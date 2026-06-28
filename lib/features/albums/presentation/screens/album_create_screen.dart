import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../photos/data/models/photo_model.dart';
import '../../../photos/presentation/providers/asset_thumbnail_loader_provider.dart';
import '../../../photos/presentation/providers/photos_provider.dart';
import '../../data/models/album_model.dart';
import '../providers/album_list_provider.dart';

/// 新建影集页面。
///
/// 流程：输入名称 → 选照片（多选） → 选版式 → 创建
///
/// 版式选项（4 种）：
/// - [AlbumLayout.grid] 网格（默认）
/// - [AlbumLayout.magazine] 杂志
/// - [AlbumLayout.collage] 拼贴
/// - [AlbumLayout.polaroid] 宝丽来
class AlbumCreateScreen extends ConsumerStatefulWidget {
  const AlbumCreateScreen({super.key});

  @override
  ConsumerState<AlbumCreateScreen> createState() => _AlbumCreateScreenState();
}

class _AlbumCreateScreenState extends ConsumerState<AlbumCreateScreen> {
  final _nameController = TextEditingController();
  final _selectedPhotoIds = <String>{};
  AlbumLayout _selectedLayout = AlbumLayout.grid;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAlbum() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('请输入影集名称');
      return;
    }
    setState(() => _isCreating = true);
    try {
      await ref.read(albumRepositoryProvider).create(
            name: name,
            photoIds: _selectedPhotoIds.toList(),
            layout: _selectedLayout,
          );
      await ref.read(albumListProvider.notifier).refresh();
      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('创建失败，请重试');
        setState(() => _isCreating = false);
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
    final theme = Theme.of(context);
    final asyncPhotos = ref.watch(photosProvider);
    final thumbnailLoader = ref.watch(assetThumbnailLoaderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('新建影集'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
              if (context.canPop()) context.pop();
            },
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createAlbum,
            child: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 名称输入
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '影集名称',
                hintText: '例如：旅行照片',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 50,
            ),
          ),
          // 版式选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '版式',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AlbumLayout.values.map((layout) {
                    final isSelected = layout == _selectedLayout;
                    return ChoiceChip(
                      label: Text(_layoutName(layout)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedLayout = layout);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 照片选择标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择照片',
                  style: theme.textTheme.titleSmall,
                ),
                if (_selectedPhotoIds.isNotEmpty)
                  Text(
                    '已选 ${_selectedPhotoIds.length} 张',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 照片网格
          Expanded(
            child: asyncPhotos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const EmptyState(
                icon: Icons.error_outline,
                title: '加载失败',
                message: '无法读取相册照片',
              ),
              data: (photos) {
                if (photos.isEmpty) {
                  return const EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: '暂无照片',
                    message: '相册里没有可添加的照片',
                  );
                }
                return _PhotoPickerGrid(
                  photos: photos,
                  thumbnailLoader: thumbnailLoader,
                  selectedIds: _selectedPhotoIds,
                  onToggle: (id) {
                    setState(() {
                      if (_selectedPhotoIds.contains(id)) {
                        _selectedPhotoIds.remove(id);
                      } else {
                        _selectedPhotoIds.add(id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _layoutName(AlbumLayout layout) {
    switch (layout) {
      case AlbumLayout.grid:
        return '网格';
      case AlbumLayout.magazine:
        return '杂志';
      case AlbumLayout.collage:
        return '拼贴';
      case AlbumLayout.polaroid:
        return '宝丽来';
    }
  }
}

/// 照片多选网格。
class _PhotoPickerGrid extends StatelessWidget {
  const _PhotoPickerGrid({
    required this.photos,
    required this.thumbnailLoader,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<PhotoModel> photos;
  final Future<Uint8List?> Function(String assetId) thumbnailLoader;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final isSelected = selectedIds.contains(photo.id);
        return _PhotoPickerItem(
          key: Key('photo_picker_item_${photo.id}'),
          photo: photo,
          thumbnailLoader: thumbnailLoader,
          isSelected: isSelected,
          onTap: () => onToggle(photo.id),
        );
      },
    );
  }
}

/// 单个照片选择格子。
class _PhotoPickerItem extends StatelessWidget {
  const _PhotoPickerItem({
    super.key,
    required this.photo,
    required this.thumbnailLoader,
    required this.isSelected,
    required this.onTap,
  });

  final PhotoModel photo;
  final Future<Uint8List?> Function(String assetId) thumbnailLoader;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 缩略图或占位
          FutureBuilder<Uint8List?>(
            future: thumbnailLoader(photo.id),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done ||
                  bytes == null) {
                return ColoredBox(
                  color: theme.dividerColor,
                  child: const Icon(Icons.photo, color: Colors.white54),
                );
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
          // 半透明遮罩（选中时）
          if (isSelected)
            const ColoredBox(
              color: Color(0x4D000000),
            ),
          // 勾选图标
          if (isSelected)
            Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ignore_for_file: use_key_in_widget_constructors