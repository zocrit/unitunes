import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/history_entry.dart';
import 'services/history_service.dart';
import 'services/music_service.dart';

void showEntryActionSheet(
  BuildContext context,
  HistoryEntry entry,
  List<MusicService> services,
) {
  final targetLabel = services.displayNameFor(entry.targetId);
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              entry.title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy link'),
            onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: entry.targetUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text('Open in $targetLabel'),
            onTap: () async {
              Navigator.pop(ctx);
              final uri = Uri.tryParse(entry.targetUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    ),
  );
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
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history'),
        content:
            const Text('Are you sure you want to clear your conversion history?'),
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
      body: _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'No conversions yet.\nConverted links will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final sourceName = widget.services.displayNameFor(entry.sourceId);
                final targetName = widget.services.displayNameFor(entry.targetId);
                return ListTile(
                  title: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$sourceName \u2192 $targetName \u00b7 ${entry.relativeTime}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showEntryActionSheet(context, entry, widget.services),
                );
              },
            ),
    );
  }
}
