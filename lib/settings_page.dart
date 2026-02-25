import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final String defaultAction;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsPage({
    super.key,
    required this.defaultAction,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selected;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _selected = widget.defaultAction;
    _themeMode = widget.themeMode;
  }

  String get _themeModeLabel => switch (_themeMode) {
    ThemeMode.system => 'System default',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  Future<void> _showThemeDialog() async {
    final result = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          for (final (mode, label) in [
            (ThemeMode.system, 'System default'),
            (ThemeMode.light, 'Light'),
            (ThemeMode.dark, 'Dark'),
          ])
            RadioListTile<ThemeMode>(
              title: Text(label),
              value: mode,
              groupValue: _themeMode,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _themeMode = result);
      widget.onThemeModeChanged(result);
    }
  }

  static const _actionLabels = {
    'ask': 'Always ask',
    'copy': 'Copy to clipboard',
    'open': 'Open link directly',
    'show': 'Show details',
  };

  String get _actionLabel => _actionLabels[_selected] ?? _selected;

  Future<void> _showActionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default action'),
        children: [
          for (final entry in _actionLabels.entries)
            RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: _selected,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _selected = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('default_action', result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
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
