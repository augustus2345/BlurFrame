import 'package:flutter/material.dart';

import '../../data/models/frame_template.dart';
import 'frame_preview_painter.dart';

/// 模版 tab 列表的单卡：预览图 + 名称 + 徽标 + 长按弹出复制/删除菜单。
///
/// 设计要点：
/// - **预览图** 用 [FramePreview] 绘制（无 photo 字节的抽象缩略），不阻塞
///   列表渲染；真实效果由 M2-T5 渲染器在导出时给出。
/// - **badge 二选一**：内置显示 "自带"，用户模板显示 "使用 N 次"。
/// - **长按菜单**：内置禁用"删除"（[isBuiltIn] 时整项灰掉）；
///   用户模板两个 action 都可用。
/// - **点按**：跳编辑器（M2-T4 实现，先 push 框架）。
class FrameTemplateCard extends StatelessWidget {
  const FrameTemplateCard({
    required this.template,
    this.onTap,
    this.onDuplicate,
    this.onDelete,
    this.onEdit,
    super.key,
  });

  final FrameTemplate template;

  /// 点按卡片（M2-T4 会跳编辑器；本任务里可空）。
  final VoidCallback? onTap;

  /// 长按菜单 → 复制为我的模板。
  final Future<void> Function()? onDuplicate;

  /// 长按菜单 → 删除（内置模板此回调不应被调用，菜单灰显）。
  final Future<void> Function()? onDelete;

  /// 长按菜单 → 编辑（仅用户模板可用，M2-T4 接入）。
  final VoidCallback? onEdit;

  Future<void> _showActionSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_CardAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制为我的模板'),
              subtitle: const Text('创建一个可编辑的副本'),
              onTap: () => Navigator.of(sheetContext).pop(_CardAction.duplicate),
            ),
            if (!template.isBuiltIn)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑'),
                enabled: onEdit != null,
                onTap: onEdit == null
                    ? null
                    : () => Navigator.of(sheetContext).pop(_CardAction.edit),
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: template.isBuiltIn
                    ? Theme.of(sheetContext).disabledColor
                    : Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                '删除',
                style: TextStyle(
                  color: template.isBuiltIn
                      ? Theme.of(sheetContext).disabledColor
                      : Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              subtitle: Text(
                template.isBuiltIn ? '内置模板不可删除' : '永久删除此模板',
              ),
              enabled: !template.isBuiltIn,
              onTap: template.isBuiltIn
                  ? null
                  : () => Navigator.of(sheetContext).pop(_CardAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    switch (result) {
      case _CardAction.duplicate:
        if (onDuplicate != null) await onDuplicate!();
      case _CardAction.delete:
        if (onDelete != null) await onDelete!();
      case _CardAction.edit:
        if (onEdit != null) onEdit!();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showActionSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 预览 + 角标
              Stack(
                children: [
                  FramePreview(template: template),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _Badge(template: template),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 名称（单行省略）
              Text(
                template.name,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              // 用户模板：显示使用次数；内置：显示"内置"提示
              const SizedBox(height: 2),
              Text(
                template.isBuiltIn
                    ? '内置模板'
                    : '使用 ${template.usageCount} 次',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CardAction { duplicate, edit, delete }

/// 角标：内置 → "自带"；用户 → "N次"。
class _Badge extends StatelessWidget {
  const _Badge({required this.template});

  final FrameTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBuiltIn = template.isBuiltIn;
    final label = isBuiltIn ? '自带' : '${template.usageCount} 次';
    return Container(
      key: Key(
        isBuiltIn
            ? 'frame_template_card_built_in_badge'
            : 'frame_template_card_usage_badge',
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isBuiltIn
            ? Colors.black.withValues(alpha: 0.55)
            : theme.colorScheme.primary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
