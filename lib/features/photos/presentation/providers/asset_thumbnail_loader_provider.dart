import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../core/utils/lru_cache.dart';

/// LRU 缓存的最大容量（缓存的缩略图数量）。
///
/// 360×360 JPEG 约 20–50 KB，100 张 ≈ 2–5 MB，在移动设备上可接受。
const int _thumbnailCacheMaxSize = 100;

/// 缩略图加载函数的 DI 入口（含 LRU 缓存）。
///
/// 生产路径：用 assetId 拿 AssetEntity 再调 thumbnailDataWithSize，
/// 首次加载后自动缓存到 LRU，后续同一 assetId 直接从缓存返回。
/// 测试用：override 成返回固定字节 / null 的闭包。
///
/// 返回 `null` 表示"缩略图不可用"（asset 找不到 / 平台拒绝 / 缩略图生成失败），
/// gallery 会渲染占位灰块而不是崩溃。
final assetThumbnailLoaderProvider =
    Provider<Future<Uint8List?> Function(String assetId)>((ref) {
  // 跨回调共享同一个 LRU 缓存实例
  final cache = LruCache<String, Uint8List>(_thumbnailCacheMaxSize);
  return (String assetId) => _cachedThumbnailLoader(assetId, cache);
});

/// 带 LRU 缓存的缩略图加载实现。
///
/// 先查缓存，命中则直接返回；未命中则从 AssetEntity 加载并写入缓存。
Future<Uint8List?> _cachedThumbnailLoader(
  String assetId,
  LruCache<String, Uint8List> cache,
) async {
  // 先查缓存（get 会自动把 key 移到 LRU 尾部）
  final cached = cache.get(assetId);
  if (cached != null) return cached;

  // 缓存未命中，从系统相册加载
  final bytes = await _loadThumbnailFromAsset(assetId);
  if (bytes != null) {
    cache.put(assetId, bytes);
  }
  return bytes;
}

/// 从 AssetEntity 加载缩略图。
///
/// 步骤：
/// 1. `AssetEntity.fromId(id)` — 把 `PhotoModel.id` 还原成 `AssetEntity`。
/// 2. `thumbnailDataWithSize(ThumbnailSize(360, 360))` — 拉 360×360 缩略图 JPEG。
///
/// 两步都可能返回 `null`（asset 已被用户删除 / 平台没权限 / 缩略图生成失败），
/// 一律当 placeholder 处理。
Future<Uint8List?> _loadThumbnailFromAsset(String assetId) async {
  final asset = await AssetEntity.fromId(assetId);
  if (asset == null) return null;
  return asset.thumbnailDataWithSize(const ThumbnailSize(360, 360));
}
