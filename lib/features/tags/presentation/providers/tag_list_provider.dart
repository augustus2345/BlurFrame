import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tag_model.dart';
import '../../data/repositories/tag_repository.dart' show TagRepository, tagRepositoryProvider;

// Re-export so screens can import from here without knowing about the data layer.
export '../../data/repositories/tag_repository.dart' show tagRepositoryProvider;

/// 标签列表状态 — 与 [AlbumListNotifier] 同模式：
/// - [build] 同步返回空列表（首屏不是 loading）
/// - 异步加载走 [refresh]
class TagListNotifier extends AsyncNotifier<List<TagModel>> {
  @override
  Future<List<TagModel>> build() async {
    return const <TagModel>[];
  }

  /// 从 Hive 加载所有标签，按创建时间倒序。
  Future<void> refresh() async {
    state = const AsyncValue<List<TagModel>>.loading();
    state = await AsyncValue.guard(
      () => Future.value(ref.read(tagRepositoryProvider).getAll()),
    );
  }
}

/// 全局标签列表入口。
final tagListProvider =
    AsyncNotifierProvider<TagListNotifier, List<TagModel>>(
  TagListNotifier.new,
);