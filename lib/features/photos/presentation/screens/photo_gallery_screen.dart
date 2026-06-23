import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../data/models/photo_model.dart';
import '../../data/photo_permission_status.dart';
import '../providers/asset_thumbnail_loader_provider.dart';
import '../providers/photo_permission_provider.dart';
import '../providers/photos_provider.dart';
import '../widgets/photo_grid_item.dart';
import 'permission_request_screen.dart';

/// 相册主屏 — 设备所有照片的入口。
///
/// 当前阶段（M1-T5）的职责：
/// 1. 在 [initState] 调 [PhotoPermissionNotifier.refresh] 拉取真实权限态
/// 2. 根据权限态分派渲染：
///    - **usable**（`granted` / `limited`）→ 显示 4 态网格主体：
///      - **loading** — [CircularProgressIndicator]
///      - **error**   — 重试 EmptyState，调 [PhotosNotifier.refresh]
///      - **empty**   — "暂无照片" EmptyState
///      - **success** — 3 列网格（[PhotoGridItem]），缩略图走注入的
///        [assetThumbnailLoaderProvider]（生产用 photo_manager）
///    - **未授权 / 拒绝 / 限制 / 等待系统** → 显示 [PermissionRequestScreen]
///
/// 后续 M1 任务将承载：
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
    // 同一个 post-frame 里也触发 photos 刷新 — 权限通过后我们立刻要看到网格。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(photoPermissionProvider.notifier).refresh();
      ref.read(photosProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(photoPermissionProvider);
    final permNotifier = ref.read(photoPermissionProvider.notifier);

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
      body: _buildBody(status, permNotifier),
    );
  }

  /// 权限分派：usable → 4 态网格；其余 → 引导屏。
  Widget _buildBody(
    PhotoPermissionStatus status,
    PhotoPermissionNotifier permNotifier,
  ) {
    if (!status.isUsable) {
      return PermissionRequestScreen(
        status: status,
        onRequest: permNotifier.request,
        onOpenSettings: permNotifier.openSettings,
      );
    }
    return const _GalleryBody();
  }
}

/// 授权通过后的 4 态主体。
///
/// 自身是 [ConsumerWidget]，watch [photosProvider] 决定渲染哪一种视图。
class _GalleryBody extends ConsumerWidget {
  const _GalleryBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPhotos = ref.watch(photosProvider);
    return asyncPhotos.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          key: Key('photo_gallery_loading_indicator'),
        ),
      ),
      error: (error, _) => _GalleryError(
        error: error,
        onRetry: () => ref.read(photosProvider.notifier).refresh(),
      ),
      data: (photos) {
        if (photos.isEmpty) {
          return const EmptyState(
            key: Key('photo_gallery_empty_state'),
            icon: Icons.photo_library_outlined,
            title: '暂无照片',
            message: '设备上没有可展示的照片',
          );
        }
        return _PhotoGrid(photos: photos);
      },
    );
  }
}

/// 错误态 — 带"重试"按钮。
class _GalleryError extends StatelessWidget {
  const _GalleryError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      key: const Key('photo_gallery_error_state'),
      icon: Icons.error_outline,
      title: '加载失败',
      message: '无法读取相册：$error',
      action: FilledButton(
        key: const Key('photo_gallery_retry_button'),
        onPressed: onRetry,
        child: const Text('重试'),
      ),
    );
  }
}

/// 3 列网格。
///
/// 单独成 widget 而不是在 `_GalleryBody` 内 inline，便于 widget 测试用 `Key`
/// 锁定断言点。
class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({required this.photos});

  final List<PhotoModel> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailLoader = ref.watch(assetThumbnailLoaderProvider);
    return GridView.builder(
      key: const Key('photo_gallery_grid'),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        // 每个 cell 由 PhotoGridItem 内部用 AspectRatio 锁 1:1，
        // 这里把 mainAxisSpacing / childAspectRatio 都用 0 让 item 自己控制高度。
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return PhotoGridItem(
          key: ValueKey<String>('photo_grid_item_${photo.id}'),
          photo: photo,
          thumbnailLoader: (p) => thumbnailLoader(p.id),
        );
      },
    );
  }
}