import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/delete_viewer_provider.dart';
import '../providers/full_image_loader_provider.dart';
import '../providers/photos_provider.dart';
import '../widgets/photo_viewer.dart';

/// 删除 tab 主屏 — 单张照片全屏查看器（黑底）。
///
/// 承载原"清理模式"：单图全屏展示，支持上一张/下一张切换，
/// M5-T7 增加手势滑动导航和删除功能。
///
/// M5-T6 职责：
/// - 黑底全屏显示当前照片（用 [PhotoViewer]）
/// - 顶栏：`‹` 返回 / `N / M` 位置计数 / 右上 `⋯` 操作菜单
/// - 左右箭头按钮切换上/下一张
///
/// M5-T7 手势：
/// - ↑ 滑 → 删除当前照片 + 撤销 toast（5s）
/// - ← 滑 → 上一张
/// - → 滑 → 下一张
class DeleteViewerScreen extends ConsumerStatefulWidget {
  /// 路由 `/delete-viewer` 的目标 widget。由 `AppShell` 包裹。
  const DeleteViewerScreen({super.key});

  @override
  ConsumerState<DeleteViewerScreen> createState() => _DeleteViewerScreenState();
}

class _DeleteViewerScreenState extends ConsumerState<DeleteViewerScreen> {
  @override
  void initState() {
    super.initState();
    // 初始化当前索引为 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(deleteViewerProvider.notifier).initialize(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncPhotos = ref.watch(photosProvider);
    final viewerState = ref.watch(deleteViewerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: asyncPhotos.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white38,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '没有照片',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            );
          }

          final currentIndex =
              viewerState.currentIndex.clamp(0, photos.length - 1);
          final currentPhoto = photos[currentIndex];
          final aspectRatio =
              (currentPhoto.width ?? 1) / (currentPhoto.height ?? 1);

          final fullImageLoader = ref.watch(fullImageLoaderProvider);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 照片主体（黑底全屏）—— 手势检测 + FutureBuilder 处理加载态
              // 手势：↑ 滑删除 / ← 上一张 / → 下一张
              Center(
                child: _SwipePhotoViewer(
                  key: ValueKey(currentPhoto.id),
                  photoId: currentPhoto.id,
                  aspectRatio: aspectRatio,
                  fullImageLoader: fullImageLoader,
                  onSwipeUp: () => _handleDelete(context, currentPhoto.id),
                  onSwipeLeft: viewerState.currentIndex > 0
                      ? () => ref
                          .read(deleteViewerProvider.notifier)
                          .goToPrevious(photos.length)
                      : null,
                  onSwipeRight: photos.length > 1 &&
                          viewerState.currentIndex < photos.length - 1
                      ? () => ref
                          .read(deleteViewerProvider.notifier)
                          .goToNext(photos.length)
                      : null,
                ),
              ),

