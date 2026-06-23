import 'package:photo_manager/photo_manager.dart';

import 'photo_permission_status.dart';

/// 封装 `photo_manager` 权限 API，对业务层暴露 [PhotoPermissionStatus]。
///
/// 设计动机：
/// 1. UI / Provider 不直接依赖 `package:photo_manager` 的 `PermissionState` 枚举。
///    未来若切换权限实现（如 `permission_handler`），只需改本文件。
/// 2. 构造函数接受三个可注入的函数，便于在测试中 mock 而不触发真实平台通道。
///
/// 默认参数全部走 `PhotoManager` 静态方法，生产代码无需任何配置。
/// `PhotoManager.getPermissionState` / `requestPermissionExtend` 内部
/// 已使用默认 `PermissionRequestOption()`，故在静态方法中一次性传默认值即可。
class PhotoPermissionRepository {
  /// 测试 / DI 入口：传入三个伪函数以替代真实平台调用。
  ///
  /// 不传则默认走 `PhotoManager` 静态方法（已使用默认 `PermissionRequestOption`）。
  PhotoPermissionRepository({
    Future<PermissionState> Function()? getCurrent,
    Future<PermissionState> Function()? request,
    Future<void> Function()? openSettings,
  })  : _getCurrent = getCurrent ?? _defaultGetCurrent,
        _request = request ?? _defaultRequest,
        _openSettings = openSettings ?? PhotoManager.openSetting;

  final Future<PermissionState> Function() _getCurrent;
  final Future<PermissionState> Function() _request;
  final Future<void> Function() _openSettings;

  /// 当前权限态（不弹系统对话框）。用于 App 启动时恢复状态。
  Future<PhotoPermissionStatus> current() async {
    final state = await _getCurrent();
    return _convert(state);
  }

  /// 触发系统授权对话框，返回用户选择后的新状态。
  ///
  /// 注意：iOS / Android 在用户拒绝一次后，再次调用通常**不会**再弹对话框。
  /// 此时用户必须去系统设置手动开启 — UI 层用
  /// [PhotoPermissionStatusX.needsSystemSettings] 判定后给"打开系统设置"按钮。
  Future<PhotoPermissionStatus> request() async {
    final state = await _request();
    return _convert(state);
  }

  /// 跳到系统设置。用户在系统设置中改完后，UI 应主动调 [current] 重新拉取状态。
  Future<void> openSettings() => _openSettings();

  static Future<PermissionState> _defaultGetCurrent() {
    return PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(),
    );
  }

  static Future<PermissionState> _defaultRequest() {
    return PhotoManager.requestPermissionExtend();
  }

  static PhotoPermissionStatus _convert(PermissionState state) {
    return switch (state) {
      PermissionState.notDetermined => PhotoPermissionStatus.notDetermined,
      PermissionState.denied => PhotoPermissionStatus.denied,
      PermissionState.restricted => PhotoPermissionStatus.restricted,
      PermissionState.authorized => PhotoPermissionStatus.granted,
      PermissionState.limited => PhotoPermissionStatus.limited,
    };
  }
}
