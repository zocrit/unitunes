import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'models/conversion_state.dart';
import 'models/history_entry.dart';
import 'services/history_service.dart';
import 'services/music_service.dart';
import 'services/spotify_service.dart';
import 'services/youtube_music_service.dart';
import 'services/tidal_service.dart';
import 'history_page.dart';
import 'prefs_keys.dart';
import 'settings_page.dart';
import 'utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(kThemeModeKey);
    if (value != null) {
      setState(() {
        _themeMode = switch (value) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
      });
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniTunes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: HomePage(themeMode: _themeMode, onThemeModeChanged: _setThemeMode),
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const HomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ConversionState _conversion = const Idle();
  String _shareTargetType = 'youtube_music';
  String _defaultAction = 'share';
  bool _launchedFromShare = false;

  late StreamSubscription _intentSub;
  StreamSubscription? _targetEventSub;
  List<MusicService> _services = [];
  HistoryService? _historyService;
  List<HistoryEntry> _recentEntries = [];

  final _pasteController = TextEditingController();
  final _servicesReady = Completer<void>();
  String? _pendingLink;

  static const _targetChannel = MethodChannel(
    'io.github.zocrit.unitunes/share_target',
  );
  static const _targetEvents = EventChannel(
    'io.github.zocrit.unitunes/share_target_events',
  );

  MusicService? get _target =>
      _services.where((s) => s.id == _shareTargetType).firstOrNull;

  bool get _useMinimalOverlay =>
      _launchedFromShare && (_defaultAction == 'copy' || _defaultAction == 'share');

  @override
  void initState() {
    super.initState();

    _listenForTargetChanges();
    _initServices();

    // Link shared while app was closed
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _launchedFromShare = true;
        _convertLink(value.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    }, onError: (_) {});

    // Link shared while app is running
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _launchedFromShare = true;
        _convertLink(value.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  Future<void> _fetchShareTarget() async {
    try {
      final result = await _targetChannel.invokeMethod<String>(
        'getShareTargetType',
      );
      if (result != null) setState(() => _shareTargetType = result);
    } catch (_) {}
  }

  void _listenForTargetChanges() {
    _targetEventSub = _targetEvents.receiveBroadcastStream().listen((event) {
      if (event is String) setState(() => _shareTargetType = event);
    }, onError: (_) {});
  }

  Future<void> _initServices() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultAction = prefs.getString(kDefaultActionKey) ?? 'share';
    _shareTargetType = prefs.getString(kDefaultTargetKey) ?? _shareTargetType;
    await _fetchShareTarget();

    const clientId = String.fromEnvironment(
      'SPOTIFY_CLIENT_ID',
      defaultValue: '',
    );
    const clientSecret = String.fromEnvironment(
      'SPOTIFY_CLIENT_SECRET',
      defaultValue: '',
    );

    SpotifyService spotifyService;
    if (clientId.isNotEmpty && clientSecret.isNotEmpty) {
      try {
        spotifyService = await SpotifyService.create(clientId, clientSecret);
      } catch (e) {
        debugPrint('Failed to init Spotify with API, using scraping only: $e');
        spotifyService = SpotifyService();
      }
    } else {
      spotifyService = SpotifyService();
    }

    _services = [spotifyService, YoutubeMusicService(), TidalService()];

    _servicesReady.complete();
    final historyService = HistoryService(prefs);
    setState(() {
      _historyService = historyService;
      _recentEntries = historyService.load();
    });

    if (_pendingLink != null) {
      final link = _pendingLink!;
      _pendingLink = null;
      _convertLink(link);
    }
  }

  Future<void> _convertLink(String text) async {
    if (!_servicesReady.isCompleted) {
      _pendingLink = text;
      setState(() => _conversion = Converting(link: text));
      return;
    }

    setState(() => _conversion = Converting(link: text));

    final source = _services.where((s) => s.detect(text)).firstOrNull;
    if (source == null) {
      _failConversion('Unsupported link');
      return;
    }

    final target = _target;
    if (target == null) {
      _failConversion('Unknown target service');
      return;
    }

    if (source.id == target.id) {
      if (_launchedFromShare) {
        Fluttertoast.showToast(
          msg: 'This link is already from ${source.displayName}',
        );
        SystemNavigator.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This link is already from ${source.displayName}'),
          ),
        );
        setState(() => _conversion = const Idle());
      }
      return;
    }

    final cached =
        _recentEntries
            .where((e) => e.sourceUrl == text && e.targetId == target.id)
            .firstOrNull;
    if (cached != null) {
      _handleResult(cached);
      return;
    }

    try {
      final params = await source.parse(text);
      if (params == null) {
        _failConversion('Could not parse ${source.displayName} link');
        return;
      }

      setState(() => _conversion = Converting(link: text, imageUrl: params.imageUrl));

      final searchResult = await target.search(params);

      if (searchResult.results.isNotEmpty) {
        final item = searchResult.results.first;
        final entry = HistoryEntry(
          title: item.title,
          sourceUrl: text,
          targetUrl: item.url,
          sourceId: source.id,
          targetId: target.id,
          type: params.type,
          timestamp: DateTime.now(),
          imageUrl: params.imageUrl,
          artist: params.artist,
        );
        await _historyService?.add(entry);
        _handleResult(entry);
      } else {
        _failConversion('No results found');
      }
    } catch (e) {
      _failConversion('Conversion failed');
    }
  }

  void _setError(String message) {
    final img = switch (_conversion) {
      Converting(:final imageUrl) => imageUrl,
      _ => null,
    };
    setState(() => _conversion = ConversionError(message: message, imageUrl: img));
  }

  void _failConversion(String message) {
    if (_useMinimalOverlay) {
      Fluttertoast.showToast(msg: message);
      _exitOrReset();
    } else {
      _setError(message);
    }
  }

  void _handleResult(HistoryEntry entry) {
    switch (_defaultAction) {
      case 'copy':
        _copyAndFinish(entry.targetUrl);
      case 'share':
        _shareAndFinish(entry.targetUrl);
      case 'open':
        _openAndFinish(entry.targetUrl);
      case 'show':
        setState(() => _conversion = Converted(entry: entry));
      default: // 'ask'
        setState(() => _conversion = Converted(entry: entry));
        _showActionSheet(entry);
    }
  }

  void _showActionSheet(HistoryEntry entry) {
    showEntryActionSheet(
      context,
      title: entry.title,
      targetLabel: _target?.displayName ?? 'target',
      onCopy: () => _copyAndFinish(entry.targetUrl),
      onShare: () => _shareAndFinish(entry.targetUrl),
      onOpen: () => _openAndFinish(entry.targetUrl),
      onShowDetails: () => setState(() => _conversion = Converted(entry: entry)),
    );
  }

  void _copyAndFinish(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (_useMinimalOverlay) {
      Fluttertoast.showToast(msg: 'Link copied to clipboard');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
    _exitOrReset();
  }

  Future<void> _shareAndFinish(String url) async {
    if (_useMinimalOverlay) setState(() => _conversion = const Idle());
    await shareLink(url);
    _exitOrReset();
  }

  Future<void> _openAndFinish(String url) async {
    await openLink(url);
    _exitOrReset();
  }

  void _exitOrReset() {
    if (_launchedFromShare) {
      SystemNavigator.pop();
    } else {
      setState(() {
        _conversion = const Idle();
        if (_historyService != null) {
          _recentEntries = _historyService!.load();
        }
      });
    }
  }

  Future<void> _setDefaultAction(String action) async {
    setState(() => _defaultAction = action);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kDefaultActionKey, action);
  }

  Future<void> _setDefaultTarget(String targetId) async {
    setState(() => _shareTargetType = targetId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kDefaultTargetKey, targetId);
  }

  void _submitPastedLink() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) return;
    _pasteController.clear();
    _convertLink(text);
  }

  Widget _buildArtwork(String? imageUrl) {
    if (imageUrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            width: 200,
            height: 200,
            child: Center(child: Icon(Icons.music_note, size: 48)),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _intentSub.cancel();
    _targetEventSub?.cancel();
    _pasteController.dispose();
    super.dispose();
  }

  Widget _buildOverlay() {
    final converting = _conversion is Converting;
    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black54,
        child: Align(
          alignment: const Alignment(0, -0.5),
          child: converting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(Icons.check_circle_outline, color: Colors.white, size: 48),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useMinimalOverlay) {
      return PopScope(
        canPop: false,
        child: _buildOverlay(),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final inputRadius = BorderRadius.circular(12);

    return PopScope(
      canPop: _conversion is Idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitOrReset();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('UniTunes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => SettingsPage(
                          defaultAction: _defaultAction,
                          themeMode: widget.themeMode,
                          onThemeModeChanged: widget.onThemeModeChanged,
                          onDefaultActionChanged: _setDefaultAction,
                        ),
                  ),
                );
              },
            ),
          ],
        ),
        body: switch (_conversion) {
          Idle() => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextField(
                  controller: _pasteController,
                  decoration: InputDecoration(
                    hintText: 'Paste a music link...',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: inputRadius,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: inputRadius,
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: inputRadius,
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.arrow_forward,
                        color: colorScheme.primary,
                      ),
                      onPressed: _submitPastedLink,
                    ),
                  ),
                  onSubmitted: (_) => _submitPastedLink(),
                ),
                if (_services.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children:
                                _services.map((s) {
                                  final isSelected =
                                      s.id == _shareTargetType;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: ChoiceChip(
                                      showCheckmark: false,
                                      label: Text(s.displayName),
                                      selected: isSelected,
                                      selectedColor:
                                          colorScheme.primaryContainer,
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? colorScheme
                                                .onPrimaryContainer
                                            : colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      side: isSelected
                                          ? BorderSide.none
                                          : BorderSide(
                                              color: colorScheme.outline,
                                            ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: inputRadius,
                                      ),
                                      onSelected:
                                          (_) => _setDefaultTarget(s.id),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const kHeaderHeight = 48.0;
                      const kTileHeight = 72.0;
                      final available =
                          constraints.maxHeight - kHeaderHeight;
                      final maxItems = (available / kTileHeight)
                          .floor()
                          .clamp(0, 10);
                      final itemCount = min(
                        _recentEntries.length,
                        maxItems,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color:
                                          colorScheme.onSurfaceVariant,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                              TextButton(
                                onPressed:
                                    _historyService == null
                                        ? null
                                        : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => HistoryPage(
                                                    historyService:
                                                        _historyService!,
                                                    services: _services,
                                                  ),
                                            ),
                                          );
                                          setState(() {
                                            _recentEntries =
                                                _historyService!.load();
                                          });
                                        },
                                child: const Text('See all'),
                              ),
                            ],
                          ),
                          if (_recentEntries.isEmpty)
                            Expanded(
                              child: Center(
                                child: Text(
                                  'No conversions yet',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: itemCount,
                                itemBuilder: (context, index) {
                                  final entry = _recentEntries[index];
                                  return HistoryTile(
                                    entry: entry,
                                    targetName: _services.displayNameFor(
                                      entry.targetId,
                                    ),
                                    onTap:
                                        () => showBrowseActionSheet(
                                          context, entry, _services,
                                        ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Converted(:final entry) => ConversionDetailContent(
            entry: entry,
            services: _services,
          ),
          Converting(:final imageUrl) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildArtwork(imageUrl),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
          ConversionError(:final message, :final imageUrl) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildArtwork(imageUrl),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        },
      ),
    );
  }
}
