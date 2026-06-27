import 'package:flutter/material.dart';

/// 模版编辑器里的"层"分组容器（M2-T4）。
///
/// 一个分组 = 标题 + 启用开关 + 可折叠的参数区。3 种 layer（模糊 / 水印 /
/// 颜色条）共用同一个 layout，只换标题和参数 builder。
///
/// 折叠行为：
/// - [enabled] = true → 参数区展开
/// - [enabled] = false → 参数区收起（**保留值**，不销毁 state），
///   UI 上显示一个 "已关闭" 提示行，让用户知道这层还在
///
/// 设计要点：
/// - 参数区由 [paramsBuilder] 提供（运行时构造，避免把每个 layer 的所有
///   控件都堆在一个 widget 里）
/// - 开关状态由父 widget 完全控制（受控组件），便于和 [TemplateEditorState]
///   单向数据流保持一致
/// - 不在内部管理 [enabled] 状态；改 [enabled] 的副作用（如清空 layer 实例）
///   由父 widget 在 [onEnabledChanged] 回调里做
class LayerSwitchGroup extends StatelessWidget {
  const LayerSwitchGroup({
    required this.title,
    required this.enabled,
    required this.onEnabledChanged,
    required this.paramsBuilder,
    this.keyPrefix = 'layer',
    super.key,
  });

  /// 分组标题（如 "模糊边框"）。
  final String title;

  /// 当前层是否启用。
  final bool enabled;

  /// 启用开关变化回调（true = 用户拨到开，false = 拨到关）。
  final ValueChanged<bool> onEnabledChanged;

  /// 参数区 builder：只在该层 enabled = true 时被调用。
  ///
  /// 用 builder 而不是直接给 Widget 数组是因为各层参数差异大（slider /
  /// dropdown / TextField / color picker 各不同），且部分参数内部用
  /// `StatefulWidget` 维护 `TextEditingController`，在 enabled 切换时
  /// 需要被重新构造。
  final WidgetBuilder paramsBuilder;

  /// 测试 key 前缀；生成的 key：
  /// - `$keyPrefix\_enable_switch` — Switch 本身
  /// - `$keyPrefix\_params` — 参数区根节点
  /// - `$keyPrefix\_disabled_hint` — 关闭时提示行
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题行 + Switch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Switch(
                  key: Key('${keyPrefix}_enable_switch'),
                  value: enabled,
                  onChanged: onEnabledChanged,
                ),
              ],
            ),
          ),
          if (enabled)
            Padding(
              key: Key('${keyPrefix}_params'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: paramsBuilder(context),
            )
          else
            Padding(
              key: Key('${keyPrefix}_disabled_hint'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                '已关闭（不写入最终模板）',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
