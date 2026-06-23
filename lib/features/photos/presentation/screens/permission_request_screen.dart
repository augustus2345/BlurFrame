import 'package:flutter/material.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../data/photo_permission_status.dart';

/// 权限引导屏：首启或权限被拒后显示。
///
/// 设计为纯展示 + 回调注入，不直接调用 `photo_manager`。
/// 父级（`PhotoGalleryScreen`）通过 [photoPermissionProvider] 拿到
/// 状态和动作实现，本屏只负责：
/// 1. 根据 [status] 决定主标题 / 副标题 / 按钮
/// 2. 在按钮点击时回调 [onRequest] / [onOpenSettings]
///
/// 状态映射：
/// - [PhotoPermissionStatus.notDetermined] → "查看你的相册" + 授权按钮
/// - [PhotoPermissionStatus.requesting]    → loading 指示（防双击）
/// - [PhotoPermissionStatus.denied]        → "需要相册权限" + 打开系统设置按钮
/// - [PhotoPermissionStatus.restricted]    → "系统限制访问" + 打开系统设置按钮
/// - [PhotoPermissionStatus.granted] / [PhotoPermissionStatus.limited]
///   → 兜底"已授权"（理论上父级不渲染本屏；保留以防 race）
class PermissionRequestScreen extends StatelessWidget {
  const PermissionRequestScreen({
    super.key,
    required this.status,
    required this.onRequest,
    required this.onOpenSettings,
  });

  /// 当前权限态。驱动整屏 UI 形态。
  final PhotoPermissionStatus status;

  /// 用户点击"授权访问"时调用。父级应负责驱动状态到 [PhotoPermissionStatus.requesting] 并触发系统对话框。
  final Future<void> Function() onRequest;

  /// 用户点击"打开系统设置"时调用。
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PhotoPermissionStatus.requesting => const _RequestingView(),
      PhotoPermissionStatus.notDetermined => _NotDeterminedView(
          onRequest: onRequest,
        ),
      PhotoPermissionStatus.denied => _NeedsSettingsView(
          icon: Icons.no_photography_outlined,
          title: '需要相册权限',
          message: '请在系统设置中开启相册访问权限',
          onOpenSettings: onOpenSettings,
        ),
      PhotoPermissionStatus.restricted => _NeedsSettingsView(
          icon: Icons.lock_outline,
          title: '系统限制访问',
          message: '当前设备策略禁止访问相册，请联系设备管理员',
          onOpenSettings: onOpenSettings,
        ),
      PhotoPermissionStatus.granted ||
      PhotoPermissionStatus.limited =>
        const _GrantedFallbackView(),
    };
  }
}

/// 首启 / 未决定态：友好引导 + 授权按钮。
class _NotDeterminedView extends StatelessWidget {
  const _NotDeterminedView({required this.onRequest});

  final Future<void> Function() onRequest;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.photo_library_outlined,
      title: '查看你的相册',
      message: 'Photo Beauty 不会上传你的照片，所有处理都在本机完成',
      action: FilledButton(
        key: const Key('permission_grant_button'),
        // fire-and-forget：父级（provider）通过 status 切换自行管理
        // requesting 中间态。这里不 await 是为了避免父级 callback 重入。
        onPressed: onRequest,
        child: const Text('授权访问'),
      ),
    );
  }
}

/// 等待系统授权响应：显示 spinner，无可点按钮（防双击）。
class _RequestingView extends StatelessWidget {
  const _RequestingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(
            key: Key('permission_requesting_indicator'),
          ),
          SizedBox(height: 16),
          Text('等待系统授权'),
        ],
      ),
    );
  }
}

/// 拒绝 / 限制态：共同 UI（不同 copy），引导去系统设置。
class _NeedsSettingsView extends StatelessWidget {
  const _NeedsSettingsView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      action: FilledButton(
        key: const Key('permission_settings_button'),
        onPressed: onOpenSettings,
        child: const Text('打开系统设置'),
      ),
    );
  }
}

/// 兜底视图：granted / limited 时本不应出现；保留以便 race 时不闪黑屏。
class _GrantedFallbackView extends StatelessWidget {
  const _GrantedFallbackView();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.check_circle_outline,
      title: '已授权',
      message: '可以查看你的相册了',
    );
  }
}
