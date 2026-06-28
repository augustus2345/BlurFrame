import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app.dart';
import '../providers/delete_viewer_provider.dart';
import '../providers/full_image_loader_provider.dart';
import '../providers/multi_select_provider.dart';
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
///
/// M5-T8 补充：
/// - 首次进入显示操作 hint（3s 后渐隐）
/// - 顶栏菜单「进入多选」→ 跳转相册并进入多选模式
class DeleteViewerScreen extends ConsumerStatefulWidget {
  /// 路由 `/delete-viewer` 的目标 widget。由 `AppShell` 包裹。
  const DeleteViewerScreen({super.key});

  @override
  ConsumerState<DeleteViewerScreen> createState() => _DeleteViewerScreenState();
}

class _DeleteViewerScreenState extends ConsumerState<DeleteViewerScreen> {
  /// 是否显示操作 hint overlay（首次进入后 3s 自动渐隐）。
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    // 初始化当前索引为 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(deleteViewerProvider.notifier).initialize(0);
      _checkAndShowHint();
    });
  }

  /// 检查是否首次进入（hint 未显示过），若是则显示并在 3s 后渐隐。
  void _checkAndShowHint() {
    final settings = ref.read(settingsServiceProvider);
    const hintKey = 'deleteHintShown';
    // 注意：getBool 返回 bool，但 _box.get 泛型推断在 Box<dynamic> 下会推成 Object?，
    // 所以用 == false 而不是 ! 来避免静态类型错误。
    final alreadyShown = settings.getBool(hintKey, defaultValue: false);
    if (alreadyShown == false) {
      setState(() => _showHint = true);
      settings.setBool(hintKey, true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showHint = false);
      });
    }
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
                  key: const Key('swipe_photo_viewer'),
                  photoId: currentPhoto.id,
                  aspectRatio: aspectRatio,
                  fullImageLoader: fullImageLoader,
                  isMarkedDelete: viewerState.pendingDeleteIds.contains(currentPhoto.id),
                  onSwipeUp: () => _handleSwipeUpMark(currentPhoto.id),
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
                  pendingDeleteCount: viewerState.pendingDeleteIds.length,
                  onBack: () => context.pop(),
                  onMenuPressed: () => _showMenuSheet(context),
                  onDelete: viewerState.pendingDeleteIds.isNotEmpty
                      ? () => _handleBatchDelete(context)
                      : null,
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

              // 操作 hint（M5-T8：首次显示，3s 后渐隐）
              if (_showHint)
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: _DeleteHintOverlay(onFadeOut: () {
                    if (mounted) setState(() => _showHint = false);
                  },),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 处理上滑标记：标记照片以待删除（不立即删除）。
  ///
  /// 多次上滑标记后，右上角删除按钮一次性批量删除。
  void _handleSwipeUpMark(String photoId) {
    final notifier = ref.read(deleteViewerProvider.notifier);
    notifier.togglePendingDelete(photoId);

    final isMarked = notifier.pendingDeleteIds.contains(photoId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isMarked ? '已标记待删除' : '已取消标记'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 处理批量删除：删除所有已标记的照片。
  ///
  /// 显示确认对话框，用户确认后执行删除。
  Future<void> _handleBatchDelete(BuildContext context) async {
    final notifier = ref.read(deleteViewerProvider.notifier);
    final pendingIds = notifier.pendingDeleteIds.toList();

    if (pendingIds.isEmpty) return;

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${pendingIds.length} 张照片吗？删除后可在回收站恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 批量删除
    for (final id in pendingIds) {
      await ref.read(photosProvider.notifier).delete(id);
    }

    // 清除标记
    notifier.clearPendingDelete();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除 ${pendingIds.length} 张照片'),
        duration: const Duration(seconds: 2),
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
              title: const Text('进入多选', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _handleEnterMultiSelect(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_list, color: Colors.white),
              title: const Text('切换过滤', style: TextStyle(color: Colors.white)),
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

  /// 进入多选模式：全选当前照片 → 退出删除 tab → 跳转相册。
  void _handleEnterMultiSelect(BuildContext context) {
    final photos = ref.read(photosProvider).valueOrNull ?? [];
    if (photos.isEmpty) return;

    // 全选所有照片，进入多选模式
    ref.read(multiSelectProvider.notifier).selectAll(
          photos.map((p) => p.id).toSet(),
        );
    ref.read(multiSelectProvider.notifier).enterMultiSelectMode();

    // 退出删除 tab，跳转到相册（多选 AppBar 会自动出现）
    if (context.canPop()) context.pop();
    context.go('/gallery');
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
    required this.pendingDeleteCount,
    required this.onBack,
    required this.onMenuPressed,
    required this.onDelete,
  });

  final int currentIndex;
  final int totalCount;
  final int pendingDeleteCount;
  final VoidCallback onBack;
  final VoidCallback onMenuPressed;
  final VoidCallback? onDelete;

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
              const SizedBox(width: 8),
              // 待删除数量
              if (pendingDeleteCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$pendingDeleteCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              // 删除按钮（有待删除时显示）
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: '删除 ($pendingDeleteCount)',
                ),
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
/// - ↑ 滑（> 50px）→ [onSwipeUp] 标记待删除
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
    required this.isMarkedDelete,
  });

  final String photoId;
  final double aspectRatio;
  final Future<Uint8List?> Function(String) fullImageLoader;
  final VoidCallback onSwipeUp;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final bool isMarkedDelete;

  @override
  State<_SwipePhotoViewer> createState() => _SwipePhotoViewerState();
}

