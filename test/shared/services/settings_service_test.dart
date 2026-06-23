import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/core/constants/app_constants.dart';
import 'package:photo_beauty/shared/services/settings_service.dart';

/// Tests for [SettingsService] — theme mode read/write and first-launch flag.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - `getThemeMode` returns the stored ThemeMode, defaulting to `system`
///   when the box is empty or holds an unrecognized value (defensive).
/// - `setThemeMode` persists the matching string key for each ThemeMode.
/// - `isFirstLaunch` returns the stored bool, defaulting to `true`.
/// - `markFirstLaunchDone` writes `false` to the first launch key.
///
/// Mirrors the `MockBox` + mocktail pattern used in
/// `test/features/frames/frame_repository_test.dart`.
class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;
  late SettingsService service;

  setUp(() {
    box = _MockBox();
    service = SettingsService.fromBox(box);
  });

  group('SettingsService.getThemeMode', () {
    test('returns ThemeMode.system when box is empty (default)', () {
      when(() => box.get(any<dynamic>(), defaultValue: any<dynamic>(named: 'defaultValue')))
          .thenReturn('system');
      expect(service.getThemeMode(), ThemeMode.system);
    });

    test('returns ThemeMode.light when stored as "light"', () {
      when(() => box.get(any<dynamic>(), defaultValue: any<dynamic>(named: 'defaultValue')))
          .thenReturn('light');
      expect(service.getThemeMode(), ThemeMode.light);
    });

    test('returns ThemeMode.dark when stored as "dark"', () {
      when(() => box.get(any<dynamic>(), defaultValue: any<dynamic>(named: 'defaultValue')))
          .thenReturn('dark');
      expect(service.getThemeMode(), ThemeMode.dark);
    });

    test('returns ThemeMode.system for unrecognized values (defensive)', () {
      // 防御性：将来如果有人手改 box 写入了 'sepia' / 'high-contrast' 之类，
      // 不能直接崩，要回退到 system。
      when(() => box.get(any<dynamic>(), defaultValue: any<dynamic>(named: 'defaultValue')))
          .thenReturn('nonsense-value');
      expect(service.getThemeMode(), ThemeMode.system);
    });
  });

  group('SettingsService.setThemeMode', () {
    test('writes "light" for ThemeMode.light', () async {
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await service.setThemeMode(ThemeMode.light);
      verify(() => box.put(AppConstants.themeModeKey, 'light')).called(1);
    });

    test('writes "dark" for ThemeMode.dark', () async {
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await service.setThemeMode(ThemeMode.dark);
      verify(() => box.put(AppConstants.themeModeKey, 'dark')).called(1);
    });

    test('writes "system" for ThemeMode.system', () async {
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await service.setThemeMode(ThemeMode.system);
      verify(() => box.put(AppConstants.themeModeKey, 'system')).called(1);
    });
  });

  group('SettingsService first launch flag', () {
    test('isFirstLaunch returns true when box is empty (default)', () {
      when(() => box.get(any<dynamic>(), defaultValue: any<dynamic>(named: 'defaultValue')))
          .thenReturn(true);
      expect(service.isFirstLaunch(), isTrue);
    });

    test('isFirstLaunch returns false when stored as false', () {
      when(() => box.get(any<dynamic>(), defaultValue: any<dynamic>(named: 'defaultValue')))
          .thenReturn(false);
      expect(service.isFirstLaunch(), isFalse);
    });

    test('markFirstLaunchDone writes false to the first launch key', () async {
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await service.markFirstLaunchDone();
      verify(() => box.put(AppConstants.firstLaunchKey, false)).called(1);
    });
  });
}
