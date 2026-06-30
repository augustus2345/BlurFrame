import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/album_model.dart';
import '../providers/album_list_provider.dart';

/// 批量加入影集底部弹窗入口.
///
/// 展示所有影集列表，用户选择一个后把 [selectedPhotoIds] 添加进去.
Future<void> showAlbumPickerSheet({
  required BuildContext context,
  required Set<String> selectedPhotoIds,
  required void Function(String albumId) onConfirm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => AlbumPickerSheet(
      selectedPhotoIds: selectedPhotoIds,
      onConfirm: onConfirm,
    ),
  );
}

/// 批量加入影集 Sheet.
class AlbumPickerSheet extends ConsumerStatefulWidget {
  const AlbumPickerSheet({
    required this.selectedPhotoIds,
    required this.onConfirm,
    super.key,
  });

  final Set<String> selectedPhotoIds;
  final void Function(String albumId) onConfirm;

  @override
  ConsumerState<AlbumPickerSheet> createState() => _AlbumPickerSheetState();
}

class _AlbumPickerSheetState extends ConsumerState<AlbumPickerSheet> {
  @override
  void initState() {
    super.initState();
    // 首次弹出时刷新影集列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(albumListProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncAlbums = ref.watch(albumListProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '加入影集',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '已选 ${widget.selectedPhotoIds.length} 张',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 影集列表
            Flexible(
              child: asyncAlbums.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('加载失败: $e'),
                  ),
                ),
                data: (albums) {
                  if (albums.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_album_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '还没有影集',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '点击下方按钮创建新影集',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return _AlbumListTile(
                        album: album,
                        onTap: () {
                          widget.onConfirm(album.id);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // 底部操作栏
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCreateAlbumDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('新建影集并添加'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateAlbumDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _CreateAlbumDialog(
        initialPhotoCount: widget.selectedPhotoIds.length,
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      // 只创建空影集，照片由 onConfirm 回调统一添加
      // 避免重复添加：_handleBatchAlbum 里会调用 addPhotos
      final albumRepo = ref.read(albumRepositoryProvider);
      final newAlbum = await albumRepo.create(name: name);
      widget.onConfirm(newAlbum.id);
    }
  }
}

/// 影集列表项.
class _AlbumListTile extends StatelessWidget {
  const _AlbumListTile({
    required this.album,
    required this.onTap,
  });

  final AlbumModel album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.photo_album_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(album.name),
      subtitle: Text(
        '${album.photoIds.length} 张照片',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// 新建影集对话框.
class _CreateAlbumDialog extends StatefulWidget {
  const _CreateAlbumDialog({
    required this.initialPhotoCount,
  });

  final int initialPhotoCount;

  @override
  State<_CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<_CreateAlbumDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建影集'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: '影集名称',
          hintText: '输入影集名称',
          suffixText: '${widget.initialPhotoCount} 张照片将加入',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }
}