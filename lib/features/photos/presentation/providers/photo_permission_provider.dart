import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app.dart';
import '../../data/photo_permission_repository.dart';
import '../../data/photo_permission_status.dart';

/// [PhotoPermissionRepository] 的 DI 入口。
///
/// 测试中通过 `ProviderContainer(overrides: [photoPermissionRepositoryProvider.overrideWithValue(...)])`
/// 注入 mock 仓库，避免真实平台通道调用。
final photoPermissionRepositoryProvider = Provider<PhotoPermissionRepository>(
  (ref) => PhotoPermissionRepository(),
);

/// 当前照片库权限状态。
///
/// 初始化为 [PhotoPermissionStatus.notDetermined]（未知态）。`PhotoGalleryScreen`
/// 在 `initState` / `didChangeDependencies` 中调 [PhotoPermissionNotifier.refresh]
/// 拉取真实状态。
///
/// UI 形态由状态决定（见 `PermissionRequestScreen` 的状态映射）。
class PhotoPermissionNotifier extends Notifier<PhotoPermissionStatus> {
  @override
  PhotoPermissionStatus build() => PhotoPermissionStatus.notDetermined;

  /// 异步读取当前权限态（不弹系统对话框）。
  ///
  /// 应在 gallery 进入前台时调用一次（`initState` 中），让 UI 与真实态同步。
  Future<void> refresh() async {
    final repo = ref.read(photoPermissionRepositoryProvider);
    state = await repo.current();
  }

  /// 触发系统授权对话框。
  ///
  /// 状态机：
  /// 1. 先同步把 `state` 切到 [PhotoPermissionStatus.requesting]（**await 之前**），
  ///    这样 UI 能立刻切到 loading 视图，**避免快速双击触发两次系统对话框**。
  /// 2. `await` 系统响应。
  /// 3. 用真实结果覆盖 `state`。
  /// 4. 若结果是可用的（`granted` / `limited`），调
  ///    `SettingsService.markFirstLaunchDone()` 标记首启完成。
  ///
  /// 若结果为 `denied` / `restricted`，保留 `first_launch = true` —— 下次启动
  /// 仍然显示引导页（这次展示"打开系统设置"按钮版本）。
  Future<void> request() async {
    final repo = ref.read(photoPermissionRepositoryProvider);
    state = PhotoPermissionStatus.requesting;
    final next = await repo.request();
    state = next;
    if (next.isUsable) {
      await ref.read(settingsServiceProvider).markFirstLaunchDone();
    }
  }

  /// 跳到系统设置页。用户在系统设置中改完授权后，调用 [refresh] 拉取新状态。
  ///
  /// 本方法内部自动调一次 [refresh]，覆盖"用户改完回 App"的常见路径。
  /// 但若 App 已被系统杀掉（设置页 → 强杀），则由 UI 重建时再次 [refresh]。
  Future<void> openSettings() async {
    final repo = ref.read(photoPermissionRepositoryProvider);
    await repo.openSettings();
    await refresh();
  }
}

/// 全局 photo permission 状态入口。
final photoPermissionProvider =
    NotifierProvider<PhotoPermissionNotifier, PhotoPermissionStatus>(
  PhotoPermissionNotifier.new,
);
