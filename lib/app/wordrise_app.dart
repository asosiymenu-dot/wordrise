import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_localizations.dart';
import 'package:provider/provider.dart';
import '../features/focus/focus_provider.dart';
import '../features/focus/focus_mode_wrapper.dart';
import '../core/theme/app_theme.dart';
import 'app_shell.dart';

class WordRiseApp extends StatefulWidget {
  const WordRiseApp({super.key});

  @override
  State<WordRiseApp> createState() => _WordRiseAppState();
}

class _WordRiseAppState extends State<WordRiseApp> {
  static const _themeKey = 'wordrise_theme_mode';
  static const _localeKey = 'wordrise_locale';

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('uz');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    final localeCode = prefs.getString(_localeKey);
    if (!mounted) return;
    setState(() {
      _themeMode = _themeModeFromName(themeName);
      _locale = AppLocalizations.supportedLocales.firstWhere(
        (item) => item.languageCode == localeCode,
        orElse: () => const Locale('uz'),
      );
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (mounted) setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> _setLocale(Locale locale) async {
    if (mounted) setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FocusProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WordRise',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        themeAnimationDuration: const Duration(milliseconds: 280),
        themeAnimationCurve: Curves.easeOutCubic,
        scrollBehavior: const _WordRiseScrollBehavior(),
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: FocusModeWrapper(
          child: AppShell(
            themeMode: _themeMode,
            locale: _locale,
            onThemeModeChanged: _setThemeMode,
            onLocaleChanged: _setLocale,
          ),
        ),
      ),
    );
  }
}

class _WordRiseScrollBehavior extends MaterialScrollBehavior {
  const _WordRiseScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

ThemeMode _themeModeFromName(String? value) {
  return ThemeMode.values.firstWhere(
    (item) => item.name == value,
    orElse: () => ThemeMode.light,
  );
}
