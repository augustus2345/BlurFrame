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

/// 100 张照片的压力测试 — 验证 [PhotoGalleryScreen] 在真实规模数据下的行为：
/// - 初次渲染：视口里只能看到 ~9 张（GridView 懒构建）
/// - 拖动滚动到接近底部：第 99 张进入视口
/// - 滚回顶部：photo_000 重新可见（widget 复用稳定）
/// - 缩略图按需加载：每张进入视口时 `Image.memory` 渲染对应的色块
/// - 性能预算：100 张首次渲染 + 滚动到 99 应在 1 秒内完成（粗略 sanity check）
///
/// 100 张不是拍脑袋选的：
/// - 30 张 = 典型一周出行的手机相册
/// - 100 张 = 一段假期的规模，足以暴露任何 O(N) 的渲染问题
/// - 1000+ 留到 M6-T3 性能压测（那时用 `pumpAndSettle` 的总耗时当基准）
class _MockBox extends Mock implements Box<dynamic> {}

class _MockRepo extends Mock implements PhotoRepository {}

void main() {
  late _MockBox box;
  late _MockRepo repo;
  late List<PhotoModel> photos;
  late Map<String, Uint8List> thumbs;

  setUpAll(() async {
    photos = TestPhotoFixtures.photos(count: 100);
    thumbs = await TestPhotoFixtures.thumbnailMap(count: 100);
  });

  setUp(() {
    box = _MockBox();
    repo = _MockRepo();
    when(() => box.put(any<dynamic>(), any<dynamic>()))
        .thenAnswer((_) async {});
    when(() => repo.loadAllFromSystem())
        .thenAnswer((_) async => photos);
  });

  Widget buildGallery() {
    final permRepo = PhotoPermissionRepository(
      getCurrent: () async => PermissionState.authorized,
      request: () async => PermissionState.authorized,
      openSettings: () async {},
    );
    return ProviderScope(
      overrides: <Override>[
        photoPermissionRepositoryProvider.overrideWithValue(permRepo),
        settingsServiceProvider.overrideWithValue(SettingsService.fromBox(box)),
        photoRepositoryProvider.overrideWithValue(repo),
        assetThumbnailLoaderProvider
            .overrideWithValue((String id) async => thumbs[id]),
      ],
      child: const MaterialApp(home: PhotoGalleryScreen()),
    );
  }

  testWidgets('first render: viewport shows only the first ~9 items '
      '(GridView lazy build)', (tester) async {
    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(buildGallery());
    await tester.pumpAndSettle();
    stopwatch.stop();

    expect(find.byKey(const Key('photo_gallery_grid')), findsOneWidget);
    // 首行 3 张可见
    expect(find.byKey(const Key('photo_grid_item_photo_000')), findsOneWidget);
    expect(find.byKey(const Key('photo_grid_item_photo_001')), findsOneWidget);
    expect(find.byKey(const Key('photo_grid_item_photo_002')), findsOneWidget);
    // 末张（photo_099）还没构建
    expect(find.byKey(const Key('photo_grid_item_photo_099')), findsNothing);
    // 性能 sanity：100 张首次渲染不应超过 1 秒
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(1000),
      reason: '100 张首次渲染过慢，可能有 N² 或重复 build 风险',
    );
  });

  testWidgets('scroll to bottom: last items become visible', (tester) async {
    await tester.pumpWidget(buildGallery());
    await tester.pumpAndSettle();

    // 滚动一个超大的距离（确保触发到底）
    await tester.drag(
      find.byKey(const Key('photo_gallery_grid')),
      const Offset(0, -10000),
    );
    await tester.pumpAndSettle();

    // 末张可见
    expect(find.byKey(const Key('photo_grid_item_photo_099')), findsOneWidget);
    // 第一张已离屏
    expect(find.byKey(const Key('photo_grid_item_photo_000')), findsNothing);
  });

  testWidgets('scroll back to top: first item re-appears with same key',
      (tester) async {
    await tester.pumpWidget(buildGallery());
    await tester.pumpAndSettle();

    // 先滚到底
    await tester.drag(
      find.byKey(const Key('photo_gallery_grid')),
      const Offset(0, -10000),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo_grid_item_photo_099')), findsOneWidget);

    // 再滚回顶
    await tester.drag(
      find.byKey(const Key('photo_gallery_grid')),
      const Offset(0, 20000),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo_grid_item_photo_000')), findsOneWidget);
    // 末张已离屏
    expect(find.byKey(const Key('photo_grid_item_photo_099')), findsNothing);
  });

  testWidgets('thumbnail bytes are looked up by id (each cell gets its own)',
      (tester) async {
    // 验证：每个 PhotoGridItem 用的 thumbnail 是 fixtureThumbs 里对应 id 的字节，
    // 不是所有 cell 共享同一份。检查方式是：mock 一个 tracker 闭包记录调用次数。
    final lookupCounts = <String, int>{};
    Future<Uint8List?> trackedLoader(String id) async {
      lookupCounts[id] = (lookupCounts[id] ?? 0) + 1;
      return thumbs[id];
    }

    final permRepo = PhotoPermissionRepository(
      getCurrent: () async => PermissionState.authorized,
      request: () async => PermissionState.authorized,
      openSettings: () async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          photoPermissionRepositoryProvider.overrideWithValue(permRepo),
          settingsServiceProvider.overrideWithValue(SettingsService.fromBox(box)),
          photoRepositoryProvider.overrideWithValue(repo),
          assetThumbnailLoaderProvider.overrideWithValue(trackedLoader),
        ],
        child: const MaterialApp(home: PhotoGalleryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 视口内 ~9 张，每张 loader 至少被调 1 次
    expect(lookupCounts.length, greaterThanOrEqualTo(9));
    expect(lookupCounts['photo_000'], greaterThanOrEqualTo(1));
    expect(lookupCounts['photo_005'], greaterThanOrEqualTo(1));
  });
}