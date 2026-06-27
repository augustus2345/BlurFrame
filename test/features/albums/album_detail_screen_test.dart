import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photo_beauty/features/albums/data/models/album_model.dart';
import 'package:photo_beauty/features/albums/presentation/providers/album_list_provider.dart';
import 'package:photo_beauty/features/albums/presentation/screens/album_detail_screen.dart';
import 'package:photo_beauty/features/photos/presentation/providers/asset_thumbnail_loader_provider.dart';

void main() {
  group('AlbumDetailScreen', () {
    final testAlbums = [
      AlbumModel(
        id: 'album_001',
        name: '旅行影集',
        coverPhotoId: 'photo_001',
        photoIds: ['photo_001', 'photo_002'],
        createdAt: DateTime(2026, 1, 1),
        layout: AlbumLayout.grid,
      ),
      AlbumModel(
        id: 'album_002',
        name: '家庭聚会',
        coverPhotoId: 'photo_003',
        photoIds: [
          'photo_003',
          'photo_004',
          'photo_005',
          'photo_006',
          'photo_007',
        ],
        createdAt: DateTime(2026, 1, 2),
        layout: AlbumLayout.magazine,
      ),
      AlbumModel(
        id: 'album_003',
        name: '单张照片',
        coverPhotoId: 'photo_010',
        photoIds: ['photo_010'],
        createdAt: DateTime(2026, 1, 3),
        layout: AlbumLayout.polaroid,
      ),
      AlbumModel(
        id: 'album_004',
        name: '空影集',
        coverPhotoId: '',
        photoIds: [],
        createdAt: DateTime(2026, 1, 4),
        layout: AlbumLayout.collage,
      ),
    ];

    testWidgets('loading 态显示 CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(() => _LoadingAlbumListNotifier()),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'album_001'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error 态显示错误视图和重试按钮', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(() => _ErrorAlbumListNotifier()),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'album_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('影集不存在时显示"影集不存在"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => null,
            ),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'not_existing_id'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('影集不存在'), findsOneWidget);
    });

    testWidgets('空影集显示 EmptyState', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => null,
            ),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'album_004'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('影集为空'), findsOneWidget);
      expect(find.text('还没有添加照片'), findsOneWidget);
    });

    testWidgets('1 张照片 → 1 宫格', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => null,
            ),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'album_003'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 1);
    });

    testWidgets('2 张照片 → 2 宫格', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => null,
            ),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'album_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('5+ 照片 → 2 列可滚动网格', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => null,
            ),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'album_002'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('手动切换 4 宫格', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => null,
            ),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'album_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 初始是 2 宫格
      var gridView = tester.widget<GridView>(find.byType(GridView));
      var delegate = gridView.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);

      // 点击版式切换按钮
      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();

      // 选择 4 宫格
      await tester.tap(find.text('4 宫格'));
      await tester.pumpAndSettle();

      gridView = tester.widget<GridView>(find.byType(GridView));
      delegate = gridView.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 4);
    });

    testWidgets('点击照片跳转详情页', (tester) async {
      final router = GoRouter(
        initialLocation: '/albums/album_003',
        routes: [
          GoRoute(
            path: '/albums/:id',
            builder: (context, state) =>
                AlbumDetailScreen(albumId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/photo/:id',
            builder: (context, state) => Scaffold(
              body: Text('photo_detail_${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => null,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // 点击第一张照片格子
      await tester.tap(find.byKey(const Key('album_photo_tile_photo_010')));
      await tester.pumpAndSettle();

      expect(find.text('photo_detail_photo_010'), findsOneWidget);
    });

    testWidgets('AppBar 显示影集名称', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => null,
            ),
          ],
          child: MaterialApp(
            home: AlbumDetailScreen(albumId: 'album_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('旅行影集'), findsOneWidget);
    });
  });

  group('autoLayout', () {
    test('1 张 → 1 宫格', () {
      expect(autoLayout(1), 1);
    });
    test('2 张 → 2 宫格', () {
      expect(autoLayout(2), 2);
    });
    test('3 张 → 4 宫格', () {
      expect(autoLayout(3), 4);
    });
    test('4 张 → 4 宫格', () {
      expect(autoLayout(4), 4);
    });
    test('5 张 → 2 列', () {
      expect(autoLayout(5), 2);
    });
    test('100 张 → 2 列', () {
      expect(autoLayout(100), 2);
    });
  });
}

// --- Test notifier helpers ---

class _LoadingAlbumListNotifier extends AlbumListNotifier {
  @override
  Future<List<AlbumModel>> build() => Completer<List<AlbumModel>>().future;
  @override
  Future<void> refresh() async {}
}

class _EmptyAlbumListNotifier extends AlbumListNotifier {
  @override
  Future<List<AlbumModel>> build() async => [];
  @override
  Future<void> refresh() async {}
}

class _SuccessAlbumListNotifier extends AlbumListNotifier {
  _SuccessAlbumListNotifier(this._albums);
  final List<AlbumModel> _albums;

  @override
  Future<List<AlbumModel>> build() async => _albums;
  @override
  Future<void> refresh() async {}
}

class _ErrorAlbumListNotifier extends AlbumListNotifier {
  @override
  Future<List<AlbumModel>> build() async => throw Exception('test error');
  @override
  Future<void> refresh() async {}
}