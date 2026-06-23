import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/photo_viewer.dart';

import '../../test_utils/test_photo_fixtures.dart';

/// Tests for [PhotoViewer] — the InteractiveViewer + double-tap zoom widget.
///
/// **踩坑**：
/// - `tester.tap + pumpAndSettle` 在 widget test 里**永久 hang**——
///   `InteractiveViewer` 内部的 gesture detector 持续 schedule frame。
///   绕开：直接拿 GestureDetector 调 `onDoubleTap` 闭包，不走真实 pointer pipeline。
/// - `pumpAndSettle` 与 `InteractiveViewer` 不兼容 —— 所有测试只用 `pump()`。
/// - 每个测试自建 `bytes`，不共享 file-level future（避免后续测试 hang）。
void main() {
  Future<Uint8List> makeBytes() async {
    final map = await TestPhotoFixtures.thumbnailMap(count: 1);
    return map['photo_000']!;
  }

  Widget buildSubject({
    Uint8List? imageBytes,
    TransformationController? controller,
    double aspectRatio = 1.0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 400,
            child: PhotoViewer(
              imageBytes: imageBytes,
              aspectRatio: aspectRatio,
              transformationController: controller,
            ),
          ),
        ),
      ),
    );
  }

  group('PhotoViewer', () {
    testWidgets('shows placeholder when imageBytes is null', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byKey(const Key('photo_viewer_placeholder')), findsOneWidget);
      expect(find.byKey(const Key('photo_viewer_interactive')), findsNothing);
    });

    testWidgets('shows Image.memory when imageBytes is provided',
        (tester) async {
      final bytes = await makeBytes();
      await tester.pumpWidget(buildSubject(imageBytes: bytes));
      await tester.pump();

      expect(find.byKey(const Key('photo_viewer_placeholder')), findsNothing);
      expect(find.byKey(const Key('photo_viewer_interactive')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('double-tap zooms in to ~2.5× (matrix scale > 1)',
        (tester) async {
      final bytes = await makeBytes();
      final controller = TransformationController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildSubject(imageBytes: bytes, controller: controller),
      );
      await tester.pump();

      tester
          .widget<GestureDetector>(find.byType(GestureDetector).first)
          .onDoubleTap!();
      await tester.pump();

      expect(
        controller.value.getMaxScaleOnAxis(),
        greaterThan(1.5),
      );
    });

    testWidgets('double-tap while zoomed resets to identity', (tester) async {
      final bytes = await makeBytes();
      final controller = TransformationController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildSubject(imageBytes: bytes, controller: controller),
      );
      await tester.pump();

      tester
          .widget<GestureDetector>(find.byType(GestureDetector).first)
          .onDoubleTap!();
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.5));

      tester
          .widget<GestureDetector>(find.byType(GestureDetector).first)
          .onDoubleTap!();
      await tester.pump();

      expect(
        controller.value.getMaxScaleOnAxis(),
        closeTo(1.0, 0.01),
      );
    });

    testWidgets('renders without crash in initial state', (tester) async {
      final bytes = await makeBytes();
      await tester.pumpWidget(buildSubject(imageBytes: bytes));
      await tester.pump();

      expect(find.byKey(const Key('photo_viewer_interactive')), findsOneWidget);
    });
  });
}
