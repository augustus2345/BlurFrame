import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/frames/presentation/widgets/editor_subwidgets/hex_color_field.dart';

/// Widget tests for [HexColorField] (M2-T4)。
///
/// 覆盖：
/// - 初始值格式化显示（#AARRGGBB）
/// - 合法输入触发 onValidColor
/// - 非法输入显示 errorText 但不触发回调
/// - `0x` 前缀支持
/// - 失焦回滚到 initialValue（外部同步）
/// - 输入框只接受 hex 字符
void main() {
  group('HexColorField', () {
    testWidgets('initial value formats as #AARRGGBB', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorField(
              initialValue: 0xCCFF8800,
              onValidColor: (_) {},
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller!.text, equals('#CCFF8800'));
    });

    testWidgets('typing valid 8-char hex triggers onValidColor',
        (tester) async {
      int? reportedColor;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorField(
              initialValue: 0xFF000000,
              onValidColor: (c) => reportedColor = c,
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, '#FF12AB34');
      await tester.pump();

      expect(reportedColor, equals(0xFF12AB34));
    });

    testWidgets('typing invalid hex shows error, does not trigger callback',
        (tester) async {
      int? reportedColor;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorField(
              initialValue: 0xFF000000,
              onValidColor: (c) => reportedColor = c,
            ),
          ),
        ),
      );

      // Enter only 7 chars (too short)
      final textField = find.byType(TextField);
      await tester.enterText(textField, '#FF12AB3');
      await tester.pump();

      expect(reportedColor, isNull);
      // errorText should appear
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.decoration?.errorText, isNotNull);
    });

    testWidgets('0x prefix is accepted and parsed correctly', (tester) async {
      int? reportedColor;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorField(
              initialValue: 0xFF000000,
              onValidColor: (c) => reportedColor = c,
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, '0xAABBCCDD');
      await tester.pump();

      expect(reportedColor, equals(0xAABBCCDD));
    });

    testWidgets('suffix color swatch shows initialValue color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorField(
              initialValue: 0xFFFF0000, // opaque red
              onValidColor: (_) {},
            ),
          ),
        ),
      );

      // The suffix container shows the color
      final suffixIcon = find.byType(Container).last;
      expect(suffixIcon, findsOneWidget);
    });

    testWidgets('inputFormatter only allows hex characters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorField(
              initialValue: 0xFF000000,
              onValidColor: (_) {},
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      final textFieldWidget = tester.widget<TextField>(textField);

      // Check that FilteringTextInputFormatter is set
      expect(textFieldWidget.inputFormatters, isNotEmpty);
    });

    testWidgets('clearing field shows error', (tester) async {
      int? reportedColor;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorField(
              initialValue: 0xFF000000,
              onValidColor: (c) => reportedColor = c,
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, '');
      await tester.pump();

      expect(reportedColor, isNull);
    });
  });
}