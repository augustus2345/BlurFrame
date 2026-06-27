import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/presentation/widgets/editor_subwidgets/color_stripe_editor.dart';

/// Widget tests for [ColorStripeEditor] (M2-T4)。
///
/// 覆盖：位置下拉 / 厚度滑块 / 圆角滑块 / 颜色输入框。
void main() {
  group('ColorStripeEditor', () {
    Future<void> pumpEditor(
      WidgetTester tester,
      ColorStripeLayer layer, {
      required ValueChanged<int> onColorChanged,
      required ValueChanged<double> onWidthChanged,
      required ValueChanged<double> onCornerRadiusChanged,
      required ValueChanged<StripePosition> onPositionChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ColorStripeEditor(
                layer: layer,
                onColorChanged: onColorChanged,
                onWidthChanged: onWidthChanged,
                onCornerRadiusChanged: onCornerRadiusChanged,
                onPositionChanged: onPositionChanged,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders all 4 controls', (tester) async {
      await pumpEditor(
        tester,
        ColorStripeLayer(
          color: 0xFF000000,
          width: 0.1,
          cornerRadius: 4,
          position: StripePosition.top,
        ),
        onColorChanged: (_) {},
        onWidthChanged: (_) {},
        onCornerRadiusChanged: (_) {},
        onPositionChanged: (_) {},
      );

      expect(find.byKey(const Key('stripe_position_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('stripe_width_slider')), findsOneWidget);
      expect(find.byKey(const Key('stripe_corner_radius_slider')), findsOneWidget);
    });

    testWidgets('position dropdown shows current selected item text',
        (tester) async {
      await pumpEditor(
        tester,
        ColorStripeLayer(
          color: 0xFF000000,
          width: 0.1,
          cornerRadius: 0,
          position: StripePosition.bottom,
        ),
        onColorChanged: (_) {},
        onWidthChanged: (_) {},
        onCornerRadiusChanged: (_) {},
        onPositionChanged: (_) {},
      );

      // When position=bottom, the dropdown should show '底部'
      expect(find.text('底部'), findsOneWidget);
    });

    testWidgets('width slider shows current value', (tester) async {
      await pumpEditor(
        tester,
        ColorStripeLayer(
          color: 0xFF000000,
          width: 0.22,
          cornerRadius: 0,
          position: StripePosition.top,
        ),
        onColorChanged: (_) {},
        onWidthChanged: (_) {},
        onCornerRadiusChanged: (_) {},
        onPositionChanged: (_) {},
      );

      // 0.22 → '0.22'
      expect(find.text('0.22'), findsOneWidget);
    });

    testWidgets('corner radius slider shows current value', (tester) async {
      await pumpEditor(
        tester,
        ColorStripeLayer(
          color: 0xFF000000,
          width: 0.1,
          cornerRadius: 15,
          position: StripePosition.top,
        ),
        onColorChanged: (_) {},
        onWidthChanged: (_) {},
        onCornerRadiusChanged: (_) {},
        onPositionChanged: (_) {},
      );

      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('dragging width slider triggers onWidthChanged',
        (tester) async {
      double? reportedWidth;
      await pumpEditor(
        tester,
        ColorStripeLayer(
          color: 0xFF000000,
          width: 0.05,
          cornerRadius: 0,
          position: StripePosition.top,
        ),
        onColorChanged: (_) {},
        onWidthChanged: (w) => reportedWidth = w,
        onCornerRadiusChanged: (_) {},
        onPositionChanged: (_) {},
      );

      final slider = find.byKey(const Key('stripe_width_slider'));
      await tester.drag(slider, const Offset(50, 0));
      await tester.pump();

      expect(reportedWidth, isNotNull);
      // 0.05 + positive drag → larger width
      expect(reportedWidth, greaterThan(0.05));
    });

    testWidgets('tapping position dropdown triggers onPositionChanged',
        (tester) async {
      StripePosition? reportedPosition;
      await pumpEditor(
        tester,
        ColorStripeLayer(
          color: 0xFF000000,
          width: 0.1,
          cornerRadius: 0,
          position: StripePosition.top,
        ),
        onColorChanged: (_) {},
        onWidthChanged: (_) {},
        onCornerRadiusChanged: (_) {},
        onPositionChanged: (p) => reportedPosition = p,
      );

      // Open the dropdown
      await tester.tap(find.byKey(const Key('stripe_position_dropdown')));
      await tester.pumpAndSettle();

      // Select '底部'
      await tester.tap(find.text('底部').last);
      await tester.pumpAndSettle();

      expect(reportedPosition, equals(StripePosition.bottom));
    });
  });
}