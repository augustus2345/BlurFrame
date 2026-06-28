import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../frames/data/repositories/frame_repository.dart';
import '../../data/models/photo_model.dart';
import '../../data/photo_permission_status.dart';
import '../providers/asset_thumbnail_loader_provider.dart';
import '../providers/batch_apply_template_provider.dart';
import '../providers/full_image_loader_provider.dart';
import '../providers/multi_select_provider.dart';
import '../providers/photo_permission_provider.dart';
import '../providers/photos_provider.dart';
import '../widgets/apply_template_sheet.dart';
import '../widgets/multi_select_app_bar.dart';
import '../widgets/photo_grid_item.dart';
import '../widgets/star_rating_picker_sheet.dart';
import '../../../albums/presentation/widgets/album_picker_sheet.dart';
import '../../../albums/presentation/providers/album_list_provider.dart';
import '../../../tags/presentation/widgets/tag_picker_sheet.dart';
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
    final multiSelectState = ref.watch(multiSelectProvider);

    return Scaffold(
      appBar: multiSelectState.isMultiSelectMode
          ? MultiSelectAppBar(
              selectedCount: multiSelectState.selectedIds.length,
              totalCount: ref.watch(photosProvider).valueOrNull?.length ?? 0,
              onClose: () =>
                  ref.read(multiSelectProvider.notifier).exitMultiSelectMode(),
              onSelectAll: () {
                final photos = ref.read(photosProvider).valueOrNull ?? [];
                final notifier = ref.read(multiSelectProvider.notifier);
                if (notifier.isAllSelected(photos.map((p) => p.id).toSet())) {
                  notifier.clearSelection();
                } else {
                  notifier.selectAll(photos.map((p) => p.id).toSet());
                }
              },
              onDelete: () => _showDeleteConfirmation(context, ref),
              onTags: () => _handleBatchTags(context, ref),
              onStar: () => _handleBatchStar(context, ref),
              onAlbum: () => _handleBatchAlbum(context, ref),
              onFrame: () => _handleBatchFrame(context, ref),
            )
          : AppBar(
              title: const Text('相册'),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: '搜索',
                  onPressed: () => context.push('/search'),
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services_outlined),
                  tooltip: '清理',
                  onPressed: () => context.go(AppRoute.deleteViewer),
                ),
              ],
            ),
      body: _buildBody(status, permNotifier),
    );
  }

  /// 批量删除确认弹窗。
  Future<void> _showDeleteConfirmation(
      BuildContext context, WidgetRef ref,) async {
    final selectedIds = ref.read(multiSelectProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除选中的 ${selectedIds.length} 张照片吗？'),
            const SizedBox(height: 12),
            Text(
              '注意：仅删除 App 内记录，系统相册中的原图不受影响。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // 删除操作
      final photoRepo = ref.read(photoRepositoryProvider);
      for (final id in selectedIds) {
        await photoRepo.delete(id);
      }
      // 退出多选模式并刷新列表
      ref.read(multiSelectProvider.notifier).exitMultiSelectMode();
      unawaited(ref.read(photosProvider.notifier).refresh());
    }
  }

  /// 批量打标签。
  ///
  /// 弹出 [TagPickerSheet]，用户选择标签后，
  /// 将选中的标签 ADD 到每张选中照片的现有标签列表中，
  /// 然后退出多选模式并刷新列表。
  Future<void> _handleBatchTags(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(multiSelectProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    // 读取所有选中照片的现有标签，取并集作为初始选中
    final photoRepo = ref.read(photoRepositoryProvider);
    final allPhotos = ref.read(photosProvider).valueOrNull ?? [];
    final selectedPhotos = allPhotos.where((p) => selectedIds.contains(p.id));
    final existingTagIds = <String>{};
    for (final photo in selectedPhotos) {
      existingTagIds.addAll(photo.tags);
    }

    await showTagPickerSheet(
      context: context,
      selectedTagIds: existingTagIds,
      onConfirm: (selectedTagIds) async {
        final newTags = selectedTagIds.toList();
        for (final id in selectedIds) {
          await photoRepo.updateTags(id, newTags);
        }
        if (!context.mounted) return;
        ref.read(multiSelectProvider.notifier).exitMultiSelectMode();
        unawaited(ref.read(photosProvider.notifier).refresh());
      },
    );
  }

  /// 批量加星。
  ///
  /// 弹出 [showBatchStarRatingSheet]，用户选择星级后，
  /// 将星级写入每张选中照片，然后退出多选模式并刷新列表。
  Future<void> _handleBatchStar(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(multiSelectProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    await showBatchStarRatingSheet(
      context: context,
      onConfirm: (starRating) async {
        final photoRepo = ref.read(photoRepositoryProvider);
        for (final id in selectedIds) {
          await photoRepo.updateStarRating(id, starRating);
        }
        if (!context.mounted) return;
        ref.read(multiSelectProvider.notifier).exitMultiSelectMode();
        unawaited(ref.read(photosProvider.notifier).refresh());
      },
    );
  }

  /// 批量加入影集。
  ///
  /// 弹出 [showAlbumPickerSheet]，用户选择影集后，
  /// 将选中照片添加到影集，然后退出多选模式并刷新列表。
  Future<void> _handleBatchAlbum(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(multiSelectProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    await showAlbumPickerSheet(
      context: context,
      selectedPhotoIds: selectedIds,
      onConfirm: (albumId) async {
        final albumRepo = ref.read(albumRepositoryProvider);
        await albumRepo.addPhotos(albumId, selectedIds.toList());
        if (!context.mounted) return;
        ref.read(multiSelectProvider.notifier).exitMultiSelectMode();
        unawaited(ref.read(photosProvider.notifier).refresh());
        // 刷新影集列表（封面可能变化）
        unawaited(ref.read(albumListProvider.notifier).refresh());
      },
    );
  }

  /// 批量套模版.
  Future<void> _handleBatchFrame(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(multiSelectProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    // 先选择模板
    final template = await showTemplatePickerSheet(context: context);
    if (template == null) return;

    // 准备 photoLoaders
    final fullImageLoader = ref.read(fullImageLoaderProvider);
    final photoLoaders = <String, Future<Uint8List?> Function()>{};
    for (final id in selectedIds) {
      photoLoaders[id] = () => fullImageLoader(id);
    }

    // 重置状态并启动批量处理
    ref.read(batchApplyTemplateProvider.notifier).reset();
    final frameRepo = ref.read(frameRepositoryProvider);
    await ref.read(batchApplyTemplateProvider.notifier).applyTemplateBatch(
          template: template,
          photoLoaders: photoLoaders,
          frameRepository: frameRepo,
        );

    if (!context.mounted) return;

    // 显示结果 Sheet
    final state = ref.read(batchApplyTemplateProvider);
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: state is! BatchApplyTemplateProcessing,
      enableDrag: state is! BatchApplyTemplateProcessing,
      builder: (ctx) => _BatchResultSheet(state: state),
    );

    // 完成后退出多选模式并刷新
    ref.read(multiSelectProvider.notifier).exitMultiSelectMode();
    unawaited(ref.read(photosProvider.notifier).refresh());
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
///
/// 多选模式（M1-T7）：
/// - watch [multiSelectProvider] 获取当前选中的 ID 集合
/// - [onTap] 在多选模式下 toggle 选择，否则跳详情页
/// - [onLongPress] 进入多选模式并选中当前项
class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({required this.photos});

  final List<PhotoModel> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailLoader = ref.watch(assetThumbnailLoaderProvider);
    final multiSelectState = ref.watch(multiSelectProvider);
    final isMultiSelectMode = multiSelectState.isMultiSelectMode;
    final selectedIds = multiSelectState.selectedIds;

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
        final isSelected = selectedIds.contains(photo.id);
        return PhotoGridItem(
          key: ValueKey<String>('photo_grid_item_${photo.id}'),
          photo: photo,
          thumbnailLoader: (p) => thumbnailLoader(p.id),
          isSelected: isSelected,
          onTap: () {
            if (isMultiSelectMode) {
              // 多选模式：toggle 选中状态
              ref.read(multiSelectProvider.notifier).toggle(photo.id);
            } else {
              // 普通模式：跳详情页
              context.push('/photo/${photo.id}');
            }
          },
          onLongPress: () {
            // 长按进入多选模式并选中当前项
            if (!isMultiSelectMode) {
              ref.read(multiSelectProvider.notifier).enterMultiSelectMode();
            }
            ref.read(multiSelectProvider.notifier).toggle(photo.id);
          },
        );
      },
    );
  }
}

/// 批量套模版结果展示 Sheet.
class _BatchResultSheet extends StatelessWidget {
  const _BatchResultSheet({required this.state});

  final BatchApplyTemplateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 根据状态显示不同内容
          _buildStateContent(state),
        ],
      ),
    );
  }

  Widget _buildStateContent(BatchApplyTemplateState s) {
    if (s is BatchApplyTemplateProcessing) {
      return _ProcessingContent(state: s);
    } else if (s is BatchApplyTemplateDone) {
      return _DoneContent(state: s);
    } else if (s is BatchApplyTemplateError) {
      return _ErrorContent(message: s.message);
    }
    return const SizedBox.shrink();
  }
}

