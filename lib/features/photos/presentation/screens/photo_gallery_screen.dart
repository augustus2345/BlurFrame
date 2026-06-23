import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../data/photo_permission_status.dart';
import '../providers/photo_permission_provider.dart';
import 'permission_request_screen.dart';

/// 相册主屏 — 设备所有照片的入口。
///
/// 当前阶段（M1-T1）的职责：
/// 1. 在 [initState] 调 [PhotoPermissionNotifier.refresh] 拉取真实权限态
/// 2. 根据权限态分派渲染：
///    - **usable**（`granted` / `limited`）→ 显示 gallery 主体（目前是占位 EmptyState；
///      M1-T3 起会换成 3 列缩略图网格 + 懒加载）
///    - **未授权 / 拒绝 / 限制 / 等待系统** → 显示 [PermissionRequestScreen]
///
/// 后续 M1 任务将承载：
/// - 3 列网格（`photo_manager` 读取的 `AssetEntity` 缩略图）
/// - 缩略图懒加载 + 无限滚动分页
/// - 长按照片进入多选模式（顶部出现批量操作栏：相框 / 影集 / 标签 / 删除）
/// - 顶部 AppBar 右侧"清理"按钮 → 进入清理模式（M5），上滑单张删除
class PhotoGalleryScreen extends ConsumerStatefulWidget {
  /// 路由 `/gallery` 的目标 widget。由 `AppShell` 包裹。
  const PhotoGalleryScreen({super.key});

  @override
  ConsumerState<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends ConsumerState<PhotoGalleryScreen> {
  @override
  void initState() {
    super.initState();
    // `refresh` 涉及 await，必须推到首帧之后再读 provider / 触发平台通道。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(photoPermissionProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(photoPermissionProvider);
    final notifier = ref.read(photoPermissionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('相册'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '清理',
            onPressed: () {
              // TODO(M5): navigate to /cleanup — single-photo cleanup mode.
            },
          ),
        ],
      ),
      body: _buildBody(status, notifier),
    );
  }

  /// 权限分派：usable → 主体；其余 → 引导屏。
  Widget _buildBody(PhotoPermissionStatus status, PhotoPermissionNotifier notifier) {
    if (status.isUsable) {
      return const _GalleryPlaceholder();
    }
    return PermissionRequestScreen(
      status: status,
      onRequest: notifier.request,
      onOpenSettings: notifier.openSettings,
    );
  }
}

/// 主体占位 — M1-T3 替换为 3 列缩略图网格。
///
/// 独立成 widget 方便 M1-T3 直接替换 build 内引用。
class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.photo_library_outlined,
      title: '暂无照片',
      message: '授权后这里会展示你设备上的所有照片',
    );
  }
}
