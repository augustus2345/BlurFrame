import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/app.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/data/photo_permission_repository.dart';
import 'package:photo_beauty/features/photos/data/repositories/photo_repository.dart';
import 'package:photo_beauty/features/photos/presentation/providers/asset_thumbnail_loader_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photo_permission_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photos_provider.dart';
import 'package:photo_beauty/features/photos/presentation/screens/photo_gallery_screen.dart';
import 'package:photo_beauty/shared/services/settings_service.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../test_utils/test_photo_fixtures.dart';

/// Integration tests for [PhotoGalleryScreen] — verifies the gallery:
/// 1. dispatches to [PermissionRequestScreen] vs the 4-state gallery body
///    based on permission status (M1-T1 contract);
/// 2. inside the gallery body, switches between loading / error / empty /
///    success states based on [photosProvider] (M1-T5 contract);
/// 3. triggers a one-shot [PhotosNotifier.refresh] on mount so the grid
///    appears as soon as permission is usable.
///
/// 关键 mock：
/// - `_MockBox` — SettingsService 用
/// - `_MockRepo` — PhotosNotifier 用
/// - `photoRepositoryProvider.overrideWithValue(...)` — 阻止真实 photo_manager
/// - `assetThumbnailLoaderProvider.overrideWithValue(...)` — 返回固定 PNG，
///   让 `Image.memory` codec 能解码（widget 测试不能走真 photo_manager）
class _MockBox extends Mock implements Box<dynamic> {}

class _MockRepo extends Mock implements PhotoRepository {}