              // 顶栏
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _DeleteViewerAppBar(
                  currentIndex: currentIndex,
                  totalCount: photos.length,
                  onBack: () => context.pop(),
                  onMenuPressed: () => _showMenuSheet(context),
                ),
              ),

              // 左右切换按钮
              if (photos.length > 1) ...[
                // 左侧：上一张
                Positioned(
                  left: 0,
                  top: 80,
                  bottom: 0,
                  child: _NavigationArrow(
                    icon: Icons.chevron_left,
                    onTap: viewerState.currentIndex > 0
                        ? () => ref
                            .read(deleteViewerProvider.notifier)
                            .goToPrevious(photos.length)
                        : null,
                  ),
                ),
                // 右侧：下一张
                Positioned(
                  right: 0,
                  top: 80,
                  bottom: 0,
                  child: _NavigationArrow(
                    icon: Icons.chevron_right,
                    onTap: viewerState.currentIndex < photos.length - 1
                        ? () => ref
                            .read(deleteViewerProvider.notifier)
                            .goToNext(photos.length)
                        : null,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// 处理上滑删除：删除照片 + 显示撤销 toast（5s）。
  Future<void> _handleDelete(BuildContext context, String photoId) async {
    final photos = ref.read(photosProvider).valueOrNull ?? [];
    final deletedPhoto = photos.firstWhere(
      (p) => p.id == photoId,
      orElse: () => throw StateError('photo not found: $photoId'),
    );

    // 删除照片（只删 App 记录，不影响系统相册）
    await ref.read(photosProvider.notifier).delete(photoId);

    if (!context.mounted) return;

    // 通知 deleteViewer 更新 index（如果还有剩余照片）
    if (photos.length > 1) {
      ref.read(deleteViewerProvider.notifier).onDeleted(photos.length - 1);
    } else {
      // 没有照片了，退出
      if (context.canPop()) context.pop();
    }

    // 显示撤销 toast（5s）
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已删除'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            // 撤销：重新保存该照片记录
            await ref.read(photoRepositoryProvider).save(deletedPhoto);
            await ref.read(photosProvider.notifier).refresh();
          },
        ),
      ),
    );
  }

  void _showMenuSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white),
              title: const Text(
                '退出清理模式',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (context.canPop()) {
                  context.pop();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.select_all, color: Colors.white),
              title:
                  const Text('进入多选', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('多选功能即将推出')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_list, color: Colors.white),
              title:
                  const Text('切换过滤', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('过滤功能即将推出')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 负责加载单张照片全量字节的 widget。
///
/// 使用 [FutureBuilder] 避免在 build() 中触发 setState 导致的无限重建。
/// - loading: 显示带透明度的占位符
/// - error/null: 显示图片图标占位（而不是转圈 spinner，防止 pumpAndSettle 超时）
class _PhotoLoader extends StatelessWidget {
  const _PhotoLoader({
    super.key,
    required this.photoId,
    required this.aspectRatio,
    required this.fullImageLoader,
  });

  final String photoId;
  final double aspectRatio;
  final Future<Uint8List?> Function(String) fullImageLoader;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: fullImageLoader(photoId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 加载中：显示占位符而不是 spinner，避免 pumpAndSettle 超时
          return AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              color: Colors.grey.shade900,
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.white24,
                  size: 64,
                ),
              ),
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null) {
          // 加载失败或无数据：显示占位图标
          return AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              color: Colors.grey.shade900,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white24,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '无法加载',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return PhotoViewer(
          imageBytes: bytes,
          aspectRatio: aspectRatio,
        );
      },
    );
  }
}

/// 删除查看器顶栏。
class _DeleteViewerAppBar extends StatelessWidget {
  const _DeleteViewerAppBar({
    required this.currentIndex,
    required this.totalCount,
    required this.onBack,
    required this.onMenuPressed,
  });

  final int currentIndex;
  final int totalCount;
  final VoidCallback onBack;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack,
                tooltip: '返回',
              ),
              const Spacer(),
              // 位置计数 N / M
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${currentIndex + 1} / $totalCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: onMenuPressed,
                tooltip: '更多',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 左右切换箭头按钮。
class _NavigationArrow extends StatelessWidget {
  const _NavigationArrow({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// 带手势检测的照片查看器（M5-T7 新增）。
///
/// - ↑ 滑（> 50px）→ [onSwipeUp]
/// - ← 滑（> 50px）→ [onSwipeLeft]
/// - → 滑（> 50px）→ [onSwipeRight]
///
/// 手势方向判定：|dx| > |dy| → 水平；否则 → 垂直。
/// 垂直方向仅响应上滑（删除），忽略下滑。
class _SwipePhotoViewer extends StatefulWidget {
  const _SwipePhotoViewer({
    super.key,
    required this.photoId,
    required this.aspectRatio,
    required this.fullImageLoader,
    required this.onSwipeUp,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  final String photoId;
  final double aspectRatio;
  final Future<Uint8List?> Function(String) fullImageLoader;
  final VoidCallback onSwipeUp;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  @override
  State<_SwipePhotoViewer> createState() => _SwipePhotoViewerState();
}

class _SwipePhotoViewerState extends State<_SwipePhotoViewer> {
  double _startX = 0;
  double _startY = 0;
  static const double _threshold = 50;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _startX = details.globalPosition.dx;
        _startY = details.globalPosition.dy;
      },
      onPanEnd: (details) {
        final dx = details.globalPosition.dx - _startX;
        final dy = details.globalPosition.dy - _startY;

        // 方向判定：|dx| > |dy| → 水平；否则 → 垂直
        if (dx.abs() > dy.abs()) {
          // 水平滑动
          if (dx > _threshold && widget.onSwipeRight != null) {
            widget.onSwipeRight!();
          } else if (dx < -_threshold && widget.onSwipeLeft != null) {
            widget.onSwipeLeft!();
          }
        } else {
          // 垂直滑动：仅响应上滑（删除）
          if (dy < -_threshold) {
            widget.onSwipeUp();
          }
        }
      },
      child: _PhotoLoader(
        key: ValueKey('loader_${widget.photoId}'),
        photoId: widget.photoId,
        aspectRatio: widget.aspectRatio,
        fullImageLoader: widget.fullImageLoader,
      ),
    );
  }
}
