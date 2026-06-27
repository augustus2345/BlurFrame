import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/tag_repository.dart';
import '../providers/tag_detail_provider.dart';

/// 标签详情页 — 修改名称 / 修改颜色 / 删除标签。
///
/// 路由：`/tags/:id`。
/// 从 [TagListItem] 点击进入。
class TagDetailScreen extends ConsumerStatefulWidget {
  const TagDetailScreen({required this.tagId, super.key});

  final String tagId;

  @override
  ConsumerState<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends ConsumerState<TagDetailScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tagDetailProvider.notifier).load(widget.tagId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditing(String currentName) {
    _nameController.text = currentName;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showSnackBar('标签名称不能为空');
      return;
    }
    await ref.read(tagDetailProvider.notifier).rename(newName);
    setState(() => _isEditing = false);
    if (mounted) _showSnackBar('已保存');
  }

  Future<void> _changeColor(int colorValue) async {
    await ref.read(tagDetailProvider.notifier).setColor(colorValue);
    if (mounted) _showSnackBar('颜色已更新');
  }

  Future<void> _deleteTag() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: const Text('确定要删除这个标签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(tagDetailProvider.notifier).delete();
      if (mounted) {
        _showSnackBar('标签已删除');
        context.pop();
      }
    } on TagInUseException {
      if (mounted) {
        _showSnackBar('该标签已被照片使用，请先移除照片中的标签后再删除');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(tagDetailProvider);
    final theme = Theme.of(context);

    if (detailState == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('标签详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tag = detailState.tag;
    final tagColor = Color(tag.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除标签',
            onPressed: detailState.isDeleting ? null : _deleteTag,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 颜色预览 + 当前色值
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tagColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '0x${tag.colorValue.toRadixString(16).toUpperCase()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 颜色选择
          Text('颜色', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _presetColors)
                GestureDetector(
                  onTap: () => _changeColor(color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: tag.colorValue == color
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 3,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 名称编辑
          Text('名称', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_isEditing) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入标签名称',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _cancelEditing,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveName,
                  child: const Text('保存'),
                ),
              ],
            ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tag.name),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _startEditing(tag.name),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 标签 ID（调试用，低对比度）
          Text(
            'ID: ${tag.id}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// 预设颜色列表（10 种常用颜色）。
  static const _presetColors = [
    0xFFE53935, // 红
    0xFFFF7043, // 橙
    0xFFFFCA28, // 黄
    0xFF66BB6A, // 绿
    0xFF26A69A, // 青
    0xFF42A5F5, // 蓝
    0xFF5C6BC0, // 靛
    0xFFAB47BC, // 紫
    0xFFEC407A, // 粉
    0xFF8D6E63, // 棕
  ];
}