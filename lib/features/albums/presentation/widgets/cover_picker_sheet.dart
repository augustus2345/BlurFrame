import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../photos/presentation/providers/asset_thumbnail_loader_provider.dart';

/// 换封面底部弹窗。
///
/// 展示影集所有照片网格，当前封面带勾选标记。
/// 用户点击照片后关闭弹窗并返回选中的 photoId。
class CoverPickerSheet extends ConsumerWidget {
  const CoverPickerSheet({
    required this.albumId,
    required this.photoIds,
    required this.currentCoverPhotoId,
    super.key,
  });

  final String albumId;
  final List<String> photoIds;
  final String currentCoverPhotoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailLoader = ref.watch(assetThumbnailLoaderProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 顶部拖拽条 + 标题
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '选择封面',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 照片网格
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: photoIds.length,
                itemBuilder: (context, index) {
                  final photoId = photoIds[index];
                  return _CoverPhotoTile(
                    photoId: photoId,
                    thumbnailLoader: thumbnailLoader,
                    isSelected: photoId == currentCoverPhotoId,
                    onTap: () => Navigator.of(context).pop(photoId),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 封面选择网格中的单张照片格子。
class _CoverPhotoTile extends StatelessWidget {
  const _CoverPhotoTile({
    required this.photoId,
    required this.thumbnailLoader,
    required this.isSelected,
    required this.onTap,
  });

  final String photoId;
  final Future<Uint8List?> Function(String assetId) thumbnailLoader;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: thumbnailLoader(photoId),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done ||
                  bytes == null) {
                return Container(
                  color: Theme.of(context).dividerColor,
                  child: const Center(
                    child: Icon(Icons.photo, color: Colors.white54),
                  ),
                );
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
          // 当前封面标记
          if (isSelected)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
