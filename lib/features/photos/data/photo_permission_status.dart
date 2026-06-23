/// 简化的权限状态 — 业务层与 photo_manager [PermissionState] 之间的隔离层。
///
/// 设计动机：
/// 1. UI 不直接依赖 `package:photo_manager`，方便测试与未来切换实现。
/// 2. 业务命名 `granted` 比 photo_manager 的 `authorized` 更直观。
/// 3. 多一个 `requesting` 显式表达"等待用户在系统对话框中响应"的中间态。
enum PhotoPermissionStatus {
  /// 尚未请求（首启 / 用户从未回复系统对话框）。
  notDetermined,

  /// 正在等待用户在系统授权对话框中响应。
  requesting,

  /// 用户拒绝。
  denied,

  /// 系统限制（如家长控制 / MDM / 企业策略）。
  restricted,

  /// 用户授权完整访问。
  granted,

  /// 用户授权有限访问（仅部分照片，iOS 14+）。
  limited,
}

/// 业务侧对 [PhotoPermissionStatus] 的判定扩展。
extension PhotoPermissionStatusX on PhotoPermissionStatus {
  /// 是否可以读取照片（`granted` 和 `limited` 都算可用）。
  ///
  /// UI 据此决定是显示 gallery 内容还是权限引导页。
  bool get isUsable =>
      this == PhotoPermissionStatus.granted ||
      this == PhotoPermissionStatus.limited;

  /// 是否处于"已请求过但失败"的状态，需要引导去系统设置。
  bool get needsSystemSettings =>
      this == PhotoPermissionStatus.denied ||
      this == PhotoPermissionStatus.restricted;
}
