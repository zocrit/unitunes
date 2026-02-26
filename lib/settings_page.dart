import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final String defaultAction;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onDefaultActionChanged;

  const SettingsPage({
    super.key,
    required this.defaultAction,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onDefaultActionChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selected;
  late ThemeMode _themeMode;

  static const _themeLabels = {
    ThemeMode.system: 'System default',
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
  };

  static const _actionLabels = {
    'ask': 'Always ask',
    'copy': 'Copy to clipboard',
    'share': 'Reshare',
    'open': 'Open link directly',
    'show': 'Show details',
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.defaultAction;
    _themeMode = widget.themeMode;
  }

  String get _themeModeLabel => _themeLabels[_themeMode] ?? 'System default';

  Future<void> _showThemeDialog() async {
    final result = await showDialog<ThemeMode>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Theme'),
            children: [
              RadioGroup<ThemeMode>(
                groupValue: _themeMode,
                onChanged: (v) => Navigator.pop(ctx, v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in _themeLabels.entries)
                      RadioListTile<ThemeMode>(
                        title: Text(entry.value),
                        value: entry.key,
                      ),
                  ],
                ),
              ),
            ],
          ),
    );
    if (result != null) {
      setState(() => _themeMode = result);
      widget.onThemeModeChanged(result);
    }
  }

  String get _actionLabel => _actionLabels[_selected] ?? _selected;

  Future<void> _showActionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Default action'),
            children: [
              RadioGroup<String>(
                groupValue: _selected,
                onChanged: (v) => Navigator.pop(ctx, v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in _actionLabels.entries)
                      RadioListTile<String>(
                        title: Text(entry.value),
                        value: entry.key,
                      ),
                  ],
                ),
              ),
            ],
          ),
    );
    if (result != null) {
      setState(() => _selected = result);
      widget.onDefaultActionChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_themeModeLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showThemeDialog,
          ),
          ListTile(
            title: const Text('Default action'),
            subtitle: Text(_actionLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showActionDialog,
          ),
        ],
      ),
    );
  }
}
