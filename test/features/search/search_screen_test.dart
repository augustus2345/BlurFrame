import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/presentation/providers/asset_thumbnail_loader_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photos_provider.dart';
import 'package:photo_beauty/features/search/data/models/search_filter.dart';
import 'package:photo_beauty/features/search/presentation/providers/search_provider.dart';
import 'package:photo_beauty/features/search/presentation/screens/search_screen.dart';
import 'package:photo_beauty/features/search/presentation/widgets/filter_chip_bar.dart';
import 'package:photo_beauty/features/search/presentation/widgets/star_rating_filter_sheet.dart';

void main() {
  group('SearchScreen', () {
    testWidgets('显示 FilterChipBar + loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photosProvider.overrideWith(() => _LoadingPhotosNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/search',
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const SearchScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(FilterChipBar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('空照片显示 EmptyState', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photosProvider.overrideWith(() => _EmptyPhotosNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/search',
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const SearchScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_empty_state')), findsOneWidget);
      expect(find.text('从上方选择过滤条件开始搜索'), findsOneWidget);
    });

    testWidgets('有照片时显示网格', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photosProvider.overrideWith(() => _PhotosNotifier([
              _makePhoto('ph1'),
              _makePhoto('ph2'),
            ])),
            assetThumbnailLoaderProvider.overrideWithValue(
              (_) async => _tinyPngBytes(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/search',
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const SearchScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_results_grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('search_photo_ph1')), findsOneWidget);
      expect(find.byKey(const ValueKey('search_photo_ph2')), findsOneWidget);
    });

    testWidgets('星级 filter chip 点击弹出 sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photosProvider.overrideWith(() => _PhotosNotifier([_makePhoto('x')])),
            assetThumbnailLoaderProvider.overrideWithValue(
              (_) async => _tinyPngBytes(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/search',
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const SearchScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('星级'));
      await tester.pumpAndSettle();

      expect(find.byType(StarRatingFilterSheet), findsOneWidget);
    });
  });
}

// ---- Test fixtures ----

Uint8List _tinyPngBytes() {
  // 1×1 透明 PNG from CLAUDE.md §7.13
  return Uint8List.fromList(const [
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
    0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x60, 0x60, 0x60, 0x60,
    0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0x87, 0xa1, 0x4e, 0xd4, 0x00, 0x00,
    0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
  ]);
}

PhotoModel _makePhoto(String id) {
  return PhotoModel(
    id: id,
    path: '/test/$id.jpg',
    width: 100,
    height: 100,
    takenAt: DateTime(2024, 1, 1),
    tags: const [],
    starRating: 0,
  );
}

/// Loading notifier — build returns a Future that never completes.
class _LoadingPhotosNotifier extends PhotosNotifier {
  @override
  Future<List<PhotoModel>> build() {
    return Completer<List<PhotoModel>>().future;
  }

  @override
  Future<void> refresh() async {}
}

class _EmptyPhotosNotifier extends PhotosNotifier {
  @override
  Future<List<PhotoModel>> build() async => [];
}

class _PhotosNotifier extends PhotosNotifier {
  _PhotosNotifier(this._photos);
  final List<PhotoModel> _photos;

  @override
  Future<List<PhotoModel>> build() async => _photos;
}