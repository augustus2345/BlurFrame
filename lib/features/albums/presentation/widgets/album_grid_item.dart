import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models/album_model.dart';

/// 影集列表单个格子（1:1 正方形）。
///
/// 封面逻辑：
/// - 有 [coverPhotoId] 且 [thumbnailLoader] 返回非 null → 展示缩略图
/// - 无封面 / 加载失败 → 占位灰块 + 照片数量
///
/// 多选模式（M3 后续）：
/// - [isSelected] 控制右上角勾选图标
/// - [onLongPress] 进入多选模式
class AlbumGridItem extends StatelessWidget {
  const AlbumGridItem({
    required this.album,
    required this.thumbnailLoader,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    super.key,
  });

  final AlbumModel album;

  /// 异步拉缩略图的注入函数。返回 `null` 时显示占位。
  final Future<Uint8List?> Function(String assetId) thumbnailLoader;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoCount = album.photoIds.length;

    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 封面缩略图或占位
              _buildCover(theme),
              // 底部渐变遮罩 + 标题 + 照片数
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        album.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$photoCount 张照片',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 多选态勾选
              if (isSelected) ...[
                const ColoredBox(
                  color: Color(0x62000000),
                ),
                Positioned(
                  top: 4,
                  right: 4,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(ThemeData theme) {
    if (album.coverPhotoId.isEmpty) {
      return _Placeholder(color: theme.dividerColor);
    }
    return FutureBuilder<Uint8List?>(
      future: thumbnailLoader(album.coverPhotoId),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || bytes == null) {
          return _Placeholder(color: theme.dividerColor);
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

/// 占位灰块。
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('album_grid_item_placeholder'),
      color: color,
      child: const Center(
        child: Icon(
          Icons.collections_bookmark_outlined,
          size: 32,
          color: Colors.white54,
        ),
      ),
    );
  }
}