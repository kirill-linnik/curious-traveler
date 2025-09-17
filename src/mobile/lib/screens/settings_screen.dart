import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _defaultDuration = 4;

  final List<Map<String, String>> _languages = [
    {'code': 'en-US', 'name': 'English'},
    {'code': 'es-ES', 'name': 'Spanish'},
    {'code': 'fr-FR', 'name': 'French'},
    {'code': 'de-DE', 'name': 'German'},
    {'code': 'it-IT', 'name': 'Italian'},
    {'code': 'pt-BR', 'name': 'Portuguese'},
    {'code': 'zh-CN', 'name': 'Chinese (Simplified)'},
    {'code': 'ja-JP', 'name': 'Japanese'},
    {'code': 'ko-KR', 'name': 'Korean'},
    {'code': 'ru-RU', 'name': 'Russian'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = context.read<SharedPreferences>();
    setState(() {
      _defaultDuration = prefs.getInt('default_duration') ?? 4;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = context.read<SharedPreferences>();
    await prefs.setInt('default_duration', _defaultDuration);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.languageAndRegion,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Consumer<LocaleProvider>(
                    builder: (context, localeProvider, child) {
                      return DropdownButtonFormField<String>(
                        initialValue: localeProvider.currentLanguageCode,
                        decoration: InputDecoration(
                          labelText: localizations.narrationLanguage,
                          border: const OutlineInputBorder(),
                        ),
                        items: _languages.map((language) {
                          return DropdownMenuItem(
                            value: language['code'],
                            child: Text(language['name']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            localeProvider.setLanguageCode(value);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Default Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.defaultPreferences,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(localizations.defaultDurationHours(_defaultDuration)),
                  Slider(
                    value: _defaultDuration.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    onChanged: (value) {
                      setState(() => _defaultDuration = value.round());
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // App Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.about,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info),
                    title: Text(localizations.version),
                    subtitle: const Text('1.0.0'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description),
                    title: Text(localizations.privacyPolicy),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showPrivacyPolicy(),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help),
                    title: Text(localizations.helpAndSupport),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showHelp(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Data & Storage
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.dataAndStorage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete),
                    title: Text(localizations.clearCachedData),
                    subtitle: Text(localizations.removeCachedDataDescription),
                    onTap: () => _showClearDataDialog(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Footer
          Center(
            child: Column(
              children: [
                Text(
                  localizations.appTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI-powered city exploration',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.privacyPolicy),
        content: SingleChildScrollView(
          child: Text(
            localizations.privacyPolicyContent,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.helpAndSupport),
        content: SingleChildScrollView(
          child: Text(
            localizations.helpContent,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.clearData),
        content: Text(
          localizations.clearDataDialogContent,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () async {
              await _clearData();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(localizations.clear),
          ),
        ],
      ),
    );
  }

  Future<void> _clearData() async {
    final prefs = context.read<SharedPreferences>();
    final localeProvider = context.read<LocaleProvider>();
    
    await prefs.clear();
    
    // Reset to defaults
    setState(() {
      _defaultDuration = 4;
    });
    
    // Reset locale to default
    await localeProvider.setLanguageCode('en-US');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.dataClearedSuccessfully),
        ),
      );
    }
  }
}