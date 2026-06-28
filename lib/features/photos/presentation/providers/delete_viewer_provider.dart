import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/photo_model.dart';

/// 删除查看器（清理模式）的状态。
///
/// 负责管理当前查看的第 N/M 张照片，以及对应的操作状态。
/// 手势删除和撤销逻辑在 M5-T7 / M5-T9 实现。
class DeleteViewerState {
  const DeleteViewerState({
    required this.currentIndex,
    required this.isLoading,
    required this.sessionId,
    required this.undoStack,
    required this.pendingDeleteIds,
  });

  final int currentIndex;
  final bool isLoading;

  /// 当前会话的唯一标识符。
  ///
  /// 每次进入删除 tab 时生成新 id，撤销时校验 sessionId 是否匹配，
  /// 防止跨会话的撤销操作（用户退出删除 tab 后再进入，之前的撤销应该失效）。
  final String sessionId;

  /// 撤销栈：存储同一次会话内被删除的照片。
  ///
  /// 每条记录包含 assetId、sessionId（用于校验）和完整的 PhotoModel（用于恢复）。
  /// 队列顺序 = 删除顺序，撤销时按 LIFO（后进先出）弹出。
  final Queue<UndoEntry> undoStack;

  /// 待删除的照片 ID 集合。
  ///
  /// 上滑标记照片时加入，批量删除时一起删除，清除。
  final Set<String> pendingDeleteIds;

  DeleteViewerState copyWith({
    int? currentIndex,
    bool? isLoading,
    String? sessionId,
    Queue<UndoEntry>? undoStack,
    Set<String>? pendingDeleteIds,
  }) {
    return DeleteViewerState(
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      sessionId: sessionId ?? this.sessionId,
      undoStack: undoStack ?? this.undoStack,
      pendingDeleteIds: pendingDeleteIds ?? this.pendingDeleteIds,
    );
  }
}

/// 撤销栈条目（M5-T9）。
class UndoEntry {
  const UndoEntry({
    required this.assetId,
    required this.sessionId,
    required this.photo,
  });

  final String assetId;
  final String sessionId;
  final PhotoModel photo;
}

/// [DeleteViewerNotifier] 管理删除 tab 的状态。
///
/// 职责：
/// - 维护当前查看的照片索引
/// - 提供上一张 / 下一张导航
/// - 删除后自动切换到下一张（M5-T7）
/// - sessionId 防竞态校验 + 撤销栈管理（M5-T9）
class DeleteViewerNotifier extends Notifier<DeleteViewerState> {
  @override
  DeleteViewerState build() {
    return DeleteViewerState(
      currentIndex: 0,
      isLoading: false,
      sessionId: _generateSessionId(),
      undoStack: Queue<UndoEntry>(),
      pendingDeleteIds: {},
    );
  }

  /// 生成新的会话 ID。
  String _generateSessionId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  /// 进入删除 tab 时初始化：从照片列表第一张开始，并生成新 sessionId。
  ///
  /// 新 sessionId 会使上一会话的撤销操作失效（防止跨会话撤销）。
  void initialize(int startIndex) {
    state = DeleteViewerState(
      currentIndex: startIndex,
      isLoading: false,
      sessionId: _generateSessionId(),
      undoStack: Queue<UndoEntry>(),
      pendingDeleteIds: {},
    );
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

  /// 将已删除的照片推入撤销栈。
  ///
  /// [photo] 被删除的完整照片模型（用于恢复）。
  /// 撤销时需校验 sessionId 匹配才能执行。
  void pushToUndoStack(PhotoModel photo) {
    final entry = UndoEntry(
      assetId: photo.id,
      sessionId: state.sessionId,
      photo: photo,
    );
    final newStack = Queue<UndoEntry>.from(state.undoStack)..addLast(entry);
    state = state.copyWith(undoStack: newStack);
  }

  /// 弹出栈顶的撤销条目（仅当 sessionId 匹配时）。
  ///
  /// 返回被弹出的条目；如果栈为空或 sessionId 不匹配则返回 null。
  /// 这确保了跨会话撤销操作被拒绝。
  UndoEntry? popUndoStackIfValid() {
    if (state.undoStack.isEmpty) return null;
    final top = state.undoStack.last;
    if (top.sessionId != state.sessionId) {
      // sessionId 不匹配，拒绝撤销（可能是跨会话的操作）
      return null;
    }
    final newStack = Queue<UndoEntry>.from(state.undoStack)..removeLast();
    state = state.copyWith(undoStack: newStack);
    return top;
  }

  /// 获取当前会话的撤销栈大小（用于 UI 显示等）。
  int get undoStackSize => state.undoStack.length;

  /// 标记/取消标记照片以待删除。
  ///
  /// 如果照片已在待删除集合中，则移除；否则添加。
  void togglePendingDelete(String photoId) {
    final newSet = Set<String>.from(state.pendingDeleteIds);
    if (newSet.contains(photoId)) {
      newSet.remove(photoId);
    } else {
      newSet.add(photoId);
    }
    state = state.copyWith(pendingDeleteIds: newSet);
  }

  /// 清除所有待删除标记。
  void clearPendingDelete() {
    state = state.copyWith(pendingDeleteIds: {});
  }

  /// 获取待删除照片 ID 集合。
  Set<String> get pendingDeleteIds => state.pendingDeleteIds;

  /// 获取待删除照片数量。
  int get pendingDeleteCount => state.pendingDeleteIds.length;
}

/// 全局删除查看器状态入口。
final deleteViewerProvider =
    NotifierProvider<DeleteViewerNotifier, DeleteViewerState>(
  DeleteViewerNotifier.new,
);
