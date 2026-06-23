import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

/// 全尺寸原图的 DI 入口 —— 详情页 / 导出流程用。
///
/// - 暴露 `Future<Uint8List?> Function(String assetId)`，测试可 `overrideWithValue(...)`。
/// - 生产实现：`AssetEntity.fromId(id)` + `originBytes`。
/// - 失败统一返回 `null`：资源被删（`fromId` 返回 null）/ 平台读字节失败。
/// - M6 性能压测时换成 `asset.loadFile(isOrigin: true)` + `Image.file`。
final fullImageLoaderProvider =
    Provider<Future<Uint8List?> Function(String assetId)>((ref) {
  return (assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) {
      return null;
    }
    return asset.originBytes;
  };
});
