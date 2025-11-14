import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_event.dart';
import 'features/settings/presentation/bloc/settings_state.dart';
import 'features/lan/presentation/pages/lan_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';

class RapidApp extends StatelessWidget {
  const RapidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SettingsBloc>()..add(SettingsInitialize()),
      child: const _RapidAppContent(),
    );
  }
}

class _RapidAppContent extends StatefulWidget {
  const _RapidAppContent();

  @override
  State<_RapidAppContent> createState() => _RapidAppContentState();
}

class _RapidAppContentState extends State<_RapidAppContent> {
  // Глобальный ключ для MaterialApp
  final _appKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsBloc, SettingsState>(
      // ВАЖНО: При изменении состояния пересоздаём виджет
      listener: (context, state) {
        if (state is SettingsLoaded) {
          // Форсируем rebuild через setState
          setState(() {});
        }
      },
      builder: (context, state) {
        ThemeMode themeMode = ThemeMode.system;
        Locale locale = const Locale('ru');

        if (state is SettingsLoaded) {
          themeMode = _parseThemeMode(state.settings.themeMode);
          locale = Locale(state.settings.language);
        }

        return MaterialApp(
          key: _appKey, // Глобальный ключ
          title: 'Rapid',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,

          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: const MainNavigation(),
        );
      },
    );
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const LANPage(),
    const Placeholder(), // WebPage
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.wifi),
            label: l10n.lan,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.public),
            label: l10n.web,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
