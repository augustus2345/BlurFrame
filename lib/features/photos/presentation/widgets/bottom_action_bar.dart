import 'package:flutter/material.dart';

/// 详情页底部 5 项批量操作栏。
///
/// - **删除** ✅ 完整：tap → 二次确认 → 调 [onDelete](photoId)
/// - **模版** ✅ M2-T6：tap → 调用 [onApplyTemplate]（由 [PhotoDetailScreen] 展示选择器）
/// - **标签 / 星级 / 影集** 🔒 disabled 占位（依赖 M4-T5 / M3 后续 milestone）
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    required this.photoId,
    required this.onDelete,
    this.onApplyTemplate,
    super.key,
  });

  final String? photoId;
  final Future<void> Function(String photoId) onDelete;

  /// M2-T6 导出流程入口，由 [PhotoDetailScreen] 传入具体实现。
  final VoidCallback? onApplyTemplate;

  Future<void> _handleDelete(BuildContext context) async {
    final id = photoId;
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('photo_detail_delete_dialog'),
        title: const Text('删除这张照片？'),
        content: const Text('仅删除本地引用，源文件仍在系统相册。'),
        actions: [
          TextButton(
            key: const Key('photo_detail_delete_cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('photo_detail_delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await onDelete(id);
  }

  @override
  Widget build(BuildContext context) {
    final canAct = photoId != null;
    return Container(
      key: const Key('photo_detail_bottom_action_bar'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            key: const Key('photo_detail_action_delete'),
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: canAct ? () => _handleDelete(context) : null,
          ),
          const IconButton(
            key: Key('photo_detail_action_tags'),
            tooltip: '标签（M4 接入）',
            icon: Icon(Icons.local_offer_outlined),
            onPressed: null,
          ),
          const IconButton(
            key: Key('photo_detail_action_star'),
            tooltip: '星级（M4 接入）',
            icon: Icon(Icons.star_border),
            onPressed: null,
          ),
          const IconButton(
            key: Key('photo_detail_action_album'),
            tooltip: '影集（M3 接入）',
            icon: Icon(Icons.collections_bookmark_outlined),
            onPressed: null,
          ),
          IconButton(
            key: const Key('photo_detail_action_frame'),
            tooltip: '应用模版',
            icon: const Icon(Icons.crop_square_outlined),
            onPressed: canAct && onApplyTemplate != null
                ? () => onApplyTemplate!()
                : null,
          ),
        ],
      ),
    );
  }
}