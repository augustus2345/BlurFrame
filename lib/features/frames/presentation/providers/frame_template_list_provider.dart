import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/frame_template.dart';
import '../../data/repositories/frame_repository.dart';

/// 模版 tab 列表的数据源 — 暴露 `AsyncValue<List<FrameTemplate>>` 给 UI
/// 走 4 态分派（loading / error / empty / success）。
///
/// 设计要点（与 M1-T5 的 [PhotosNotifier] 对齐）：
/// - **build 同步返回空列表**（CLAUDE.md §7.5：`build()` 不能 await），
///   真正的加载由 [FrameTemplateListNotifier.refresh] 触发；
///   屏幕在 `initState` post-frame 调 [refresh] 拿到真实数据。
/// - **refresh 幂等**：任何时刻都可重复调用。
/// - **错误语义**：Hive 读失败以 `AsyncError` 形式上抛，UI 展示带"重试"按钮。
/// - **写入操作后无需手动 refresh**：duplicate / delete / save 都直接走
///   `_box`，但 [refresh] 会重新 `getAll()`，UI 调一次即可刷新。
class FrameTemplateListNotifier
    extends AsyncNotifier<List<FrameTemplate>> {
  @override
  Future<List<FrameTemplate>> build() async {
    // 故意返回空列表 + AsyncData：首屏不是 loading，真加载由 [refresh] 触发。
    return const <FrameTemplate>[];
  }

  /// 重新从 Hive 拉取全部模版。
  ///
  /// 调用约定：
  /// - 任何时刻都可重复调用（幂等）；
  /// - 长按卡片 → 复制 / 删除 / 编辑保存后都会调一次，让 UI 同步新数据；
  /// - 失败时 state 切到 [AsyncError]；UI 可调 `refresh()` 重试。
  Future<void> refresh() async {
    state = const AsyncValue<List<FrameTemplate>>.loading();
    state = await AsyncValue.guard(
      () async => ref.read(frameRepositoryProvider).getAll(),
    );
  }
}

/// 全局 frame templates 状态入口。
final frameTemplateListProvider =
    AsyncNotifierProvider<FrameTemplateListNotifier, List<FrameTemplate>>(
  FrameTemplateListNotifier.new,
);
