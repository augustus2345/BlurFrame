import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../frames/data/models/frame_template.dart';
import '../../../frames/presentation/providers/frame_template_list_provider.dart';
import '../../../frames/presentation/widgets/frame_preview_painter.dart';

/// 模版选择 BottomSheet。
///
/// 从详情页"应用模版"触发，展示所有可用模板（内置+用户），
/// 用户点选后触发 [onSelect] 回调。
///
/// 回调 [onSelect] 后 sheet 自动 pop。
class ApplyTemplateSheet extends ConsumerWidget {
  const ApplyTemplateSheet({
    required this.onSelect,
    super.key,
  });

  /// 选中的模板 id。
  final void Function(FrameTemplate template) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplates = ref.watch(frameTemplateListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 拖拽指示条
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      '选择相框',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('apply_template_sheet_close'),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 模板列表
              Expanded(
                child: asyncTemplates.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      key: Key('apply_template_sheet_loading'),
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Text(
                      '加载失败：$error',
                      key: const Key('apply_template_sheet_error'),
                    ),
                  ),
                  data: (templates) {
                    if (templates.isEmpty) {
                      return const Center(
                        child: Text(
                          '暂无可用模板',
                          key: Key('apply_template_sheet_empty'),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final tmpl = templates[index];
                        return _TemplateListItem(
                          template: tmpl,
                          onTap: () {
                            onSelect(tmpl);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 模板列表单个条目：左侧预览 + 右侧名称+角标。
class _TemplateListItem extends StatelessWidget {
  const _TemplateListItem({
    required this.template,
    required this.onTap,
  });

  final FrameTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('apply_template_item_${template.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 预览缩略图（固定尺寸）
              SizedBox(
                width: 72,
                height: 72,
                child: FramePreview(
                  template: template,
                  borderRadius: 6,
                ),
              ),
              const SizedBox(width: 16),
              // 名称 + 角标
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    _UsageBadge(template: template),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// 角标：内置显示"自带"，用户模板显示"使用 N 次"。
class _UsageBadge extends StatelessWidget {
  const _UsageBadge({required this.template});

  final FrameTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = template.isBuiltIn
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.secondaryContainer;
    final textColor = template.isBuiltIn
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSecondaryContainer;

    final label = template.isBuiltIn
        ? '自带'
        : '使用 ${template.usageCount} 次';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 模板选择 BottomSheet（返回选中的模板，而非通过回调）。
///
/// 用于批量套模版场景，直接返回选中的模板。
Future<FrameTemplate?> showTemplatePickerSheet({
  required BuildContext context,
}) async {
  FrameTemplate? selected;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ApplyTemplateSheet(
      onSelect: (template) {
        selected = template;
        Navigator.of(sheetContext).pop();
      },
    ),
  );
  return selected;
}