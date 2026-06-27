import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/models/frame_template.dart';
import '../../data/repositories/frame_repository.dart';
import '../providers/frame_template_list_provider.dart';
import '../widgets/frame_template_card.dart';

/// 模版 tab 列表屏（M2-T3）。
///
/// 独立 tab（`/frames`，不是 push）：
/// 1. **顶部 AppBar** — "相框" + 右上 `+` 跳 `/frames/editor`（M2-T4 实现）
/// 2. **2 列网格** — 每张卡片显示 [FrameTemplateCard]：
///    - 顶部预览图（[FramePreview]，无 photo 字节的抽象缩略）
///    - 名称 + "自带"或"使用 N 次"角标
/// 3. **长按卡片** → 底部 ActionSheet：
///    - 复制为我的模板（内置 / 用户都可）→ `repo.duplicate(id)` → refresh
///    - 编辑（仅用户模板，M2-T4 接入）
///    - 删除（仅用户模板，内置灰显并提示"内置不可删除"）
/// 4. **4 态显式** — loading / error(带重试) / empty / success
///
/// 数据源 [frameTemplateListProvider]（M2-T3 引入）；
/// initState post-frame 触发首次 refresh（与 [PhotoGalleryScreen] 模式一致）。
class FrameTemplateListScreen extends ConsumerStatefulWidget {
  const FrameTemplateListScreen({super.key});

  @override
  ConsumerState<FrameTemplateListScreen> createState() =>
      _FrameTemplateListScreenState();
}

class _FrameTemplateListScreenState
    extends ConsumerState<FrameTemplateListScreen> {
  @override
  void initState() {
    super.initState();
    // 首次进入拉取列表；refresh 涉及 IO / Hive 读取，必须 post-frame。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(frameTemplateListProvider.notifier).refresh();
    });
  }

  /// 复制模板为我的：调 `repo.duplicate(id)`，结果 refresh 一次让 UI 同步。
  Future<void> _duplicateTemplate(String sourceId) async {
    final repo = ref.read(frameRepositoryProvider);
    try {
      final copy = await repo.duplicate(sourceId);
      if (!mounted) return;
      await ref.read(frameTemplateListProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('frame_template_duplicate_snackbar'),
          content: Text('已复制为「${copy.name}」'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('复制失败：$e')),
      );
    }
  }

  /// 删除用户模板：弹二次确认 → 调 `repo.delete(id)` → refresh。
  Future<void> _deleteTemplate(FrameTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('frame_template_delete_dialog'),
        title: const Text('删除模板'),
        content: Text('确定要删除「${template.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('frame_template_delete_confirm_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(frameRepositoryProvider);
    try {
      await repo.delete(template.id);
      if (!mounted) return;
      await ref.read(frameTemplateListProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('frame_template_delete_snackbar'),
          content: Text('已删除「${template.name}」'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on BuiltInTemplateException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内置模板不可删除')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncTemplates = ref.watch(frameTemplateListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('相框'),
        actions: <Widget>[
          IconButton(
            key: const Key('frame_template_new_button'),
            icon: const Icon(Icons.add),
            tooltip: '新建模板',
            onPressed: () => context.push(AppRoute.frameEditor),
          ),
        ],
      ),
      body: asyncTemplates.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            key: Key('frame_template_list_loading_indicator'),
          ),
        ),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () =>
              ref.read(frameTemplateListProvider.notifier).refresh(),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return const _EmptyListState();
          }
          return _FrameTemplateGrid(
            templates: templates,
            onDuplicate: _duplicateTemplate,
            onDelete: _deleteTemplate,
            onEdit: () {
              // TODO(M2-T4): 跳 /frames/editor 推编辑器。编辑器完成前先提示。
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('编辑器功能即将推出')),
              );
            },
          );
        },
      ),
    );
  }
}

/// 2 列网格。
class _FrameTemplateGrid extends StatelessWidget {
  const _FrameTemplateGrid({
    required this.templates,
    required this.onDuplicate,
    required this.onDelete,
    required this.onEdit,
  });

  final List<FrameTemplate> templates;
  final Future<void> Function(String sourceId) onDuplicate;
  final Future<void> Function(FrameTemplate template) onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const Key('frame_template_grid'),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // 卡片内部是 1:1 预览 + 两行文字 ≈ 1.15:1，外层 cell 比例跟着走
        childAspectRatio: 0.85,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return FrameTemplateCard(
          key: ValueKey<String>('frame_template_card_${template.id}'),
          template: template,
          onDuplicate: () => onDuplicate(template.id),
          onDelete: () => onDelete(template),
          onEdit: onEdit,
        );
      },
    );
  }
}

/// 错误态：EmptyState + 重试按钮。
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      key: const Key('frame_template_list_error_state'),
      icon: Icons.error_outline,
      title: '加载失败',
      message: '无法读取相框模板：$error',
      action: FilledButton(
        key: const Key('frame_template_list_retry_button'),
        onPressed: () => onRetry(),
        child: const Text('重试'),
      ),
    );
  }
}

/// 空列表（不应该出现，因为有 2 个内置模板；但万一 box 全空时给个友好提示）。
class _EmptyListState extends StatelessWidget {
  const _EmptyListState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      key: Key('frame_template_list_empty_state'),
      icon: Icons.crop_square_outlined,
      title: '还没有相框模板',
      message: '点击右上角 "+" 创建一个新模板',
    );
  }
}
