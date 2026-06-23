import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

/// 缩略图加载函数的 DI 入口。
///
/// 生产路径：用 `assetId` 拿 `AssetEntity` 再调 `thumbnailDataWithSize(...)`。
/// 测试用：override 成返回固定字节 / null 的闭包。
///
/// 返回 `null` 表示"缩略图不可用"（asset 找不到 / 平台拒绝 / 缩略图生成失败），
/// gallery 会渲染占位灰块而不是崩溃。
final assetThumbnailLoaderProvider =
    Provider<Future<Uint8List?> Function(String assetId)>((ref) {
  return _defaultAssetThumbnailLoader;
});

/// 生产路径：photo_manager 真路径。
///
/// 步骤：
/// 1. `AssetEntity.fromId(id)` — 把 `PhotoModel.id` 还原成 `AssetEntity`。
/// 2. `thumbnailDataWithSize(ThumbnailSize(360, 360))` — 拉 360×360 缩略图 JPEG。
///
/// 两步都可能返回 `null`（asset 已被用户删除 / 平台没权限 / 缩略图生成失败），
/// 一律当 placeholder 处理。
Future<Uint8List?> _defaultAssetThumbnailLoader(String assetId) async {
  final asset = await AssetEntity.fromId(assetId);
  if (asset == null) return null;
  return asset.thumbnailDataWithSize(const ThumbnailSize(360, 360));
}