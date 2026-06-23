import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/photo_model.dart';
import 'photos_provider.dart';

/// 单张照片元数据查询入口（详情页 / 影集封面等用）。
///
/// 设计要点（CLAUDE.md §2.3-13 — 数据来源单一）：
/// - 内部 watch [photosProvider]，**不复制**列表内容；
///   删除 / 刷新 gallery 自动反映，详情页无须手动 invalidate。
/// - 返回 `PhotoModel?` —— 不存在（gallery 列表里没这个 id，或 gallery 还在
///   loading / error 阶段）→ `null`，调用方走"未找到"分支。
final photoByIdProvider = Provider.family<PhotoModel?, String>((ref, id) {
  final asyncPhotos = ref.watch(photosProvider);
  final list = asyncPhotos.value;
  if (list == null) {
    return null;
  }
  for (final photo in list) {
    if (photo.id == id) {
      return photo;
    }
  }
  return null;
});
