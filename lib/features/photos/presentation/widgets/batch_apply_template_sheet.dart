import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/batch_apply_template_provider.dart';

/// 批量套模版进度展示 BottomSheet.
///
/// 展示批量渲染进度，包括：
/// - 当前进度 (current/total)
/// - 进度条
/// - 成功/失败计数
/// - 完成后显示总结
class BatchApplyTemplateSheet extends ConsumerWidget {
  const BatchApplyTemplateSheet({super.key});

  /// 显示批量套模版进度 Sheet.
  ///
  /// 返回选中的模板，或 null 如果用户取消.
  static Future<void> show({
    required BuildContext context,
    required BatchApplyTemplateState state,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => const BatchApplyTemplateSheet(),
    );
  }

  Widget _buildStateContent(BatchApplyTemplateState state) {
    if (state is BatchApplyTemplateProcessing) {
      return _ProcessingContent(state: state);
    } else if (state is BatchApplyTemplateDone) {
      return _DoneContent(state: state);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(batchApplyTemplateProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 根据状态显示不同内容
          _buildStateContent(state),
        ],
      ),
    );
  }
}

/// 进行中内容.
class _ProcessingContent extends StatelessWidget {
  const _ProcessingContent({required this.state});

  final BatchApplyTemplateProcessing state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          '正在应用 "${state.templateName}"',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${state.current} / ${state.total}',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: state.progress,
          key: const Key('batch_apply_progress_bar'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.successCount > 0) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text('${state.successCount}'),
              const SizedBox(width: 16),
            ],
            if (state.failureCount > 0) ...[
              const Icon(Icons.error, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              Text('${state.failureCount}'),
            ],
          ],
        ),
      ],
    );
  }
}

/// 完成内容.
class _DoneContent extends StatelessWidget {
  const _DoneContent({required this.state});

  final BatchApplyTemplateDone state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          state.failureCount == 0 ? Icons.check_circle : Icons.warning,
          size: 48,
          color: state.failureCount == 0 ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 16),
        Text(
          state.failureCount == 0
              ? '批量应用完成'
              : '批量应用完成（部分失败）',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '模板：${state.templateName}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ResultChip(
              icon: Icons.check_circle,
              color: Colors.green,
              label: '成功 ${state.successCount}',
            ),
            if (state.failureCount > 0) ...[
              const SizedBox(width: 16),
              _ResultChip(
                icon: Icons.error,
                color: Colors.red,
                label: '失败 ${state.failureCount}',
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

/// 结果 chip.
class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}