import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../photos/presentation/providers/asset_thumbnail_loader_provider.dart';
import '../../data/models/album_model.dart';
import '../providers/album_list_provider.dart';
import '../widgets/album_grid_item.dart';

/// 影集列表屏 — 主题相册集合的入口。
///
/// 支持：
/// - 2 列网格，每张影集显示封面缩略图 + 标题 + 照片数
/// - 4 态显式：loading / error+retry / empty / success
/// - 右上角 "+" → 打开新建影集流程（M3-T4）
/// - 点击进详情页 `/albums/:id`（M3-T5）
class AlbumListScreen extends ConsumerStatefulWidget {
  const AlbumListScreen({super.key});

  @override
  ConsumerState<AlbumListScreen> createState() => _AlbumListScreenState();
}

class _AlbumListScreenState extends ConsumerState<AlbumListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(albumListProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncAlbums = ref.watch(albumListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('影集'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建影集',
            onPressed: () {
              // TODO(M3-T4): navigate to album create flow
            },
          ),
        ],
      ),
      body: asyncAlbums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(
          onRetry: () => ref.read(albumListProvider.notifier).refresh(),
        ),
        data: (albums) {
          if (albums.isEmpty) {
            return const EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: '还没有影集',
              message: '从相册里多选几张照片，组成一个好看的影集',
            );
          }
          return _AlbumGrid(albums: albums);
        },
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

/// 影集 2 列网格。
class _AlbumGrid extends ConsumerWidget {
  const _AlbumGrid({required this.albums});

  final List<AlbumModel> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailLoader = ref.watch(assetThumbnailLoaderProvider);

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return AlbumGridItem(
          key: Key('album_grid_item_${album.id}'),
          album: album,
          thumbnailLoader: thumbnailLoader,
          onTap: () {
            // TODO(M3-T5): navigate to detail
          },
        );
      },
    );
  }
}