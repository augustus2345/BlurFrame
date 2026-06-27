import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/album_model.dart';
import '../../data/repositories/album_repository.dart';

/// [AlbumRepository] 的 DI 入口。
final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository();
});

/// 影集列表状态 — 与 [PhotosNotifier] 同模式：
/// - [build] 同步返回空列表（首屏不是 loading）
/// - 异步加载走 [refresh]
class AlbumListNotifier extends AsyncNotifier<List<AlbumModel>> {
  @override
  Future<List<AlbumModel>> build() async {
    return const <AlbumModel>[];
  }

  /// 从 Hive 加载所有影集，按创建时间倒序。
  Future<void> refresh() async {
    state = const AsyncValue<List<AlbumModel>>.loading();
    state = await AsyncValue.guard(
      () => Future.value(ref.read(albumRepositoryProvider).getAll()),
    );
  }
}

/// 全局影集列表入口。
final albumListProvider =
    AsyncNotifierProvider<AlbumListNotifier, List<AlbumModel>>(
  AlbumListNotifier.new,
);