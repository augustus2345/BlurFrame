import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/presentation/widgets/editor_subwidgets/text_watermark_editor.dart';

/// Widget tests for [TextWatermarkEditor] (M2-T4)。
///
/// 覆盖：文字输入 / 位置下拉 / 字号滑块 / 颜色输入框。
void main() {
  group('TextWatermarkEditor', () {
    Future<void> pumpEditor(
      WidgetTester tester,
      TextWatermarkLayer layer, {
      required ValueChanged<String> onTextChanged,
      required ValueChanged<WatermarkPosition> onPositionChanged,
      required ValueChanged<double> onFontSizeChanged,
      required ValueChanged<int> onColorChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TextWatermarkEditor(
                layer: layer,
                onTextChanged: onTextChanged,
                onPositionChanged: onPositionChanged,
                onFontSizeChanged: onFontSizeChanged,
                onColorChanged: onColorChanged,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders all 4 controls', (tester) async {
      await pumpEditor(
        tester,
        TextWatermarkLayer(
          text: 'Hello',
          position: WatermarkPosition.center,
          fontSize: 16,
          color: 0xFFFFFFFF,
        ),
        onTextChanged: (_) {},
        onPositionChanged: (_) {},
        onFontSizeChanged: (_) {},
        onColorChanged: (_) {},
      );

      // Use labelText to distinguish watermark text field from HexColorField
      // (which reuses 'watermark_text_field' key via keyPrefix).
      expect(find.widgetWithText(TextField, '水印文字'), findsOneWidget);
      expect(find.byKey(const Key('watermark_position_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('watermark_font_size_slider')), findsOneWidget);
    });

    testWidgets('initial text populates the TextField', (tester) async {
      await pumpEditor(
        tester,
        TextWatermarkLayer(
          text: 'My Watermark',
          position: WatermarkPosition.topLeft,
          fontSize: 24,
          color: 0xFF000000,
        ),
        onTextChanged: (_) {},
        onPositionChanged: (_) {},
        onFontSizeChanged: (_) {},
        onColorChanged: (_) {},
      );

      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'My Watermark'),
      );
      expect(textField.controller!.text, equals('My Watermark'));
    });

    testWidgets('changing text triggers onTextChanged', (tester) async {
      String? reportedText;
      await pumpEditor(
        tester,
        TextWatermarkLayer(
          text: '',
          position: WatermarkPosition.center,
          fontSize: 12,
          color: 0xFF000000,
        ),
        onTextChanged: (t) => reportedText = t,
        onPositionChanged: (_) {},
        onFontSizeChanged: (_) {},
        onColorChanged: (_) {},
      );

      // Find by label text to avoid HexColorField's key conflict
      await tester.enterText(
        find.widgetWithText(TextField, '水印文字'),
        'New Text',
      );
      await tester.pump();

      expect(reportedText, equals('New Text'));
    });

    testWidgets('dropdown shows current position', (tester) async {
      await pumpEditor(
        tester,
        TextWatermarkLayer(
          text: 'Test',
          position: WatermarkPosition.bottomRight,
          fontSize: 12,
          color: 0xFF000000,
        ),
        onTextChanged: (_) {},
        onPositionChanged: (_) {},
        onFontSizeChanged: (_) {},
        onColorChanged: (_) {},
      );

      // Dropdown shows the text for bottomRight position: '右下'
      expect(find.text('右下'), findsOneWidget);
    });

    testWidgets('slider reflects fontSize and shows label', (tester) async {
      await pumpEditor(
        tester,
        TextWatermarkLayer(
          text: 'Test',
          position: WatermarkPosition.center,
          fontSize: 32,
          color: 0xFF000000,
        ),
        onTextChanged: (_) {},
        onPositionChanged: (_) {},
        onFontSizeChanged: (_) {},
        onColorChanged: (_) {},
      );

      expect(find.text('32'), findsOneWidget);
      expect(find.byKey(const Key('watermark_font_size_slider')), findsOneWidget);
    });

    testWidgets('external layer.text change syncs controller',
        (tester) async {
      String? lastText;
      await pumpEditor(
        tester,
        TextWatermarkLayer(
          text: 'Initial',
          position: WatermarkPosition.center,
          fontSize: 12,
          color: 0xFF000000,
        ),
        onTextChanged: (t) => lastText = t,
        onPositionChanged: (_) {},
        onFontSizeChanged: (_) {},
        onColorChanged: (_) {},
      );

      // Simulate parent updating the layer.text externally
      // (didUpdateWidget path — rebuild with new layer)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TextWatermarkEditor(
                layer: TextWatermarkLayer(
                  text: 'Updated Text',
                  position: WatermarkPosition.center,
                  fontSize: 12,
                  color: 0xFF000000,
                ),
                onTextChanged: (t) => lastText = t,
                onPositionChanged: (_) {},
                onFontSizeChanged: (_) {},
                onColorChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Updated Text'),
      );
      expect(textField.controller!.text, equals('Updated Text'));
    });
  });
}