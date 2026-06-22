import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'hive_service.dart';

/// Thin wrapper over the settings box for typed reads/writes.
/// Keeps Hive key strings out of feature code.
class SettingsService {
  SettingsService();

  Box get _box => HiveService.settings;

  ThemeMode getThemeMode() {
    final value = _box.get(AppConstants.themeModeKey, defaultValue: 'system');
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _box.put(AppConstants.themeModeKey, value);
  }

  bool isFirstLaunch() {
    return _box.get(AppConstants.firstLaunchKey, defaultValue: true) as bool;
  }

  Future<void> markFirstLaunchDone() {
    return _box.put(AppConstants.firstLaunchKey, false);
  }
}