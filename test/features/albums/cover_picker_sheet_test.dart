import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/albums/presentation/widgets/cover_picker_sheet.dart';

import 'package:photo_beauty/features/photos/presentation/providers/asset_thumbnail_loader_provider.dart';

import '../../test_utils/test_photo_fixtures.dart';

void main() {
  final photos = TestPhotoFixtures.photos(count: 9);
  final thumbs = <String, Uint8List>{};

  setUpAll(() async {
    final thumbMap = await TestPhotoFixtures.thumbnailMap(count: 9);
    thumbs.addAll(thumbMap);
  });

  Widget buildSheet({
    required String albumId,
    required List<String> photoIds,
    String? currentCoverPhotoId,
  }) {
    return ProviderScope(
      overrides: [
        assetThumbnailLoaderProvider.overrideWithValue(
          (String id) async => thumbs[id],
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CoverPickerSheet(
            albumId: albumId,
            photoIds: photoIds,
            currentCoverPhotoId: currentCoverPhotoId ?? '',
          ),
        ),
      ),
    );
  }

  group('CoverPickerSheet', () {
    testWidgets('显示标题', (tester) async {
      await tester.pumpWidget(buildSheet(
        albumId: 'album-1',
        photoIds: photos.map((p) => p.id).toList(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('选择封面'), findsOneWidget);
    });

    testWidgets('显示拖拽条', (tester) async {
      await tester.pumpWidget(buildSheet(
        albumId: 'album-1',
        photoIds: photos.map((p) => p.id).toList(),
      ));
      await tester.pumpAndSettle();

      // 拖拽条在顶部
      final dragHandle = find.byType(Container).first;
      expect(dragHandle, findsOneWidget);
    });

    testWidgets('网格显示照片', (tester) async {
      await tester.pumpWidget(buildSheet(
        albumId: 'album-1',
        photoIds: photos.map((p) => p.id).toList(),
      ));
      await tester.pumpAndSettle();

      // viewport 可见的 FutureBuilder 数量（不一定全部 9 张）
      expect(find.byType(FutureBuilder<Uint8List?>), findsWidgets);
    });

    testWidgets('当前封面照片显示勾选标记', (tester) async {
      final coverPhotoId = photos[4].id; // 选择中间一张作为封面
      await tester.pumpWidget(buildSheet(
        albumId: 'album-1',
        photoIds: photos.map((p) => p.id).toList(),
        currentCoverPhotoId: coverPhotoId,
      ));
      await tester.pumpAndSettle();

      // 封面照片上有 check_circle 图标
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('点击照片关闭弹窗并返回 photoId', (tester) async {
      String? returnedPhotoId;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetThumbnailLoaderProvider.overrideWithValue(
              (String id) async => thumbs[id],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    returnedPhotoId = await showModalBottomSheet<String>(
                      context: context,
                      builder: (context) => CoverPickerSheet(
                        albumId: 'album-1',
                        photoIds: photos.map((p) => p.id).toList(),
                        currentCoverPhotoId: photos[0].id,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 点击第一张照片
      final futureBuilder = find.byType(FutureBuilder<Uint8List?>).first;
      expect(futureBuilder, findsOneWidget);

      // 点击第一张照片的父级 GestureDetector
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pumpAndSettle();

      expect(returnedPhotoId, photos[0].id);
    });

    testWidgets('空影集显示空网格', (tester) async {
      await tester.pumpWidget(buildSheet(
        albumId: 'album-empty',
        photoIds: [],
      ));
      await tester.pumpAndSettle();

      // 没有 FutureBuilder（没有照片）
      expect(find.byType(FutureBuilder<Uint8List?>), findsNothing);
    });
  });
}
