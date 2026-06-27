import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tag_model.dart';
import '../providers/tag_list_provider.dart';

/// Lightroom 风格标签选择器底部弹窗.
///
/// 布局：
/// ```
/// ┌────────────────────────────────────┐
/// │  拖拽条                            │
/// │  标签选择                    [完成]  │
/// │  ┌──────────────────────────────┐  │
/// │  │ 🔍 搜索标签...                │  │
/// │  └──────────────────────────────┘  │
/// │                                    │
/// │  已选          │  全部标签           │
/// │  ┌──┐ ┌──┐    │  ● 风景  ✓         │
/// │  │色│ │色│    │  ● 人物            │
/// │  └──┘ └──┘    │  ● 美食  ✓         │
/// │  未选择        │  ...               │
/// └────────────────────────────────────┘
/// ```
///
/// [selectedTagIds] — 当前照片已选的标签 ID 集合.
/// [onConfirm] — 用户点击"完成"时回调，参数为最终选中的标签 ID 集合.
Future<void> showTagPickerSheet({
  required BuildContext context,
  required Set<String> selectedTagIds,
  required void Function(Set<String> selectedTagIds) onConfirm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => TagPickerSheet(
      initialSelectedTagIds: selectedTagIds,
      onConfirm: onConfirm,
    ),
  );
}

/// 标签选择器 Sheet.
class TagPickerSheet extends ConsumerStatefulWidget {
  const TagPickerSheet({
    required this.initialSelectedTagIds,
    required this.onConfirm,
    super.key,
  });

  final Set<String> initialSelectedTagIds;
  final void Function(Set<String> selectedTagIds) onConfirm;

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  late Set<String> _selectedTagIds;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTagIds = Set<String>.from(widget.initialSelectedTagIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tagListProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TagModel> _filteredTags(List<TagModel> allTags) {
    if (_searchQuery.isEmpty) return allTags;
    final q = _searchQuery.toLowerCase();
    return allTags.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncTags = ref.watch(tagListProvider);
    final allTags = asyncTags.valueOrNull ?? const <TagModel>[];
    final filteredTags = _filteredTags(allTags);

    // Build selected tag list in display order (same as allTags order)
    final selectedTags = allTags
        .where((t) => _selectedTagIds.contains(t.id))
        .toList();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽条
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '标签选择',
                    style: theme.textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onConfirm(Set<String>.from(_selectedTagIds));
                      Navigator.of(context).pop();
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),

            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索标签...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            const SizedBox(height: 12),

            // 已选标签区域
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已选',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (selectedTags.isEmpty)
                    Text(
                      '未选择',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedTags.map((tag) {
                        return _SelectedTagChip(
                          tag: tag,
                          onRemove: () => _toggleTag(tag.id),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            const Divider(height: 24),

            // 全部标签列表
            Expanded(
              child: asyncTags.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text(
                    '加载失败',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                data: (_) {
                  if (filteredTags.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? '暂无标签' : '没有匹配的标签',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 16 + bottomInset,
                    ),
                    itemCount: filteredTags.length,
                    itemBuilder: (context, index) {
                      final tag = filteredTags[index];
                      final isSelected = _selectedTagIds.contains(tag.id);
                      return _TagListTile(
                        tag: tag,
                        isSelected: isSelected,
                        onTap: () => _toggleTag(tag.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已选标签色块（可移除）。
class _SelectedTagChip extends StatelessWidget {
  const _SelectedTagChip({
    required this.tag,
    required this.onRemove,
  });

  final TagModel tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tagColor = Color(tag.colorValue);
    return Container(
      decoration: BoxDecoration(
        color: tagColor.withAlpha(51),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tagColor, width: 1),
      ),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tagColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                tag.name,
                style: TextStyle(
                  fontSize: 12,
                  color: tagColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.close,
                size: 14,
                color: tagColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全部标签列表单个条目。
class _TagListTile extends StatelessWidget {
  const _TagListTile({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  final TagModel tag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = Color(tag.colorValue);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: tagColor,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(tag.name),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : Icon(Icons.circle_outlined, color: theme.colorScheme.outline),
    );
  }
}
