import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../photos/presentation/providers/asset_thumbnail_loader_provider.dart';
import '../../data/models/album_model.dart';
import '../providers/album_detail_provider.dart';
import '../providers/album_list_provider.dart';

/// 影集详情页路由目标 — `/albums/:id`（rootNavigator 上 push，全屏沉浸）。
///
/// M3-T5 版式支持：
/// - [AlbumLayout.grid] — 2 列网格
/// - [AlbumLayout.magazine] — 杂志风大图 + 小图
/// - [AlbumLayout.collage] — 拼贴风格
/// - [AlbumLayout.polaroid] — 宝丽莲风格（拍立得）
///
/// 每个版式都支持手动切换 1/2/3/4 宫格覆盖。
///
/// 版式自动选择 [autoLayout]：
/// - 1 张 → 1 宫格
/// - 2 张 → 2 宫格
/// - 3-4 张 → 2×2 宫格
/// - 5+ 张 → 2 列网格（可滚动）
class AlbumDetailScreen extends ConsumerStatefulWidget {
  const AlbumDetailScreen({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  /// 当前手动选择的宫格数。null 表示跟随 autoLayout。
  int? _manualGridCount;

  @override
  Widget build(BuildContext context) {
    final album = ref.watch(albumByIdProvider(widget.albumId));
    final asyncAlbums = ref.watch(albumListProvider);

    // 列表还在 loading / error，且 album 查不到时显示 loading/error 态
    if (album == null) {
      return asyncAlbums.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('影集')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('影集')),
          body: _ErrorView(
            onRetry: () => ref.read(albumListProvider.notifier).refresh(),
          ),
        ),
        data: (_) => Scaffold(
          appBar: AppBar(title: const Text('影集')),
          body: const Center(child: Text('影集不存在')),
        ),
      );
    }

    final photoIds = album.photoIds;
    final effectiveGridCount = _manualGridCount ?? autoLayout(photoIds.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(album.name),
        actions: [
          // 版式切换按钮
          PopupMenuButton<int>(
            icon: const Icon(Icons.grid_on),
            tooltip: '切换宫格',
            onSelected: (count) {
              setState(() => _manualGridCount = count == effectiveGridCount ? null : count);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text('1 宫格')),
              const PopupMenuItem(value: 2, child: Text('2 宫格')),
              const PopupMenuItem(value: 3, child: Text('3 宫格')),
              const PopupMenuItem(value: 4, child: Text('4 宫格')),
            ],
          ),
        ],
      ),
      body: photoIds.isEmpty
          ? const EmptyState(
              icon: Icons.photo_library_outlined,
              title: '影集为空',
              message: '还没有添加照片',
            )
          : _AlbumPhotoGrid(
              key: ValueKey('${album.id}_${effectiveGridCount}_$_manualGridCount'),
              photoIds: photoIds,
              gridCount: effectiveGridCount,
              albumLayout: album.layout,
            ),
    );
  }
}

/// 错误视图（带重试按钮）。
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 根据照片数量自动选择宫格数。
///
/// - 1 张 → 1 宫格
/// - 2 张 → 2 宫格
/// - 3-4 张 → 2×2（4 宫格）
/// - 5+ 张 → 2 列网格
int autoLayout(int photoCount) {
  if (photoCount <= 1) return 1;
  if (photoCount == 2) return 2;
  if (photoCount <= 4) return 4;
  return 2; // 5+ 时用 2 列可滚动网格
}

/// 影集照片网格视图。
///
/// [gridCount] 决定每行展示几张照片（1/2/3/4）。
/// [albumLayout] 决定整体风格（目前统一用网格，M3-T5 先实现核心网格）。
class _AlbumPhotoGrid extends ConsumerWidget {
  const _AlbumPhotoGrid({
    required this.photoIds,
    required this.gridCount,
    required this.albumLayout,
    super.key,
  });

  final List<String> photoIds;
  final int gridCount;
  final AlbumLayout albumLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailLoader = ref.watch(assetThumbnailLoaderProvider);

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCount,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1, // 1:1 正方形
      ),
      itemCount: photoIds.length,
      itemBuilder: (context, index) {
        final photoId = photoIds[index];
        return _AlbumPhotoTile(
          key: ValueKey('album_photo_tile_$photoId'),
          photoId: photoId,
          thumbnailLoader: thumbnailLoader,
          onTap: () {
            context.push('/photo/$photoId');
          },
        );
      },
    );
  }
}

/// 影集详情页单张照片格子。
class _AlbumPhotoTile extends StatelessWidget {
  const _AlbumPhotoTile({
    required this.photoId,
    required this.thumbnailLoader,
    this.onTap,
    super.key,
  });

  final String photoId;
  final Future<Uint8List?> Function(String assetId) thumbnailLoader;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<Uint8List?>(
        future: thumbnailLoader(photoId),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done || bytes == null) {
            return Container(
              color: Theme.of(context).dividerColor,
              child: const Center(
                child: Icon(Icons.photo, color: Colors.white54),
              ),
            );
          }
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      ),
    );
  }
}