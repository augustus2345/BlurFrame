import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/presentation/widgets/editor_subwidgets/blur_border_editor.dart';

/// Widget tests for [BlurBorderEditor] (M2-T4)。
///
/// 覆盖：强度滑块 / 仅边缘开关 / 参数变化回调。
void main() {
  group('BlurBorderEditor', () {
    testWidgets('renders intensity slider and edge-only switch',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlurBorderEditor(
              layer: BlurBorderLayer(intensity: 5.0, edge: true),
              onIntensityChanged: (_) {},
              onEdgeOnlyChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('blur_intensity_slider')), findsOneWidget);
      expect(find.byKey(const Key('blur_edge_only_switch')), findsOneWidget);
      expect(find.text('强度'), findsOneWidget);
      expect(find.text('仅边缘'), findsOneWidget);
      // Slider label shows intensity
      expect(find.text('5.0'), findsOneWidget);
    });

    testWidgets('slider reflects layer intensity value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlurBorderEditor(
              layer: BlurBorderLayer(intensity: 3.5, edge: false),
              onIntensityChanged: (_) {},
              onEdgeOnlyChanged: (_) {},
            ),
          ),
        ),
      );

      // The value label in the slider row
      expect(find.text('3.5'), findsOneWidget);
      // Switch should be off (edge=false)
      final switchTile = tester.widget<SwitchListTile>(
        find.byKey(const Key('blur_edge_only_switch')),
      );
      expect(switchTile.value, isFalse);
    });

    testWidgets('dragging slider triggers onIntensityChanged',
        (tester) async {
      double? reportedIntensity;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlurBorderEditor(
              layer: BlurBorderLayer(intensity: 0.0, edge: false),
              onIntensityChanged: (v) => reportedIntensity = v,
              onEdgeOnlyChanged: (_) {},
            ),
          ),
        ),
      );

      // Drag the slider to the right (increase intensity).
      // The slider is at position 5/10 = 0.5 by default for value 0.0.
      // We drag from center to near max.
      final slider = find.byKey(const Key('blur_intensity_slider'));
      // Drag right — from 50% to 80% of width.
      await tester.drag(slider, const Offset(100, 0));
      await tester.pump();

      expect(reportedIntensity, isNotNull);
      // Intensity should have increased from 0.0
      expect(reportedIntensity, greaterThan(0));
    });

    testWidgets('tapping switch triggers onEdgeOnlyChanged', (tester) async {
      bool? reportedEdge;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlurBorderEditor(
              layer: BlurBorderLayer(intensity: 5.0, edge: false),
              onIntensityChanged: (_) {},
              onEdgeOnlyChanged: (v) => reportedEdge = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('blur_edge_only_switch')));
      await tester.pump();

      expect(reportedEdge, isTrue);
    });

    testWidgets('intensity > 10 renders without crashing', (tester) async {
      // intensity 15.0 is above the slider max (10); widget should still render
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlurBorderEditor(
              layer: BlurBorderLayer(intensity: 15.0, edge: true),
              onIntensityChanged: (_) {},
              onEdgeOnlyChanged: (_) {},
            ),
          ),
        ),
      );

      // Should not crash; slider and switch should be present
      expect(find.byKey(const Key('blur_intensity_slider')), findsOneWidget);
      expect(find.byKey(const Key('blur_edge_only_switch')), findsOneWidget);
    });
  });
}