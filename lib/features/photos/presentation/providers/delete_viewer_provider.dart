import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 删除查看器（清理模式）的状态。
///
/// 负责管理当前查看的第 N/M 张照片，以及对应的操作状态。
/// 手势删除和撤销逻辑在 M5-T7 / M5-T9 实现。
class DeleteViewerState {
  const DeleteViewerState({
    required this.currentIndex,
    required this.isLoading,
  });

  final int currentIndex;
  final bool isLoading;

  DeleteViewerState copyWith({
    int? currentIndex,
    bool? isLoading,
  }) {
    return DeleteViewerState(
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// [DeleteViewerNotifier] 管理删除 tab 的状态。
///
/// 职责：
/// - 维护当前查看的照片索引
/// - 提供上一张 / 下一张导航
/// - 删除后自动切换到下一张（M5-T7）
class DeleteViewerNotifier extends Notifier<DeleteViewerState> {
  @override
  DeleteViewerState build() {
    return const DeleteViewerState(
      currentIndex: 0,
      isLoading: false,
    );
  }

  /// 进入删除 tab 时初始化：从照片列表第一张开始。
  void initialize(int startIndex) {
    state = state.copyWith(currentIndex: startIndex);
  }

  /// 移动到上一张。
  void goToPrevious(int totalCount) {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }

  /// 移动到下一张。
  void goToNext(int totalCount) {
    if (state.currentIndex >= totalCount - 1) return;
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  /// 删除当前照片后，切换到上一张（如果还有）。
  void onDeleted(int totalCountAfterDelete) {
    if (totalCountAfterDelete <= 0) return;
    // 如果当前索引超出新列表范围，则回退到最后一页
    final newIndex = state.currentIndex >= totalCountAfterDelete
        ? totalCountAfterDelete - 1
        : state.currentIndex;
    state = state.copyWith(currentIndex: newIndex);
  }

  /// 设置加载态。
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }
}

/// 全局删除查看器状态入口。
final deleteViewerProvider =
    NotifierProvider<DeleteViewerNotifier, DeleteViewerState>(
  DeleteViewerNotifier.new,
);
