import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/data/repositories/photo_repository.dart';
import 'package:photo_beauty/features/photos/presentation/providers/full_image_loader_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photos_provider.dart';
import 'package:photo_beauty/features/photos/presentation/screens/photo_detail_screen.dart';

import '../../test_utils/test_photo_fixtures.dart';

/// Tests for [PhotoDetailScreen] — the route target for `/photo/:id`.
class _StubPhotosNotifier extends PhotosNotifier {
  _StubPhotosNotifier(this._data);
  final List<PhotoModel> _data;

  @override
  Future<List<PhotoModel>> build() async => _data;
}

class _MockRepo extends Mock implements PhotoRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  Future<Uint8List> makeBytes() async {
    final map = await TestPhotoFixtures.thumbnailMap(count: 1);
    return map['photo_000']!;
  }

  Widget buildSubject({
    required String assetId,
    required List<PhotoModel> photos,
    Uint8List? fullImage,
  }) {
    return ProviderScope(
      overrides: <Override>[
        photosProvider.overrideWith(() => _StubPhotosNotifier(photos)),
        photoRepositoryProvider.overrideWithValue(repo),
        fullImageLoaderProvider.overrideWithValue(
          (String id) async => fullImage,
        ),
      ],
      child: MaterialApp(
        home: PhotoDetailScreen(assetId: assetId),
      ),
    );
  }

  group('PhotoDetailScreen', () {
    testWidgets('success: renders PageView + BottomActionBar for valid id',
        (tester) async {
      final bytes = await makeBytes();
      final photos = TestPhotoFixtures.photos(count: 3);

      await tester.pumpWidget(
        buildSubject(
          assetId: photos[0].id,
          photos: photos,
          fullImage: bytes,
        ),
      );
      await tester.pump();

      expect(find.byType(PhotoDetailScreen), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(
        find.byKey(const Key('photo_detail_bottom_action_bar')),
        findsOneWidget,
      );
    });

    testWidgets('empty: photosProvider empty → gallery empty view',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          assetId: 'photo_000',
          photos: const <PhotoModel>[],
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('photo_detail_screen_empty')),
        findsOneWidget,
      );
      expect(find.byType(PageView), findsNothing);
    });

    // 避免 pumpAndSettle + InteractiveViewer 永久 hang（CLAUDE.md §7.11）：
    // PageView.builder 构建了所有 3 个 PhotoDetailPage（含 InteractiveViewer）。
    // InteractiveViewer 内部 AnimationController 持续驱动 frame 调度，
    // pumpAndSettle 永远等不到"没有待处理帧"。改用 pump() + 1s 动画超时。
    testWidgets(
      'delete current photo: confirm → PhotoRepository.delete + refresh',
      (tester) async {
        final bytes = await makeBytes();
        final photos = TestPhotoFixtures.photos(count: 3);
        when(() => repo.delete(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildSubject(
            assetId: photos[0].id,
            photos: photos,
            fullImage: bytes,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('photo_detail_action_delete')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byKey(const Key('photo_detail_delete_dialog')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('photo_detail_delete_confirm')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        verify(() => repo.delete(photos[0].id)).called(1);
      },
    );

    testWidgets('delete current photo: cancel → no delete called',
        (tester) async {
      final bytes = await makeBytes();
      final photos = TestPhotoFixtures.photos(count: 3);

      await tester.pumpWidget(
        buildSubject(
          assetId: photos[0].id,
          photos: photos,
          fullImage: bytes,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('photo_detail_action_delete')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('photo_detail_delete_cancel')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verifyNever(() => repo.delete(any()));
    });
  });
}
