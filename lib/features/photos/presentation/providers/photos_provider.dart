import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/photo_model.dart';
import '../../data/repositories/photo_repository.dart';

/// [PhotoRepository] 的 DI 入口。
///
/// 测试中通过 `ProviderContainer(overrides: [photoRepositoryProvider.overrideWithValue(mock)])`
/// 注入 mock 仓库，避免真实平台通道调用。
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository();
});

/// 照片库状态 — gallery 网格的数据源。
///
/// 设计要点：
/// - **不自动加载**（CLAUDE.md §7.5：`build()` 保持同步，async 走显式方法）。
///   gallery 在 `initState` 之后调 [PhotosNotifier.refresh] 触发首次扫描；
///   这样 `build()` 不会被 await 阻塞、测试也无需 mock 异步副作用。
/// - **refresh 暴露 `AsyncValue`** — gallery 用 `when(loading, error, data)`
///   分派 4 态（M1-T9）。
/// - **错误语义**：扫描失败（系统权限撤回 / 平台通道异常 / 解析失败）以
///   `AsyncError` 形式上抛，UI 展示带"重试"按钮的 error 视图。
class PhotosNotifier extends AsyncNotifier<List<PhotoModel>> {
  @override
  Future<List<PhotoModel>> build() async {
    // 故意返回空列表 + AsyncData 形态：首屏不是 loading。
    // 真加载由 [refresh] 触发，避免 `build` 内 await 拖慢初次 build。
    return const <PhotoModel>[];
  }

  /// 从系统相册拉取最新照片列表并合并 Hive 中已有数据。
  ///
  /// 调用约定：
  /// - 任何时刻都可重复调用（幂等）；多次调用按各自结果覆盖 state。
  /// - 下拉刷新 / `pull-to-refresh` 走同一个入口（M5 再加 UI）。
  /// - 失败时 state 切到 [AsyncError]；UI 可调 `refresh()` 重试。
  Future<void> refresh() async {
    state = const AsyncValue<List<PhotoModel>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(photoRepositoryProvider).loadAllFromSystem(),
    );
  }

  /// 删除指定 id 的照片（仅删除 App 内记录，不影响系统相册原图）。
  ///
  /// 删除后刷新列表，让 UI 立即感知变化。
  Future<void> delete(String id) async {
    await ref.read(photoRepositoryProvider).delete(id);
    // 刷新列表：删除后当前 index 会由 DeleteViewerNotifier.onDeleted 处理
    await refresh();
  }
}

/// 全局 photos 状态入口。
final photosProvider =
    AsyncNotifierProvider<PhotosNotifier, List<PhotoModel>>(
  PhotosNotifier.new,
);