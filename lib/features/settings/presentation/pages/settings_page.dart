import 'dart:io';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rapid/features/settings/presentation/pages/logs_page.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsPageContent();
  }
}

class _SettingsPageContent extends StatelessWidget {
  const _SettingsPageContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings), centerTitle: true),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SettingsError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          if (state is SettingsLoaded) {
            return ListView(
              children: [
                // Profile Section
                _ProfileSection(settings: state.settings),

                const Divider(height: 32),

                // Appearance Section
                _SectionHeader(title: l10n.appearance),
                _ThemeSelector(currentTheme: state.settings.themeMode),
                _LanguageSelector(currentLanguage: state.settings.language),

                const Divider(height: 32),

                // Network Section
                _SectionHeader(title: l10n.network),
                _HttpsToggle(useHttps: state.settings.useHttps),
                _PortDisplay(port: state.settings.serverPort),

                const Divider(height: 32),

                // About Section
                _SectionHeader(title: l10n.about),
                _VersionTile(),
                _LogsTile(),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

/// Profile section с аватаром и именем
class _ProfileSection extends StatelessWidget {
  final dynamic settings;

  const _ProfileSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _pickAvatar(context),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: settings.avatar != null
                      ? FileImage(File(settings.avatar!))
                      : null,
                  child: settings.avatar == null
                      ? Text(
                          _getInitials(settings.deviceName),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Device Name
          Text(
            settings.deviceName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          TextButton.icon(
            onPressed: () => _editDeviceName(context, settings.deviceName),
            icon: const Icon(Icons.edit, size: 18),
            label: Text(l10n.deviceName),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      context.read<SettingsBloc>().add(SettingsUpdateAvatar(pickedFile.path));
    }
  }

  Future<void> _editDeviceName(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final l10n = AppLocalizations.of(context)!;

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deviceName),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.enterDeviceName),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (newName != null &&
        newName.trim().isNotEmpty &&
        newName != currentName) {
      context.read<SettingsBloc>().add(
        SettingsUpdateDeviceName(newName.trim()),
      );
    }
  }
}

/// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Theme Selector
class _ThemeSelector extends StatelessWidget {
  final String currentTheme;

  const _ThemeSelector({required this.currentTheme});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: const Icon(Icons.palette),
      title: Text(l10n.theme),
      subtitle: Text(_getThemeName(context, currentTheme)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showThemeDialog(context),
    );
  }

  String _getThemeName(BuildContext context, String theme) {
    final l10n = AppLocalizations.of(context)!;
    switch (theme) {
      case 'light':
        return l10n.themeLight;
      case 'dark':
        return l10n.themeDark;
      default:
        return l10n.themeSystem;
    }
  }

  void _showThemeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              label: l10n.themeSystem,
              value: 'system',
              currentValue: currentTheme,
              onTap: () {
                context.read<SettingsBloc>().add(
                  const SettingsChangeTheme('system'),
                );
                Navigator.pop(dialogContext);
              },
            ),
            _ThemeOption(
              label: l10n.themeLight,
              value: 'light',
              currentValue: currentTheme,
              onTap: () {
                context.read<SettingsBloc>().add(
                  const SettingsChangeTheme('light'),
                );
                Navigator.pop(dialogContext);
              },
            ),
            _ThemeOption(
              label: l10n.themeDark,
              value: 'dark',
              currentValue: currentTheme,
              onTap: () {
                context.read<SettingsBloc>().add(
                  const SettingsChangeTheme('dark'),
                );
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final String value;
  final String currentValue;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.value,
    required this.currentValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == currentValue;

    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: onTap,
    );
  }
}

/// Language Selector
class _LanguageSelector extends StatelessWidget {
  final String currentLanguage;

  const _LanguageSelector({required this.currentLanguage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(_getLanguageName(currentLanguage)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showLanguageDialog(context),
    );
  }

  String _getLanguageName(String lang) {
    switch (lang) {
      case 'en':
        return 'English';
      case 'ru':
        return 'Русский';
      default:
        return 'Русский';
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: 'English',
              value: 'en',
              currentValue: currentLanguage,
              onTap: () {
                context.read<SettingsBloc>().add(
                  const SettingsChangeLanguage('en'),
                );
                Navigator.pop(dialogContext);
              },
            ),
            _LanguageOption(
              label: 'Русский',
              value: 'ru',
              currentValue: currentLanguage,
              onTap: () {
                context.read<SettingsBloc>().add(
                  const SettingsChangeLanguage('ru'),
                );
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String value;
  final String currentValue;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.value,
    required this.currentValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == currentValue;

    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: onTap,
    );
  }
}

/// HTTPS Toggle
class _HttpsToggle extends StatelessWidget {
  final bool useHttps;

  const _HttpsToggle({required this.useHttps});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SwitchListTile(
      secondary: Icon(useHttps ? Icons.lock : Icons.lock_open),
      title: Text(l10n.useHttps),
      subtitle: Text(useHttps ? 'Secure connection' : 'Unsecure connection'),
      value: useHttps,
      onChanged: (value) {
        context.read<SettingsBloc>().add(SettingsToggleHttps(value));
      },
      activeThumbColor: Colors.green,
    );
  }
}

/// Port Display
class _PortDisplay extends StatelessWidget {
  final int port;

  const _PortDisplay({required this.port});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: const Icon(Icons.settings_ethernet),
      title: Text(l10n.serverPort),
      subtitle: Text(port.toString()),
    );
  }
}

/// Version Tile
class _VersionTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: const Icon(Icons.info),
      title: Text(l10n.version),
      subtitle: Text(AppConstants.appVersion),
    );
  }
}

class _LogsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.list_alt),
      title: const Text('Logs'),
      subtitle: const Text('Developer logs'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.of(context).push(
          sharedAxisRoute(
            page: const LogsPage(),
            type: SharedAxisTransitionType.vertical, // или scaled/horizontal
          ),
        );
      },
    );
  }
}

PageRouteBuilder<T> sharedAxisRoute<T>({
  required Widget page,
  SharedAxisTransitionType type = SharedAxisTransitionType.scaled,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 330),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: type,
        child: child,
      );
    },
  );
}
