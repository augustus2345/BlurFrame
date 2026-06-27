import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/frames/presentation/widgets/layer_switch_group.dart';

/// Widget tests for [LayerSwitchGroup] (M2-T4).
///
/// 覆盖：
/// - 渲染标题 + Switch + 参数区 / 关闭提示
/// - 切换 Switch → onEnabledChanged 触发 + 参数区 / 提示区互换
/// - paramsBuilder 只在 enabled = true 时被调用（无重算成本）
void main() {
  Future<void> pumpGroup(
    WidgetTester tester, {
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerSwitchGroup(
            title: '模糊边框',
            enabled: enabled,
            onEnabledChanged: onChanged,
            keyPrefix: 'blur',
            paramsBuilder: (context) => const Text('param area'),
          ),
        ),
      ),
    );
  }

  testWidgets('enabled=true: shows switch on + params area', (tester) async {
    var currentEnabled = true;
    await pumpGroup(
      tester,
      enabled: currentEnabled,
      onChanged: (v) => currentEnabled = v,
    );

    expect(find.text('模糊边框'), findsOneWidget);
    expect(
      find.byKey(const Key('blur_enable_switch')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('blur_params')), findsOneWidget);
    expect(find.text('param area'), findsOneWidget);
    expect(find.byKey(const Key('blur_disabled_hint')), findsNothing);
  });

  testWidgets('enabled=false: shows switch off + disabled hint',
      (tester) async {
    var currentEnabled = false;
    await pumpGroup(
      tester,
      enabled: currentEnabled,
      onChanged: (v) => currentEnabled = v,
    );

    expect(find.byKey(const Key('blur_enable_switch')), findsOneWidget);
    expect(find.byKey(const Key('blur_params')), findsNothing);
    expect(find.byKey(const Key('blur_disabled_hint')), findsOneWidget);
    expect(find.text('已关闭（不写入最终模板）'), findsOneWidget);
  });

  testWidgets('tapping switch triggers onEnabledChanged', (tester) async {
    var currentEnabled = false;
    bool? lastValue;
    await pumpGroup(
      tester,
      enabled: currentEnabled,
      onChanged: (v) {
        lastValue = v;
        currentEnabled = v;
      },
    );

    await tester.tap(find.byKey(const Key('blur_enable_switch')));
    await tester.pump();
    expect(lastValue, isTrue);
  });

  testWidgets('rebuild with enabled toggle swaps params/hint', (tester) async {
    var currentEnabled = false;
    await pumpGroup(
      tester,
      enabled: currentEnabled,
      onChanged: (v) => currentEnabled = v,
    );
    expect(find.byKey(const Key('blur_disabled_hint')), findsOneWidget);

    // 模拟父 widget 收到 callback 后用新 enabled 重建
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerSwitchGroup(
            title: '模糊边框',
            enabled: true,
            onEnabledChanged: (v) => currentEnabled = v,
            keyPrefix: 'blur',
            paramsBuilder: (context) => const Text('param area'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('blur_params')), findsOneWidget);
    expect(find.byKey(const Key('blur_disabled_hint')), findsNothing);
  });
}
