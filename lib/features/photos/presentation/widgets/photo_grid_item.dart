import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models/photo_model.dart';

/// 照片库 3 列网格的单个格子（1:1 正方形）。
///
/// 设计要点：
/// - **缩略图加载是注入的**：[thumbnailLoader] 是 `Future<Uint8List?> Function(PhotoModel)`，
///   生产路径走 `AssetEntity.thumbnailDataWithSize(...)`（在调用方注入），
///   测试 / mock 路径可换成同步闭包，方便 widget 测试。
/// - **失败 = placeholder**：`loader` 返回 `null`（损坏 / 系统拒绝）时显示占位灰块，
///   永不抛错（CLAUDE.md §1.5 — 异步路径必须考虑失败）。
/// - **1:1 比例**：用 [AspectRatio] 包住，避免在 `GridView.builder` 里被 `crossAxisCount: 3`
///   拉成怪异的横长方形。
/// - **无业务编排**：点击仅触发 [onTap]（详情页 / 多选模式由父级 [PhotoGalleryScreen]
///   决定怎么用）。
class PhotoGridItem extends StatelessWidget {
  const PhotoGridItem({
    required this.photo,
    required this.thumbnailLoader,
    this.onTap,
    super.key,
  });

  /// 要展示的照片。
  final PhotoModel photo;

  /// 异步拉缩略图的注入函数。生产路径通常包装 `AssetEntity.thumbnailDataWithSize`。
  ///
  /// 返回 `null` 时显示 placeholder（图片损坏 / 系统拒绝 / 缩略图不可用）。
  final Future<Uint8List?> Function(PhotoModel photo) thumbnailLoader;

  /// 用户点击格子时调用。父级（gallery / 详情页路由）自己决定响应（进详情 / 多选 toggle）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: FutureBuilder<Uint8List?>(
            future: thumbnailLoader(photo),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done ||
                  bytes == null) {
                return _Placeholder(color: theme.dividerColor);
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 缩略图加载中 / 失败时的占位灰块。
///
/// 单独成 widget 而不是 inline，方便 widget 测试用 [Key] 锁定断言位置。
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('photo_grid_item_placeholder'),
      color: color,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: Colors.white54,
        ),
      ),
    );
  }
}