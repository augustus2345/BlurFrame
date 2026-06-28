import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'hive_service.dart';

/// Thin wrapper over the settings box for typed reads/writes.
/// Keeps Hive key strings out of feature code.
///
/// Supports two construction paths:
///   - [SettingsService] (default) — production path, reads from
///     [HiveService.settings]. Requires `HiveService.init()` to have run
///     first.
///   - [SettingsService.fromBox] — DI / test path, accepts an explicit
///     [Box] (typically a mocktail mock). Same convention as
///     [FrameRepository.fromBox].
class SettingsService {
  /// 默认构造：从全局 [HiveService.settings] 取 box。
  ///
  /// 生产路径，依赖 `HiveService.init()` 已先于本实例使用前调用完成。
  SettingsService() : _box = HiveService.settings;

  /// 测试 / DI 构造：传入指定的 box（通常用 mocktail 的 `Mock implements Box<dynamic>`）。
  ///
  /// 与 [FrameRepository.fromBox] 保持同样的依赖注入约定。
  SettingsService.fromBox(Box<dynamic> box) : _box = box;

  /// 当前使用的 settings box。生产路径下为全局 `HiveService.settings`，
  /// DI 路径下为构造时注入的 box。
  final Box<dynamic> _box;

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

  /// 读取布尔值。
  bool getBool(String key, {bool defaultValue = false}) {
    final value = _box.get(key);
    if (value is bool) return value;
    return defaultValue;
  }

  /// 写入布尔值。
  Future<void> setBool(String key, bool value) {
    return _box.put(key, value);
  }
}
