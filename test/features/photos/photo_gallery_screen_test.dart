import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/app.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/data/photo_permission_repository.dart';
import 'package:photo_beauty/features/photos/data/repositories/photo_repository.dart';
import 'package:photo_beauty/features/photos/presentation/providers/asset_thumbnail_loader_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/full_image_loader_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photo_permission_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photos_provider.dart';
import 'package:photo_beauty/features/photos/presentation/screens/photo_detail_screen.dart';
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

  late List<PhotoModel> fixturePhotos;
  late Map<String, Uint8List> fixtureThumbs;

  setUpAll(() async {
    fixturePhotos = TestPhotoFixtures.photos(count: 30);
    fixtureThumbs = await TestPhotoFixtures.thumbnailMap(count: 30);
  });

  final tinyPng = Uint8List.fromList(
    base64.decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
    ),
  );

  setUp(() {
    box = _MockBox();
    repo = _MockRepo();

    when(() => repo.loadAllFromSystem())
        .thenAnswer((_) async => const <PhotoModel>[]);
    when(() => box.put(any<dynamic>(), any<dynamic>()))
        .thenAnswer((_) async {});
  });

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
            assetThumbnailLoaderProvider
                .overrideWithValue((String id) async => fixtureThumbs[id]),
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
      await tester.pumpWidget(
        buildGallery(
          initialState: PermissionState.authorized,
          photosBuildOverride: photosProvider,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('photo_gallery_loading_indicator')), findsOneWidget);
    });

    testWidgets('granted + error photos: shows error state with retry',
        (tester) async {
      when(() => repo.loadAllFromSystem())
          .thenThrow(StateError('load failed'));

      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.authorized),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_error_state')), findsOneWidget);
      expect(find.byKey(const Key('photo_gallery_retry_button')), findsOneWidget);
    });

    testWidgets('granted + empty photos: shows empty state ("暂无照片")',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.authorized),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_empty_state')), findsOneWidget);
    });

    testWidgets('granted + 30 populated photos: renders 3-column grid with fixture items',
        (tester) async {
      final populated = fixturePhotos.sublist(0, 5);
      await tester.pumpWidget(
        buildGallery(
          initialState: PermissionState.authorized,
          photosLoad: () async => populated,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_grid')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_000')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_004')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_005')), findsNothing);
    });

    testWidgets('limited (usable) + populated photos: same as granted',
        (tester) async {
      final populated = fixturePhotos;
      await tester.pumpWidget(
        buildGallery(
          initialState: PermissionState.limited,
          photosLoad: () async => populated,
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
        if (callIndex == 1) {
          throw StateError('boom');
        }
        return fixturePhotos.sublist(0, 5);
      });

      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.authorized),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_error_state')), findsOneWidget);

      await tester.tap(find.byKey(const Key('photo_gallery_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_grid')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_000')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_004')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_005')), findsNothing);
      verify(() => repo.loadAllFromSystem()).called(2);
    });
  });

  group('PhotoGalleryScreen — tap navigates to detail', () {
    testWidgets('tap grid item pushes /photo/:id route (M1-T6)',
        (tester) async {
      final populatedPhotos = TestPhotoFixtures.photos(count: 5);
      when(() => repo.loadAllFromSystem())
          .thenAnswer((_) async => populatedPhotos);

      final permRepo = PhotoPermissionRepository(
        getCurrent: () async => PermissionState.authorized,
        request: () async => PermissionState.authorized,
        openSettings: () async {},
      );

      final overrides = <Override>[
        photoPermissionRepositoryProvider.overrideWithValue(permRepo),
        settingsServiceProvider.overrideWithValue(SettingsService.fromBox(box)),
        photoRepositoryProvider.overrideWithValue(repo),
        assetThumbnailLoaderProvider
            .overrideWithValue((String id) async => fixtureThumbs[id]),
        fullImageLoaderProvider.overrideWithValue((_) async => tinyPng),
      ];

      final rootNavKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: rootNavKey,
        initialLocation: '/gallery',
        routes: [
          GoRoute(
            path: '/gallery',
            builder: (_, __) => const PhotoGalleryScreen(),
          ),
          GoRoute(
            path: '/photo/:id',
            parentNavigatorKey: rootNavKey,
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '';
              return ProviderScope(
                overrides: [
                  fullImageLoaderProvider.overrideWithValue((_) async => tinyPng),
                ],
                child: PhotoDetailScreen(assetId: id),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_gallery_grid')), findsOneWidget);
      expect(find.byKey(const Key('photo_grid_item_photo_002')), findsOneWidget);

      await tester.tap(find.byKey(const Key('photo_grid_item_photo_002')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_detail_screen')), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(
        find.byKey(const Key('photo_detail_bottom_action_bar')),
        findsOneWidget,
      );
    });
  });
}

/// Test-only [PhotosNotifier] whose `build()` never resolves — keeps state at
/// `AsyncLoading` indefinitely, letting the gallery widget test the loading
/// branch deterministically without relying on `Completer` timing.
class _LoadingPhotosNotifier extends PhotosNotifier {
  @override
  Future<List<PhotoModel>> build() => Completer<List<PhotoModel>>().future;

  @override
  Future<void> refresh() async {
    // no-op: 保持 AsyncLoading，让 widget 测试 loading 分支。
  }
}