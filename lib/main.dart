import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/history_entry.dart';
import 'models/search_models.dart';
import 'services/history_service.dart';
import 'services/music_service.dart';
import 'services/spotify_service.dart';
import 'services/youtube_music_service.dart';
import 'services/tidal_service.dart';
import 'history_page.dart';
import 'settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniTunes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _sharedText = '';
  SearchResultItem? _result;
  String _errorMsg = '';
  bool _isConverting = false;
  String _shareTargetType = 'youtube_music';
  String _defaultAction = 'ask';

  late StreamSubscription _intentSub;
  StreamSubscription? _targetEventSub;
  List<MusicService> _services = [];
  HistoryService? _historyService;

  final _servicesReady = Completer<void>();
  String? _pendingLink;

  static const _targetChannel = MethodChannel('io.github.zocrit.unitunes/share_target');
  static const _targetEvents = EventChannel('io.github.zocrit.unitunes/share_target_events');

  MusicService? get _target =>
      _services.where((s) => s.id == _shareTargetType).firstOrNull;

  @override
  void initState() {
    super.initState();

    _listenForTargetChanges();
    _initServices();

    // Link shared while app was closed
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _onSharedText(value.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    }, onError: (_) {});

    // Link shared while app is running
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _onSharedText(value.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _onSharedText(String text) {
    setState(() => _sharedText = text);
    _convertLink(text);
  }

  Future<void> _fetchShareTarget() async {
    try {
      final result = await _targetChannel.invokeMethod<String>('getShareTargetType');
      if (result != null) setState(() => _shareTargetType = result);
    } catch (_) {}
  }

  void _listenForTargetChanges() {
    _targetEventSub = _targetEvents.receiveBroadcastStream().listen((event) {
      if (event is String) setState(() => _shareTargetType = event);
    }, onError: (_) {});
  }

  Future<void> _initServices() async {
    await _fetchShareTarget();
    final prefs = await SharedPreferences.getInstance();
    _defaultAction = prefs.getString('default_action') ?? 'ask';

    const clientId = String.fromEnvironment('SPOTIFY_CLIENT_ID', defaultValue: '');
    const clientSecret = String.fromEnvironment('SPOTIFY_CLIENT_SECRET', defaultValue: '');

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

    _services = [
      spotifyService,
      YoutubeMusicService(),
      TidalService(),
    ];

    _servicesReady.complete();
    setState(() => _historyService = HistoryService(prefs));

    if (_pendingLink != null) {
      final link = _pendingLink!;
      _pendingLink = null;
      _convertLink(link);
    }
  }

  Future<void> _convertLink(String text) async {
    if (!_servicesReady.isCompleted) {
      _pendingLink = text;
      setState(() { _isConverting = true; });
      return;
    }

    setState(() { _result = null; _errorMsg = ''; });

    final source = _services.where((s) => s.detect(text)).firstOrNull;
    if (source == null) {
      setState(() { _errorMsg = 'Unsupported link'; });
      return;
    }

    final target = _target;
    if (target == null) {
      setState(() { _errorMsg = 'Unknown target service'; });
      return;
    }

    if (source.id == target.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This link is already from ${source.displayName}')),
        );
      }
      SystemNavigator.pop();
      return;
    }

    setState(() { _isConverting = true; });

    try {
      final params = await source.parse(text);
      if (params == null) {
        setState(() {
          _errorMsg = 'Could not parse ${source.displayName} link';
          _isConverting = false;
        });
        return;
      }

      final searchResult = await target.search(params);

      if (searchResult.results.isNotEmpty) {
        final item = searchResult.results.first;
        await _historyService?.add(HistoryEntry(
          title: item.title,
          sourceUrl: text,
          targetUrl: item.url,
          sourceId: source.id,
          targetId: target.id,
          type: params.type,
          timestamp: DateTime.now(),
        ));
        setState(() => _isConverting = false);
        _handleResult(item);
      } else {
        setState(() {
          _errorMsg = 'No results found';
          _isConverting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Conversion failed';
        _isConverting = false;
      });
    }
  }

  void _handleResult(SearchResultItem item) {
    switch (_defaultAction) {
      case 'copy':
        _copyAndPop(item.url);
      case 'open':
        _openAndPop(item.url);
      case 'show':
        setState(() => _result = item);
      default: // 'ask'
        setState(() => _result = item);
        _showActionSheet(item);
    }
  }

  void _showActionSheet(SearchResultItem item) {
    final targetLabel = _target?.displayName ?? 'target';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(ctx);
                _copyAndPop(item.url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text('Open in $targetLabel'),
              onTap: () {
                Navigator.pop(ctx);
                _openAndPop(item.url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Show details'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _result = item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAndPop(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
    SystemNavigator.pop();
  }

  Future<void> _openAndPop(String url) async {
    await _openLink(url);
    SystemNavigator.pop();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  void dispose() {
    _intentSub.cancel();
    _targetEventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetLabel = _target?.displayName ?? 'target';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('UniTunes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _historyService == null ? null : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryPage(
                    historyService: _historyService!,
                    services: _services,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(defaultAction: _defaultAction),
                ),
              );
              if (result != null) {
                setState(() => _defaultAction = result);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: _sharedText.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Share a music link to this app to convert it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Target: $targetLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Shared Link:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _sharedText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.blue),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$targetLabel Link:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (_isConverting)
                      const CircularProgressIndicator()
                    else if (_result != null) ...[
                      Text(
                        _result!.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _result!.url,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.green, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openLink(_result!.url),
                        icon: const Icon(Icons.open_in_new),
                        label: Text('Open in $targetLabel'),
                      ),
                    ] else if (_errorMsg.isNotEmpty)
                      Text(
                        _errorMsg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