/// 进行中内容.
class _ProcessingContent extends StatelessWidget {
  const _ProcessingContent({required this.state});

  final BatchApplyTemplateProcessing state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          '正在应用 "${state.templateName}"',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${state.current} / ${state.total}',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: state.progress,
          key: const Key('batch_apply_progress_bar'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.successCount > 0) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text('${state.successCount}'),
              const SizedBox(width: 16),
            ],
            if (state.failureCount > 0) ...[
              const Icon(Icons.error, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              Text('${state.failureCount}'),
            ],
          ],
        ),
      ],
    );
  }
}

/// 完成内容.
class _DoneContent extends StatelessWidget {
  const _DoneContent({required this.state});

  final BatchApplyTemplateDone state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          state.failureCount == 0 ? Icons.check_circle : Icons.warning,
          size: 48,
          color: state.failureCount == 0 ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 16),
        Text(
          state.failureCount == 0
              ? '批量应用完成'
              : '批量应用完成（部分失败）',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '模板：${state.templateName}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ResultChip(
              icon: Icons.check_circle,
              color: Colors.green,
              label: '成功 ${state.successCount}',
            ),
            if (state.failureCount > 0) ...[
              const SizedBox(width: 16),
              _ResultChip(
                icon: Icons.error,
                color: Colors.red,
                label: '失败 ${state.failureCount}',
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        if (state.failureCount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                key: const Key('batch_retry_button'),
                onPressed: () {
                  // 重试：关闭当前 sheet，重新执行批量操作
                  Navigator.of(context).pop();
                  // 通过 provider 触发重试
                  _retryBatchApply(context);
                },
                child: const Text('重试失败项'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ],
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
      ],
    );
  }

  void _retryBatchApply(BuildContext context) {
    // 使用 ProviderScope 方式访问 notifier
    // ignore: use_build_context_synchronously
    final container = ProviderScope.containerOf(context);
    container.read(batchApplyTemplateProvider.notifier).retry();
  }
}

/// 结果 chip.
class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

/// 错误内容.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        Text(
          '批量应用失败',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              key: const Key('batch_error_retry_button'),
              onPressed: () {
                Navigator.of(context).pop();
                final container = ProviderScope.containerOf(context);
                container.read(batchApplyTemplateProvider.notifier).retry();
              },
              child: const Text('重试'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ],
    );
  }
}
