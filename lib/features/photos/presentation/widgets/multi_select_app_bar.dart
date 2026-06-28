import 'package:flutter/material.dart';

/// 多选模式顶部操作栏。
///
/// 在 [PhotoGalleryScreen] 进入多选模式时显示，提供：
/// - 当前选中的数量
/// - 全选 / 取消全选按钮
/// - 5 项批量操作（删除 / 标签 / 星级 / 影集 / 模版）
///
/// [selectedCount] 当前选中的照片数量
/// [totalCount] 照片总数（全选时用到）
/// [onClose] 关闭多选模式
/// [onSelectAll] 全选
/// [onDelete] 批量删除
/// [onTags] 批量打标签
/// [onStar] 批量加星
/// [onAlbum] 批量加影集（暂无功能，show snackbar 占位）
/// [onFrame] 批量套模版（暂无功能，show snackbar 占位）
class MultiSelectAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MultiSelectAppBar({
    required this.selectedCount,
    required this.totalCount,
    required this.onClose,
    required this.onSelectAll,
    this.onDelete,
    this.onTags,
    this.onStar,
    this.onAlbum,
    this.onFrame,
    super.key,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback? onDelete;
  final VoidCallback? onTags;
  final VoidCallback? onStar;
  final VoidCallback? onAlbum;
  final VoidCallback? onFrame;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  bool get _isAllSelected => selectedCount == totalCount && totalCount > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: '关闭',
        onPressed: onClose,
      ),
      title: Text('$selectedCount 项已选中'),
      actions: <Widget>[
        // 全选 / 取消全选
        TextButton(
          onPressed: onSelectAll,
          child: Text(
            _isAllSelected ? '取消全选' : '全选',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        // 5 项批量操作
        IconButton(
          key: const Key('multi_select_delete'),
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除',
          onPressed: onDelete ?? () => _showPlaceholder(context, '删除功能即将推出'),
        ),
        IconButton(
          key: const Key('multi_select_tags'),
          icon: const Icon(Icons.label_outline),
          tooltip: '标签',
          onPressed: onTags ?? () => _showPlaceholder(context, '标签功能即将推出'),
        ),
        IconButton(
          key: const Key('multi_select_star'),
          icon: const Icon(Icons.star_outline),
          tooltip: '星级',
          onPressed: onStar ?? () => _showPlaceholder(context, '星级功能即将推出'),
        ),
        IconButton(
          key: const Key('multi_select_album'),
          icon: const Icon(Icons.photo_album_outlined),
          tooltip: '影集',
          onPressed: onAlbum ?? () => _showPlaceholder(context, '影集功能即将推出'),
        ),
        IconButton(
          key: const Key('multi_select_frame'),
          icon: const Icon(Icons.filter_frames_outlined),
          tooltip: '模版',
          onPressed: onFrame ?? () => _showPlaceholder(context, '模版功能即将推出'),
        ),
      ],
    );
  }

  void _showPlaceholder(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}