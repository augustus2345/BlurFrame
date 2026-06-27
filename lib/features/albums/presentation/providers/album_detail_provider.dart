import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/album_model.dart';
import 'album_list_provider.dart';

/// 单个影集元数据查询入口（详情页用）。
///
/// 设计要点（CLAUDE.md §2.3-13 — 数据来源单一）：
/// - 内部 watch [albumListProvider]，删除 / 刷新列表自动反映。
/// - 返回 `AlbumModel?` —— 不存在（列表里没这个 id，或列表还在 loading/error）→ `null`。
final albumByIdProvider = Provider.family<AlbumModel?, String>((ref, id) {
  final asyncAlbums = ref.watch(albumListProvider);
  // asyncAlbums.value throws if state is AsyncError — guard by checking hasValue.
  if (!asyncAlbums.hasValue) {
    return null;
  }
  final list = asyncAlbums.value;
  if (list == null) {
    return null;
  }
  for (final album in list) {
    if (album.id == id) {
      return album;
    }
  }
  return null;
});