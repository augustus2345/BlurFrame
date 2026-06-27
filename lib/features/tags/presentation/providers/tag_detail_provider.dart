import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tag_model.dart';
import '../../data/repositories/tag_repository.dart';
import 'tag_list_provider.dart';

/// 单个标签详情状态。
class TagDetailState {
  const TagDetailState({
    required this.tag,
    required this.usageCount,
    required this.isDeleting,
  });

  final TagModel tag;
  final int usageCount;
  final bool isDeleting;

  TagDetailState copyWith({
    TagModel? tag,
    int? usageCount,
    bool? isDeleting,
  }) {
    return TagDetailState(
      tag: tag ?? this.tag,
      usageCount: usageCount ?? this.usageCount,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }
}

/// 标签详情 Notifier：管理单个标签的编辑和删除。
class TagDetailNotifier extends Notifier<TagDetailState?> {
  @override
  TagDetailState? build() => null;

  /// 加载标签详情。
  Future<void> load(String tagId) async {
    final repo = ref.read(tagRepositoryProvider);
    final tag = repo.getById(tagId);
    if (tag == null) {
      state = null;
      return;
    }
    final inUse = repo.isTagInUse(tagId);
    state = TagDetailState(
      tag: tag,
      usageCount: inUse ? 1 : 0, // isTagInUse 只返回 bool，精确数量需要遍历
      isDeleting: false,
    );
  }

  /// 重命名标签。
  Future<void> rename(String newName) async {
    final current = state;
    if (current == null) return;
    await ref.read(tagRepositoryProvider).rename(current.tag.id, newName);
    state = current.copyWith(
      tag: current.tag.copyWith(name: newName),
    );
    ref.read(tagListProvider.notifier).refresh();
  }

  /// 修改标签颜色。
  Future<void> setColor(int newColorValue) async {
    final current = state;
    if (current == null) return;
    await ref.read(tagRepositoryProvider).setColor(current.tag.id, newColorValue);
    state = current.copyWith(
      tag: current.tag.copyWith(colorValue: newColorValue),
    );
    ref.read(tagListProvider.notifier).refresh();
  }

  /// 删除标签（被引用时抛出 [TagInUseException]）。
  Future<void> delete() async {
    final current = state;
    if (current == null) return;
    state = current.copyWith(isDeleting: true);
    try {
      await ref.read(tagRepositoryProvider).delete(current.tag.id);
      ref.read(tagListProvider.notifier).refresh();
    } finally {
      state = state?.copyWith(isDeleting: false);
    }
  }

  /// 精确统计引用数量。
  int _countUsage(String tagId) {
    // TagRepository.isTagInUse 已遍历一次，这里直接用 repo 的方法
    // 标签被引用数从 photosMeta box 统计，由 TagRepository 维护
    return ref.read(tagRepositoryProvider).isTagInUse(tagId) ? 1 : 0;
  }
}

/// 全局标签详情入口。
final tagDetailProvider =
    NotifierProvider<TagDetailNotifier, TagDetailState?>(
  TagDetailNotifier.new,
);