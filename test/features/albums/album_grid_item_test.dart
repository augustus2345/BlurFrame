import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_beauty/features/albums/data/models/album_model.dart';
import 'package:photo_beauty/features/albums/presentation/widgets/album_grid_item.dart';

void main() {
  group('AlbumGridItem', () {
    late AlbumModel album;

    setUp(() {
      album = AlbumModel(
        id: 'album_001',
        name: '我的旅行',
        coverPhotoId: 'photo_001',
        photoIds: ['photo_001', 'photo_002', 'photo_003'],
        createdAt: DateTime(2026, 1, 1),
        layout: AlbumLayout.grid,
      );
    });

    Future<Uint8List?> makeBytes() async {
      // 1×1 透明 PNG
      return Uint8List.fromList(base64.decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
      ));
    }

    testWidgets('tap 回调触发', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) async => null,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AlbumGridItem));
      expect(tapped, isTrue);
    });

    testWidgets('无 onTap 不抛错', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) async => null,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AlbumGridItem));
      // 无 onTap 时调用 setState 但什么都不做，不抛错
    });

    testWidgets('loading 时显示占位', (tester) async {
      final completer = Completer<Uint8List?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) => completer.future,
            ),
          ),
        ),
      );
      // Future 未完成，应显示占位
      expect(find.byKey(const Key('album_grid_item_placeholder')), findsOneWidget);
    });

    testWidgets('bytes 渲染 Image.memory', (tester) async {
      final bytes = await makeBytes();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) async => bytes,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('无封面时显示占位', (tester) async {
      final noCoverAlbum = AlbumModel(
        id: 'album_002',
        name: '空影集',
        coverPhotoId: '',
        photoIds: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: noCoverAlbum,
              thumbnailLoader: (_) async => null,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('album_grid_item_placeholder')), findsOneWidget);
    });

    testWidgets('1:1 比例', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) async => null,
            ),
          ),
        ),
      );
      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, equals(1));
    });

    testWidgets('isSelected 显示勾选', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) async => null,
              isSelected: true,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('isSelected=false 隐藏勾选', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) async => null,
              isSelected: false,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('onLongPress 触发', (tester) async {
      var longPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) async => null,
              onLongPress: () => longPressed = true,
            ),
          ),
        ),
      );
      await tester.longPress(find.byType(AlbumGridItem));
      expect(longPressed, isTrue);
    });

    testWidgets('无 onLongPress 不抛错', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumGridItem(
              album: album,
              thumbnailLoader: (_) async => null,
            ),
          ),
        ),
      );
      await tester.longPress(find.byType(AlbumGridItem));
      // 无 onLongPress 时什么都不做，不抛错
    });
  });
}