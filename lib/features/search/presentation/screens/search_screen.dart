import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../photos/data/models/photo_model.dart';
import '../../../photos/presentation/providers/asset_thumbnail_loader_provider.dart';
import '../../../photos/presentation/providers/multi_select_provider.dart';
import '../../../photos/presentation/providers/photos_provider.dart';
import '../../../photos/presentation/widgets/photo_grid_item.dart';
import '../../../photos/presentation/widgets/star_rating_picker_sheet.dart';
import '../../../tags/presentation/widgets/tag_picker_sheet.dart';
import '../../data/models/search_filter.dart';
import '../providers/search_provider.dart';
import '../widgets/filter_chip_bar.dart';

/// 搜索 / 过滤二级页.
///
/// 入口：相册 tab 顶部搜索栏 → `context.push('/search')`
///
/// 职责：
/// 1. 顶部 [FilterChipBar] — 展示当前激活的过滤条件 chip，点击弹出选择 sheet
/// 2. 下方 [SearchResultsGrid] — 根据 filter 过滤后的照片网格，支持多选
/// 3. 4 态显式：loading / error / empty（无匹配）/ success
///
/// 过滤逻辑由 [SearchRepository.matches] 承载，不直接操作 Hive.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final multiSelectState = ref.watch(multiSelectProvider);
    final isMultiSelectMode = multiSelectState.isMultiSelectMode;

    return Scaffold(
      appBar: isMultiSelectMode
          ? _buildMultiSelectAppBar(context, ref)
          : AppBar(
              title: const Text('搜索'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  ref.read(searchFilterProvider.notifier).state =
                      const SearchFilter();
                  context.pop();
                },
              ),
            ),
      body: Column(
        children: [
          // 过滤条件 chip 行
          FilterChipBar(
            filter: filter,
            onFilterChanged: (newFilter) {
              ref.read(searchFilterProvider.notifier).state = newFilter;
            },
          ),

          // 结果网格
          const Expanded(child: _SearchResultsBody()),
        ],
      ),
    );
  }

  AppBar _buildMultiSelectAppBar(BuildContext context, WidgetRef ref) {
    final selectedCount = ref.watch(multiSelectProvider).selectedIds.length;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () =>
            ref.read(multiSelectProvider.notifier).exitMultiSelectMode(),
      ),
      title: Text('已选择 $selectedCount 张'),
      actions: [
        IconButton(
          icon: const Icon(Icons.label_outline),
          tooltip: '标签',
          onPressed: () => _handleBatchTags(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.star_outline),
          tooltip: '星级',
          onPressed: () => _handleBatchStarRating(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除',
          onPressed: () => _showDeleteConfirmation(context, ref),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selectedIds = ref.read(multiSelectProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx,) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${selectedIds.length} 张照片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final photoRepo = ref.read(photoRepositoryProvider);
      for (final id in selectedIds) {
        await photoRepo.delete(id);
      }
      ref.read(multiSelectProvider.notifier).exitMultiSelectMode();
      await ref.read(photosProvider.notifier).refresh();
    }
  }

  Future<void> _handleBatchTags(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(multiSelectProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    // 先获取当前选中照片的标签集合（所有选中照片标签的并集）
    final photoRepo = ref.read(photoRepositoryProvider);
    final allSelectedTags = <String>{};
    for (final id in selectedIds) {
      final photo = photoRepo.get(id);
      if (photo != null) {
        allSelectedTags.addAll(photo.tags);
      }
    }

    if (!context.mounted) return;

    await showTagPickerSheet(
      context: context,
      selectedTagIds: allSelectedTags,
      onConfirm: (tagIds) async {
        final tagList = tagIds.toList();
        for (final id in selectedIds) {
          await photoRepo.updateTags(id, tagList);
        }
        ref.read(multiSelectProvider.notifier).exitMultiSelectMode();
        await ref.read(photosProvider.notifier).refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已为 ${selectedIds.length} 张照片设置标签')),
          );
        }
      },
    );
  }

  Future<void> _handleBatchStarRating(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(multiSelectProvider).selectedIds;
    if (selectedIds.isEmpty) return;

    if (!context.mounted) return;

    await showBatchStarRatingSheet(
      context: context,
      onConfirm: (starRating) async {
        final photoRepo = ref.read(photoRepositoryProvider);
        for (final id in selectedIds) {
          await photoRepo.updateStarRating(id, starRating);
        }
        ref.read(multiSelectProvider.notifier).exitMultiSelectMode();
        await ref.read(photosProvider.notifier).refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已为 ${selectedIds.length} 张照片设置 $starRating 星')),
          );
        }
      },
    );
  }
}

/// 搜索结果 4 态主体.
class _SearchResultsBody extends ConsumerWidget {
  const _SearchResultsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncResults = ref.watch(searchResultsProvider);

    return asyncResults.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _SearchError(
        error: error,
        onRetry: () => ref.read(photosProvider.notifier).refresh(),
      ),
      data: (photos) {
        if (photos.isEmpty) {
          final filter = ref.watch(searchFilterProvider);
          return EmptyState(
            key: const Key('search_empty_state'),
            icon: Icons.filter_alt_off_outlined,
            title: '没有匹配的照片',
            message: filter.isEmpty
                ? '从上方选择过滤条件开始搜索'
                : '尝试调整过滤条件后重试',
          );
        }
        return _SearchResultsGrid(photos: photos);
      },
    );
  }
}

/// 错误态.
class _SearchError extends StatelessWidget {
  const _SearchError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      key: const Key('search_error_state'),
      icon: Icons.error_outline,
      title: '加载失败',
      message: '无法读取照片：$error',
      action: FilledButton(
        key: const Key('search_retry_button'),
        onPressed: onRetry,
        child: const Text('重试'),
      ),
    );
  }
}

/// 搜索结果网格（与 _PhotoGrid 同结构）.
class _SearchResultsGrid extends ConsumerWidget {
  const _SearchResultsGrid({required this.photos});

  final List<PhotoModel> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailLoader = ref.watch(assetThumbnailLoaderProvider);
    final multiSelectState = ref.watch(multiSelectProvider);
    final isMultiSelectMode = multiSelectState.isMultiSelectMode;
    final selectedIds = multiSelectState.selectedIds;

    return GridView.builder(
      key: const Key('search_results_grid'),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final isSelected = selectedIds.contains(photo.id);
        return PhotoGridItem(
          key: ValueKey<String>('search_photo_${photo.id}'),
          photo: photo,
          thumbnailLoader: (p) => thumbnailLoader(p.id),
          isSelected: isSelected,
          onTap: () {
            if (isMultiSelectMode) {
              ref.read(multiSelectProvider.notifier).toggle(photo.id);
            } else {
              context.push('/photo/${photo.id}');
            }
          },
          onLongPress: () {
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