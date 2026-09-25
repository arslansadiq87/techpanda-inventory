import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/local_inventory_client.dart';
import 'core/secure_http_client_stub.dart'
    if (dart.library.io) 'core/secure_http_client_io.dart';
import 'features/inventory_home.dart';

void main() {
  configureSecureHttpOverrides();
  runApp(TechPandaInventoryApp(api: LocalInventoryClient()));
}

class TechPandaInventoryApp extends StatefulWidget {
  const TechPandaInventoryApp({super.key, required this.api});

  final ApiClient api;

  @override
  State<TechPandaInventoryApp> createState() => _TechPandaInventoryAppState();
}

class _TechPandaInventoryAppState extends State<TechPandaInventoryApp> {
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    final prefs = await SharedPreferences.getInstance();
    var darkMode = prefs.getBool('dark_mode') ?? false;
    try {
      final settings = await widget.api.uiSettings();
      darkMode = settings['dark_mode'] == true;
      await prefs.setBool('dark_mode', darkMode);
    } catch (_) {
      // The local API may not be running yet; keep the browser preference.
    }
    if (mounted) setState(() => _darkMode = darkMode);
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    try {
      await widget.api.updateUiSettings(darkMode: value);
    } catch (_) {
      // The in-browser setting is still saved; the backend copy can sync later.
    }
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B7775),
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0E1514)
          : const Color(0xFFF4F8F7),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tech Panda Components Inventory',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: InventoryHome(
        api: widget.api,
        darkMode: _darkMode,
        onDarkModeChanged: _setDarkMode,
      ),
    );
  }
}