void main() {
  late _MockBox box;
  late _MockRepo repo;

  // 共享 fixture：30 张测试照片 + 对应 30 张 4×4 纯色 PNG。
  // 在 setUpAll 一次性生成，setUp / 每个 test 都复用（不重新生成）。
  late List<PhotoModel> fixturePhotos;
  late Map<String, Uint8List> fixtureThumbs;

  setUpAll(() async {
    fixturePhotos = TestPhotoFixtures.photos(count: 30);
    fixtureThumbs = await TestPhotoFixtures.thumbnailMap(count: 30);
  });

  // 一个 1×1 透明 PNG（base64 编码）— 用于不关心具体图内容、只关心是否走通
  // Image.memory codec 的测试（如 loading / 4 态分派等）。
  final tinyPng = Uint8List.fromList(
    base64.decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
    ),
  );

  setUp(() {
    box = _MockBox();
    repo = _MockRepo();

    // 默认：repo 返回空列表（保持原有"无照片"行为，避免破坏旧用例）。
    when(() => repo.loadAllFromSystem())
        .thenAnswer((_) async => const <PhotoModel>[]);
    // box.put 总会成功（首启标记）。
    when(() => box.put(any<dynamic>(), any<dynamic>()))
        .thenAnswer((_) async {});
  });

  /// 测试 wrapper：注入权限 repo + settings + photos repo + thumbnail loader。
  ///
  /// [photosLoad] 控制 `loadAllFromSystem` 返回值；不传则用 setUp 默认（空列表）。
  /// [thumbnailLoader] 控制 gallery 缩略图；不传则查 [fixtureThumbs]（30 张真实色块）。
  /// [useTinyPng] 强制用 1×1 透明 PNG（不查 fixture map），用于不关心图片内容的
  ///   测试（如 loading 态）。
  /// [photosBuildOverride] 直接 override `photosProvider` — 用于测试 loading 态
  ///   （build() 返回永不 resolve 的 Future 让 state 一直是 AsyncLoading）。
  Widget buildGallery({
    required PermissionState initialState,
    Future<List<PhotoModel>> Function()? photosLoad,
    Future<Uint8List?> Function(String assetId)? thumbnailLoader,
    Future<PermissionState> Function()? request,
    AsyncNotifierProvider<PhotosNotifier, List<PhotoModel>>?
        photosBuildOverride,
    bool useTinyPng = false,
  }) {
    final permRepo = PhotoPermissionRepository(
      getCurrent: () async => initialState,
      request: request ?? () async => initialState,
      openSettings: () async {},
    );
    if (photosLoad != null) {
      when(() => repo.loadAllFromSystem()).thenAnswer((_) => photosLoad());
    }
    final Future<Uint8List?> Function(String) defaultLoader = useTinyPng
        ? (_) async => tinyPng
        : (String id) async => fixtureThumbs[id];
    final overrides = <Override>[
      photoPermissionRepositoryProvider.overrideWithValue(permRepo),
      settingsServiceProvider.overrideWithValue(SettingsService.fromBox(box)),
      photoRepositoryProvider.overrideWithValue(repo),
      assetThumbnailLoaderProvider
          .overrideWithValue(thumbnailLoader ?? defaultLoader),
    ];
    if (photosBuildOverride != null) {
      overrides.add(photosBuildOverride.overrideWith(_LoadingPhotosNotifier.new));
    }
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: PhotoGalleryScreen()),
    );
  }

  group('PhotoGalleryScreen — permission dispatch', () {
    testWidgets('notDetermined: renders PermissionRequestScreen grant view',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.notDetermined),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permission_grant_button')), findsOneWidget);
      expect(find.byKey(const Key('photo_gallery_grid')), findsNothing);
    });

    testWidgets('denied: renders PermissionRequestScreen settings view',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.denied),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permission_settings_button')), findsOneWidget);
      expect(find.byKey(const Key('permission_grant_button')), findsNothing);
    });

    testWidgets('restricted: renders PermissionRequestScreen settings view',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.restricted),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permission_settings_button')), findsOneWidget);
    });
  });

  group('PhotoGalleryScreen — refresh on mount', () {
    testWidgets('initState triggers photos refresh (post-frame callback)',
        (tester) async {
      var refreshCallCount = 0;
      when(() => repo.loadAllFromSystem()).thenAnswer((_) async {
        refreshCallCount++;
        return const <PhotoModel>[PhotoModel(id: 'a', path: '/a')];
      });

      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.authorized),
      );
      await tester.pumpAndSettle();

      expect(refreshCallCount, 1);
      expect(find.byKey(const Key('photo_gallery_grid')), findsOneWidget);
    });

    testWidgets('initState triggers permission refresh exactly once',
        (tester) async {
      var refreshCallCount = 0;
      final permRepo = PhotoPermissionRepository(
        getCurrent: () async {
          refreshCallCount++;
          return PermissionState.authorized;
        },
        request: () async => PermissionState.notDetermined,
        openSettings: () async {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            photoPermissionRepositoryProvider.overrideWithValue(permRepo),
            settingsServiceProvider.overrideWithValue(SettingsService.fromBox(box)),
            photoRepositoryProvider.overrideWithValue(repo),
            assetThumbnailLoaderProvider.overrideWithValue((_) async => tinyPng),
          ],
          child: const MaterialApp(home: PhotoGalleryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(refreshCallCount, 1);
    });
  });

  group('PhotoGalleryScreen — 4-state gallery body', () {
    testWidgets('granted + loading photos: shows loading spinner',
        (tester) async {
      // 直接 override photosProvider 用一个 build() 永不 resolve + refresh() no-op
      // 的 notifier，这样 state 始终是 AsyncLoading，gallery 进入 loading 分支。
      await tester.pumpWidget(
        buildGallery(
          initialState: PermissionState.authorized,
          photosBuildOverride: photosProvider,
        ),
      );
      // 用 pump 而不是 pumpAndSettle —— CircularProgressIndicator 一直在动画，
      // settle 永远等不到结束。
      await tester.pump();

      expect(
        find.byKey(const Key('photo_gallery_loading_indicator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('photo_gallery_grid')), findsNothing);
    });

    testWidgets('granted + error photos: shows error state with retry',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(
          initialState: PermissionState.authorized,
          photosLoad: () async => throw StateError('boom'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('photo_gallery_error_state')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('photo_gallery_retry_button')), findsOneWidget);
      expect(find.byKey(const Key('photo_gallery_grid')), findsNothing);
    });

    testWidgets(
        'granted + empty photos: shows empty state ("暂无照片")',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(
          initialState: PermissionState.authorized,
          photosLoad: () async => const <PhotoModel>[],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('photo_gallery_empty_state')),
        findsOneWidget,
      );
      expect(find.text('暂无照片'), findsOneWidget);
      expect(find.byKey(const Key('photo_gallery_grid')), findsNothing);
    });

    testWidgets(
        'granted + 30 populated photos: renders 3-column grid with fixture items',
        (tester) async {
      // 30 张来自 fixture 的真实色块（4×4 纯色 PNG，HSV 色环等分）。
      await tester.pumpWidget(
        buildGallery(
          initialState: PermissionState.authorized,
          photosLoad: () async => fixturePhotos,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_grid')), findsOneWidget);
      // 视口里能看到前 9 张（3 列 × 3 行）；photo_000 / photo_001 / photo_002 是首行
      expect(find.byKey(const Key('photo_grid_item_photo_000')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_001')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_002')), findsOneWidget);
      // 真正在视口外的 photo_020 还没被构建（GridView 懒加载）
      expect(find.byKey(const Key('photo_grid_item_photo_020')), findsNothing);
    });

    testWidgets('limited (usable) + populated photos: same as granted',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(
          initialState: PermissionState.limited,
          photosLoad: () async => fixturePhotos,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_grid')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_000')), findsOneWidget);
    });

    testWidgets('error retry button recovers with populated data', (tester) async {
      var callIndex = 0;
      when(() => repo.loadAllFromSystem()).thenAnswer((_) async {
        callIndex++;
        if (callIndex == 1) throw StateError('boom');
        // 第二次成功：返回 fixture 里的前 5 张
        return fixturePhotos.sublist(0, 5);
      });

      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.authorized),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('photo_gallery_error_state')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('photo_gallery_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_grid')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_000')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_004')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_005')), findsNothing);
      verify(() => repo.loadAllFromSystem()).called(2);
    });
  });
}

/// Test-only [PhotosNotifier] whose `build()` never resolves — keeps state at
/// `AsyncLoading` indefinitely, letting the gallery widget test the loading
/// branch deterministically without relying on `Completer` timing.
///
/// We also override [refresh] to be a no-op: otherwise the gallery's
/// `initState` post-frame callback would call `refresh`, which sets state to
/// `loading` then awaits `loadAllFromSystem` — and the mocked repo immediately
/// resolves with `const []`, blowing past the loading state.
class _LoadingPhotosNotifier extends PhotosNotifier {
  @override
  Future<List<PhotoModel>> build() => Completer<List<PhotoModel>>().future;

  @override
  Future<void> refresh() async {
    // no-op: 保持 AsyncLoading，让 widget 测试 loading 分支。
  }
}