import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../data/models/tag_model.dart';
import '../providers/tag_list_provider.dart';
import '../providers/tag_detail_provider.dart';
import '../widgets/tag_list_item.dart';

/// 标签管理页 — 所有标签的列表入口。
///
/// 支持：
/// - 标签列表（Chip 样式），点击进入详情页修改/删除
/// - 右上角 "+" → 打开新建标签 sheet
/// - 4 态显式：loading / error+retry / empty / success
/// - FAB 新建标签
class TagManagerScreen extends ConsumerStatefulWidget {
  const TagManagerScreen({super.key});

  @override
  ConsumerState<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends ConsumerState<TagManagerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tagListProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncTags = ref.watch(tagListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签'),
      ),
      body: asyncTags.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(
          onRetry: () => ref.read(tagListProvider.notifier).refresh(),
        ),
        data: (tags) {
          if (tags.isEmpty) {
            return EmptyState(
              icon: Icons.label_outline,
              title: '还没有标签',
              message: '点击右下角 + 创建标签，给照片打上分类标记',
              action: FilledButton.icon(
                onPressed: () => _showCreateSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('新建标签'),
              ),
            );
          }
          return _TagList(tags: tags);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context),
        tooltip: '新建标签',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CreateTagSheet(),
    ).then((created) {
      if (created == true) {
        ref.read(tagListProvider.notifier).refresh();
      }
    });
  }
}

/// 错误视图（带重试按钮）。
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 标签列表。
class _TagList extends ConsumerWidget {
  const _TagList({required this.tags});

  final List<TagModel> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tagRepositoryProvider);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tags.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tag = tags[index];
        final usageCount = repo.isTagInUse(tag.id) ? 1 : 0;
        return TagListItem(
          key: Key('tag_list_item_${tag.id}'),
          tag: tag,
          usageCount: usageCount,
          onTap: () {
            context.push('/tags/${tag.id}');
          },
        );
      },
    );
  }
}

/// 新建标签 Sheet。
class CreateTagSheet extends ConsumerStatefulWidget {
  const CreateTagSheet({super.key});

  @override
  ConsumerState<CreateTagSheet> createState() => _CreateTagSheetState();
}

class _CreateTagSheetState extends ConsumerState<CreateTagSheet> {
  final _nameController = TextEditingController();
  int _selectedColor = 0xFF808080;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签名称不能为空')),
      );
      return;
    }
    setState(() => _isCreating = true);
    try {
      await ref.read(tagRepositoryProvider).create(
            name: name,
            colorValue: _selectedColor,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('新建标签', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),

          // 名称输入
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '标签名称',
              border: OutlineInputBorder(),
              hintText: '例如：风景、人物、美食',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 16),

          // 颜色选择
          Text('颜色', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _presetColors)
                GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 3,
                            )
                          : null,
                    ),
                    child: _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 创建按钮
          FilledButton(
            onPressed: _isCreating ? null : _create,
            child: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建'),
          ),
        ],
      ),
    );
  }

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
    0xFF78909C, // 灰蓝
    0xFFA1887F, // 浅棕
  ];
}