import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photos_provider.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/photo_detail_page.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/photo_viewer.dart';

import '../../test_utils/test_photo_fixtures.dart';

/// Tests for [PhotoDetailPage] — single page inside the detail PageView.
class _StubPhotosNotifier extends PhotosNotifier {
  _StubPhotosNotifier(this._data);
  final List<PhotoModel> _data;

  @override
  Future<List<PhotoModel>> build() async => _data;
}

void main() {
  Future<Uint8List> makeBytes() async {
    final map = await TestPhotoFixtures.thumbnailMap(count: 1);
    return map['photo_000']!;
  }

  Widget buildSubject({
    required String assetId,
    required Future<Uint8List?> Function(String) fullImageLoader,
    required List<PhotoModel> photos,
  }) {
    return ProviderScope(
      overrides: <Override>[
        photosProvider.overrideWith(() => _StubPhotosNotifier(photos)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PhotoDetailPage(
            assetId: assetId,
            fullImageLoader: fullImageLoader,
          ),
        ),
      ),
    );
  }

  group('PhotoDetailPage', () {
    testWidgets('loading: fullImageLoader pending → spinner', (tester) async {
      final bytes = await makeBytes();
      final photos = TestPhotoFixtures.photos(count: 1);
      final pending = Completer<Uint8List?>();

      await tester.pumpWidget(
        buildSubject(
          assetId: photos.first.id,
          fullImageLoader: (_) => pending.future,
          photos: photos,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('photo_detail_page_loading')), findsOneWidget);

      pending.complete(bytes);
      await tester.pump();
    });

    testWidgets('error: fullImageLoader throws → error view', (tester) async {
      final photos = TestPhotoFixtures.photos(count: 1);

      await tester.pumpWidget(
        buildSubject(
          assetId: photos.first.id,
          fullImageLoader: (_) async => throw StateError('boom'),
          photos: photos,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_detail_page_error')), findsOneWidget);
      expect(find.text('加载失败'), findsOneWidget);
    });

    testWidgets('empty: photo not in gallery → not found view', (tester) async {
      final photos = TestPhotoFixtures.photos(count: 2);

      await tester.pumpWidget(
        buildSubject(
          assetId: 'photo_999',
          fullImageLoader: (_) async => null,
          photos: photos,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('photo_detail_page_not_found')), findsOneWidget);
    });

    testWidgets('success: bytes loaded → PhotoDetailContent renders',
        (tester) async {
      final bytes = await makeBytes();
      final photos = TestPhotoFixtures.photos(count: 1);

      await tester.pumpWidget(
        buildSubject(
          assetId: photos.first.id,
          fullImageLoader: (_) async => bytes,
          photos: photos,
        ),
      );
      await tester.pumpAndSettle();

      // PhotoDetailPage 现在内部渲染 PhotoDetailContent
      expect(find.byType(PhotoDetailPage), findsOneWidget);
      // PhotoDetailContent 包含 PhotoViewer（图片查看器）
      expect(find.byType(PhotoViewer), findsOneWidget);
    });
  });
}