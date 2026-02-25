import 'package:flutter/material.dart';
import 'models/history_entry.dart';
import 'services/history_service.dart';
import 'services/music_service.dart';
import 'utils.dart';

void showEntryActionSheet(
  BuildContext context,
  HistoryEntry entry,
  List<MusicService> services,
) {
  final targetLabel = services.displayNameFor(entry.targetId);
  showModalBottomSheet(
    context: context,
    builder:
        (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  entry.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy link'),
                onTap: () {
                  Navigator.pop(ctx);
                  copyAndNotify(context, entry.targetUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text('Open in $targetLabel'),
                onTap: () {
                  Navigator.pop(ctx);
                  openLink(entry.targetUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Show details'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              EntryDetailPage(entry: entry, services: services),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
  );
}

class HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final String targetName;
  final VoidCallback onTap;

  const HistoryTile({
    super.key,
    required this.entry,
    required this.targetName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child:
                    entry.imageUrl != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            entry.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) =>
                                    const Center(child: Icon(Icons.music_note)),
                          ),
                        )
                        : const Center(child: Icon(Icons.music_note)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        entry.artist != null
                            ? '${entry.title} - ${entry.artist}'
                            : entry.title,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$targetName · ${entry.relativeTime}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Center(child: Icon(Icons.chevron_right)),
            ],
          ),
        ),
      ),
    );
  }
}

class ConversionDetailContent extends StatelessWidget {
  static final _artRadius = BorderRadius.circular(16);

  final HistoryEntry entry;
  final List<MusicService> services;

  const ConversionDetailContent({
    super.key,
    required this.entry,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sourceName = services.displayNameFor(entry.sourceId);
    final targetName = services.displayNameFor(entry.targetId);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (entry.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: _artRadius,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: _artRadius,
                    child: Image.network(
                      entry.imageUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            Text(
              entry.artist != null
                  ? '${entry.title} - ${entry.artist}'
                  : entry.title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _linkRow(context, 'From $sourceName', entry.sourceUrl, colorScheme, textTheme),
            const SizedBox(height: 8),
            _linkRow(context, 'To $targetName', entry.targetUrl, colorScheme, textTheme),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => openLink(entry.targetUrl),
              icon: const Icon(Icons.open_in_new),
              label: Text('Open in $targetName'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkRow(
    BuildContext context,
    String label,
    String url,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ),
            IconButton(
              onPressed: () => copyAndNotify(context, url),
              icon: const Icon(Icons.copy, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

class EntryDetailPage extends StatelessWidget {
  final HistoryEntry entry;
  final List<MusicService> services;

  const EntryDetailPage({
    super.key,
    required this.entry,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: ConversionDetailContent(entry: entry, services: services),
    );
  }
}

class HistoryPage extends StatefulWidget {
  final HistoryService historyService;
  final List<MusicService> services;

  const HistoryPage({
    super.key,
    required this.historyService,
    required this.services,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<HistoryEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.historyService.load();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear history'),
            content: const Text(
              'Are you sure you want to clear your conversion history?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await widget.historyService.clear();
      setState(() => _entries = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body:
          _entries.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'No conversions yet.\nConverted links will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
              : ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return HistoryTile(
                    entry: entry,
                    targetName: widget.services.displayNameFor(entry.targetId),
                    onTap:
                        () => showEntryActionSheet(
                          context,
                          entry,
                          widget.services,
                        ),
                  );
                },
              ),
    );
  }
}
