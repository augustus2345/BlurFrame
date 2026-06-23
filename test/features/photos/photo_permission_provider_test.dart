import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/app.dart';
import 'package:photo_beauty/core/constants/app_constants.dart';
import 'package:photo_beauty/features/photos/data/photo_permission_repository.dart';
import 'package:photo_beauty/features/photos/data/photo_permission_status.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photo_permission_provider.dart';
import 'package:photo_beauty/shared/services/settings_service.dart';
import 'package:photo_manager/photo_manager.dart';

/// Tests for [PhotoPermissionNotifier] — the state holder + state machine for
/// photo-library permission.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - `build()` defaults to [PhotoPermissionStatus.notDetermined] (we never
///   know the real state until [PhotoPermissionNotifier.refresh] runs).
/// - `refresh()` reads `repo.current()` and updates state with the result.
/// - `request()` transitions: `notDetermined` → `requesting` (BEFORE await, so
///   the UI is updated synchronously) → result from `repo.request()`. If the
///   result is usable (`granted` or `limited`), `markFirstLaunchDone` is called.
/// - `request()` with non-usable result leaves the first-launch flag alone
///   (so the next launch can try again / show settings guidance).
/// - `openSettings()` calls `repo.openSettings` and then `refresh()` to pick up
///   the user's new choice in system settings.
///
/// Tests inject both the repository (mock photo_manager functions) and a
/// `SettingsService.fromBox` (mock Hive box) via Riverpod overrides.
class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;
  late SettingsService settingsService;
  late PhotoPermissionRepository Function({
    Future<PermissionState> Function()? getCurrent,
    Future<PermissionState> Function()? request,
    Future<void> Function()? openSettings,
  }) repoBuilder;

  // Per-test scratch state. `setUp` 重置；给初值让 Dart flow-analysis 满意。
  PhotoPermissionStatus currentResult = PhotoPermissionStatus.notDetermined;
  PhotoPermissionStatus requestResult = PhotoPermissionStatus.granted;
  bool openSettingsCalled = false;
  int currentCallCount = 0;
  int requestCallCount = 0;

  setUp(() {
    box = _MockBox();
    settingsService = SettingsService.fromBox(box);

    currentResult = PhotoPermissionStatus.notDetermined;
    requestResult = PhotoPermissionStatus.granted;
    openSettingsCalled = false;
    currentCallCount = 0;
    requestCallCount = 0;

    repoBuilder = ({
      Future<PermissionState> Function()? getCurrent,
      Future<PermissionState> Function()? request,
      Future<void> Function()? openSettings,
    }) {
      return PhotoPermissionRepository(
        getCurrent: getCurrent ??
            () async {
              currentCallCount++;
              return _toPermissionState(currentResult);
            },
        request: request ??
            () async {
              requestCallCount++;
              return _toPermissionState(requestResult);
            },
        openSettings: openSettings ??
            () async {
              openSettingsCalled = true;
            },
      );
    };
  });

  ProviderContainer makeContainer(PhotoPermissionRepository repo) {
    final container = ProviderContainer(
      overrides: <Override>[
        photoPermissionRepositoryProvider.overrideWithValue(repo),
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('PhotoPermissionNotifier.build', () {
    test('initial state is notDetermined (before refresh)', () {
      final container = makeContainer(repoBuilder());

      expect(
        container.read(photoPermissionProvider),
        PhotoPermissionStatus.notDetermined,
      );
    });
  });

  group('PhotoPermissionNotifier.refresh', () {
    test('updates state to whatever the repository reports', () async {
      currentResult = PhotoPermissionStatus.granted;
      final container = makeContainer(repoBuilder());

      await container.read(photoPermissionProvider.notifier).refresh();

      expect(
        container.read(photoPermissionProvider),
        PhotoPermissionStatus.granted,
      );
      expect(currentCallCount, 1);
    });

    test('reflects denied state from system', () async {
      currentResult = PhotoPermissionStatus.denied;
      final container = makeContainer(repoBuilder());

      await container.read(photoPermissionProvider.notifier).refresh();

      expect(
        container.read(photoPermissionProvider),
        PhotoPermissionStatus.denied,
      );
    });
  });

  group('PhotoPermissionNotifier.request', () {
    test('transitions to requesting BEFORE awaiting the system dialog',
        () async {
      // 用一个会暂停的 request 让我们能观察到中间态
      final completer = Completer<PermissionState>();
      // 后续会触发 markFirstLaunchDone → box.put，需要先 mock
      when(() => box.put(AppConstants.firstLaunchKey, false))
          .thenAnswer((_) async {});
      final container = makeContainer(
        repoBuilder(
          request: () => completer.future,
        ),
      );

      final future = container
          .read(photoPermissionProvider.notifier)
          .request();
      // 同步：state 已经是 requesting
      expect(
        container.read(photoPermissionProvider),
        PhotoPermissionStatus.requesting,
      );

      completer.complete(PermissionState.authorized);
      await future;

      expect(
        container.read(photoPermissionProvider),
        PhotoPermissionStatus.granted,
      );
    });

    test('granted result: marks first launch done', () async {
      requestResult = PhotoPermissionStatus.granted;
      when(() => box.put(AppConstants.firstLaunchKey, false))
          .thenAnswer((_) async {});

      final container = makeContainer(repoBuilder());
      await container.read(photoPermissionProvider.notifier).request();

      verify(() => box.put(AppConstants.firstLaunchKey, false)).called(1);
      expect(requestCallCount, 1);
    });

    test('limited result: marks first launch done (limited is usable)',
        () async {
      requestResult = PhotoPermissionStatus.limited;
      when(() => box.put(AppConstants.firstLaunchKey, false))
          .thenAnswer((_) async {});

      final container = makeContainer(repoBuilder());
      await container.read(photoPermissionProvider.notifier).request();

      verify(() => box.put(AppConstants.firstLaunchKey, false)).called(1);
    });

    test('denied result: does NOT mark first launch done', () async {
      requestResult = PhotoPermissionStatus.denied;
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      final container = makeContainer(repoBuilder());
      await container.read(photoPermissionProvider.notifier).request();

      verifyNever(() => box.put(AppConstants.firstLaunchKey, false));
    });

    test('restricted result: does NOT mark first launch done', () async {
      requestResult = PhotoPermissionStatus.restricted;
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      final container = makeContainer(repoBuilder());
      await container.read(photoPermissionProvider.notifier).request();

      verifyNever(() => box.put(AppConstants.firstLaunchKey, false));
    });
  });

  group('PhotoPermissionNotifier.openSettings', () {
    test('calls repo.openSettings and refreshes state', () async {
      // openSettings 后用户改了设置，回 granted
      currentResult = PhotoPermissionStatus.granted;
      final container = makeContainer(repoBuilder());

      await container.read(photoPermissionProvider.notifier).openSettings();

      expect(openSettingsCalled, isTrue);
      expect(currentCallCount, 1);
      expect(
        container.read(photoPermissionProvider),
        PhotoPermissionStatus.granted,
      );
    });
  });
}

/// 测试辅助：把领域 enum 转成 photo_manager 的 PermissionState。
PermissionState _toPermissionState(PhotoPermissionStatus status) {
  return switch (status) {
    PhotoPermissionStatus.notDetermined => PermissionState.notDetermined,
    PhotoPermissionStatus.requesting => PermissionState.notDetermined,
    PhotoPermissionStatus.denied => PermissionState.denied,
    PhotoPermissionStatus.restricted => PermissionState.restricted,
    PhotoPermissionStatus.granted => PermissionState.authorized,
    PhotoPermissionStatus.limited => PermissionState.limited,
  };
}