class _SwipePhotoViewerState extends State<_SwipePhotoViewer> {
  double _startX = 0;
  double _startY = 0;
  bool _isDragging = false;
  static const double _threshold = 50;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _startX = event.position.dx;
            _startY = event.position.dy;
            _isDragging = false;
          },
          onPointerMove: (event) {
            // 一旦检测到明显的拖动，标记为已拖动（用于决定是否阻止 InteractiveViewer 的手势）
            if (!_isDragging) {
              final dx = (event.position.dx - _startX).abs();
              final dy = (event.position.dy - _startY).abs();
              if (dx > 10 || dy > 10) {
                _isDragging = true;
              }
            }
          },
          onPointerUp: (event) {
            if (!_isDragging) return;

            final dx = event.position.dx - _startX;
            final dy = event.position.dy - _startY;

            // 方向判定：|dx| > |dy| → 水平；否则 → 垂直
            if (dx.abs() > dy.abs()) {
              // 水平滑动
              if (dx > _threshold && widget.onSwipeRight != null) {
                widget.onSwipeRight!();
              } else if (dx < -_threshold && widget.onSwipeLeft != null) {
                widget.onSwipeLeft!();
              }
            } else {
              // 垂直滑动：仅响应上滑（标记删除）
              if (dy < -_threshold) {
                widget.onSwipeUp();
              }
            }
            _isDragging = false;
          },
          child: _PhotoLoader(
            key: ValueKey('loader_${widget.photoId}'),
            photoId: widget.photoId,
            aspectRatio: widget.aspectRatio,
            fullImageLoader: widget.fullImageLoader,
          ),
        ),
        // 标记删除视觉指示
        if (widget.isMarkedDelete)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
      ],
    );
  }
}

/// 删除 tab 操作提示 overlay（M5-T8）。
///
/// 首次进入时显示手势操作说明，3 秒后自动渐隐消失。
/// 渐隐动画 500ms。
class _DeleteHintOverlay extends StatefulWidget {
  const _DeleteHintOverlay({required this.onFadeOut});

  final VoidCallback onFadeOut;

  @override
  State<_DeleteHintOverlay> createState() => _DeleteHintOverlayState();
}

class _DeleteHintOverlayState extends State<_DeleteHintOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // 3s 后开始淡出
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _controller.forward().then((_) => widget.onFadeOut());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: child,
        );
      },
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text(
                  '上滑删除',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(width: 16),
                Icon(Icons.swipe, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text(
                  '左右滑动切换',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
