import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final String defaultAction;

  const SettingsPage({super.key, required this.defaultAction});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.defaultAction;
  }

  Future<void> _onChanged(String? value) async {
    if (value == null) return;
    setState(() => _selected = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_action', value);
    if (mounted) {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Default action after conversion',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          RadioListTile<String>(
            title: const Text('Always ask'),
            value: 'ask',
            groupValue: _selected,
            onChanged: _onChanged,
          ),
          RadioListTile<String>(
            title: const Text('Copy link to clipboard'),
            value: 'copy',
            groupValue: _selected,
            onChanged: _onChanged,
          ),
          RadioListTile<String>(
            title: const Text('Open in app'),
            value: 'open',
            groupValue: _selected,
            onChanged: _onChanged,
          ),
          RadioListTile<String>(
            title: const Text('Show details'),
            value: 'show',
            groupValue: _selected,
            onChanged: _onChanged,
          ),
        ],
      ),
    );
  }
}
