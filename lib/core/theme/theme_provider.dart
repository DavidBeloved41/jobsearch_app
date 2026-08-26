import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _boxName = 'settings';
  static const _themeKey = 'theme_mode';

  ThemeNotifier() : super(ThemeMode.light) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final box = await Hive.openBox(_boxName);
      final saved = box.get(_themeKey) as String?;
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      } else if (saved == 'system') {
        state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> toggleTheme(bool isDark) async {
    await setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_themeKey, mode.name);
    } catch (_) {}
  }

  bool get isDark => state == ThemeMode.dark;
}
