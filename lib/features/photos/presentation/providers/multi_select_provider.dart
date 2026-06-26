import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 多选状态数据类
class MultiSelectState {
  /// 选中的照片 ID 集合
  final Set<String> selectedIds;

  /// 是否处于多选模式
  final bool isMultiSelectMode;

  const MultiSelectState({
    this.selectedIds = const {},
    this.isMultiSelectMode = false,
  });

  /// 复制并修改状态
  MultiSelectState copyWith({
    Set<String>? selectedIds,
    bool? isMultiSelectMode,
  }) {
    return MultiSelectState(
      selectedIds: selectedIds ?? this.selectedIds,
      isMultiSelectMode: isMultiSelectMode ?? this.isMultiSelectMode,
    );
  }
}

/// 多选模式 Notifier
class MultiSelectNotifier extends Notifier<MultiSelectState> {
  @override
  MultiSelectState build() => const MultiSelectState();

  /// 切换单个照片的选中状态
  void toggle(String photoId) {
    final newIds = Set<String>.from(state.selectedIds);
    if (newIds.contains(photoId)) {
      newIds.remove(photoId);
    } else {
      newIds.add(photoId);
    }
    state = state.copyWith(
      selectedIds: newIds,
      isMultiSelectMode: newIds.isNotEmpty,
    );
  }

  /// 进入多选模式
  void enterMultiSelectMode() {
    state = state.copyWith(isMultiSelectMode: true);
  }

  /// 退出多选模式
  void exitMultiSelectMode() {
    state = state.copyWith(
      selectedIds: const {},
      isMultiSelectMode: false,
    );
  }

  /// 全选
  void selectAll(Set<String> allPhotoIds) {
    state = state.copyWith(selectedIds: Set<String>.from(allPhotoIds));
  }

  /// 清空选集（保持多选模式）
  void clearSelection() {
    state = state.copyWith(selectedIds: const {});
  }

  /// 判断是否全选
  bool isAllSelected(Set<String> allPhotoIds) {
    if (allPhotoIds.isEmpty) return false;
    return allPhotoIds.every((id) => state.selectedIds.contains(id));
  }
}

/// 多选 Provider
final multiSelectProvider =
    NotifierProvider<MultiSelectNotifier, MultiSelectState>(
  MultiSelectNotifier.new,
);