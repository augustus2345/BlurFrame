import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photo_beauty/features/albums/data/models/album_model.dart';
import 'package:photo_beauty/features/albums/presentation/providers/album_list_provider.dart';
import 'package:photo_beauty/features/albums/presentation/screens/album_list_screen.dart';
import 'package:photo_beauty/features/photos/presentation/providers/asset_thumbnail_loader_provider.dart';

void main() {
  group('AlbumListScreen', () {
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
        photoIds: ['photo_003', 'photo_004', 'photo_005'],
        createdAt: DateTime(2026, 1, 2),
        layout: AlbumLayout.magazine,
      ),
    ];

    testWidgets('loading 态显示 CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(() => _LoadingAlbumListNotifier()),
          ],
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty 态显示 EmptyState', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(() => _EmptyAlbumListNotifier()),
          ],
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('还没有影集'), findsOneWidget);
      expect(
        find.text('从相册里多选几张照片，组成一个好看的影集'),
        findsOneWidget,
      );
    });

    testWidgets('success 态显示 2 列网格', (tester) async {
      final thumbs = <String, Uint8List>{};
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(
              () => _SuccessAlbumListNotifier(testAlbums),
            ),
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => thumbs[id],
            ),
          ],
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byKey(const Key('album_grid_item_album_001')), findsOneWidget);
      expect(find.byKey(const Key('album_grid_item_album_002')), findsOneWidget);
    });

    testWidgets('error 态显示错误视图和重试按钮', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumListProvider.overrideWith(() => _ErrorAlbumListNotifier()),
          ],
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('右上角 + 按钮存在', (tester) async {
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
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    // ========== 删除影集测试 ==========

    testWidgets('长按影集卡片显示删除选项', (tester) async {
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
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 长按第一个影集卡片
      await tester.longPress(
        find.byKey(const Key('album_grid_item_album_001')),
      );
      await tester.pumpAndSettle();

      // 应该看到删除选项
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('点击长按菜单的删除显示确认对话框', (tester) async {
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
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 长按第一个影集卡片
      await tester.longPress(
        find.byKey(const Key('album_grid_item_album_001')),
      );
      await tester.pumpAndSettle();

      // 点击删除选项
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 确认对话框应该显示
      expect(find.text('确认删除'), findsOneWidget);
    });

    testWidgets('点击取消关闭对话框不删除', (tester) async {
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
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 长按第一个影集卡片
      await tester.longPress(
        find.byKey(const Key('album_grid_item_album_001')),
      );
      await tester.pumpAndSettle();

      // 点击删除选项
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 点击取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 对话框应该关闭
      expect(find.text('确认删除'), findsNothing);
    });

    testWidgets('确认删除后显示成功 snackbar', (tester) async {
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
          child: const MaterialApp(home: AlbumListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 长按第一个影集卡片
      await tester.longPress(
        find.byKey(const Key('album_grid_item_album_001')),
      );
      await tester.pumpAndSettle();

      // 点击删除选项
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 点击确认删除
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();

      // 应该显示成功 snackbar
      expect(find.textContaining('已删除'), findsOneWidget);
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
