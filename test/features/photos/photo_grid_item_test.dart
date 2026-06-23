import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/photo_grid_item.dart';

/// Tests for [PhotoGridItem] — single cell of the photo gallery grid.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - Tapping the cell invokes [PhotoGridItem.onTap] (when provided).
/// - While the [thumbnailLoader] future is pending, a placeholder is shown.
/// - When the loader returns `null` (image damaged / system refused), a
///   placeholder is shown — the cell never crashes on missing thumbnails.
/// - When the loader returns bytes, [Image.memory] is rendered with those bytes.
/// - The cell keeps a 1:1 aspect ratio (gallery square tile).
void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  const photo = PhotoModel(id: 'a', path: '/DCIM/a.jpg');

  // 一个 1×1 透明 PNG（base64 编码）— 用来喂给 `Image.memory` 让 codec 成功。
  // 手搓字节容易写错；用合法最小 PNG 最稳。
  final tinyPng = Uint8List.fromList(
    base64.decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
    ),
  );

  group('PhotoGridItem — tap callback', () {
    testWidgets('forwards taps to onTap', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        wrap(
          PhotoGridItem(
            photo: photo,
            thumbnailLoader: (_) async => tinyPng,
            onTap: () => tapCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PhotoGridItem));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('tapping without onTap does not throw', (tester) async {
      await tester.pumpWidget(
        wrap(
          PhotoGridItem(
            photo: photo,
            thumbnailLoader: (_) async => tinyPng,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PhotoGridItem));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('PhotoGridItem — thumbnail loading', () {
    testWidgets('shows placeholder while the loader is pending',
        (tester) async {
      // 用一个永不 resolve 的 future，让我们能观察到 FutureBuilder 的"等待中"分支。
      await tester.pumpWidget(
        wrap(
          PhotoGridItem(
            photo: photo,
            thumbnailLoader: (_) => _never(),
          ),
        ),
      );
      await tester.pump(); // 启动 FutureBuilder，但不 resolve

      expect(
        find.byKey(const Key('photo_grid_item_placeholder')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('shows placeholder when loader returns null', (tester) async {
      await tester.pumpWidget(
        wrap(
          PhotoGridItem(
            photo: photo,
            thumbnailLoader: (_) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('photo_grid_item_placeholder')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders Image.memory when loader returns bytes',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          PhotoGridItem(
            photo: photo,
            thumbnailLoader: (_) async => tinyPng,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(
        find.byKey(const Key('photo_grid_item_placeholder')),
        findsNothing,
      );
    });
  });

  group('PhotoGridItem — layout', () {
    testWidgets('uses 1:1 aspect ratio (square tile)', (tester) async {
      // 父级给一个固定宽度，验证子级 AspectRatio 是 1:1。
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: PhotoGridItem(
                photo: photo,
                thumbnailLoader: (_) async => tinyPng,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final aspectRatio = tester.widget<AspectRatio>(
        find.byType(AspectRatio).first,
      );
      expect(aspectRatio.aspectRatio, 1);
    });
  });
}

/// 一个永不 resolve 的 future — 用于测 FutureBuilder 的"等待中"分支。
Future<Uint8List> _never() => Completer<Uint8List>().future;