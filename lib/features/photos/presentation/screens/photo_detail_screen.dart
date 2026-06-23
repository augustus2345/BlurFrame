import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/photo_model.dart';
import '../providers/full_image_loader_provider.dart';
import '../providers/photos_provider.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/photo_detail_page.dart';

/// 照片详情页路由目标 — `/photo/:assetId`（rootNavigator 上 push，全屏沉浸）。
///
/// 结构：
/// ```
/// Scaffold (黑底)
/// ├── AppBar (back + 第 N / 共 M + 占位)
/// └── Column
///     ├── Expanded → PageView.builder
///     │   └── PhotoDetailPage (4 态: loading/error/empty/success)
///     └── BottomActionBar (5 项操作)
/// ```
///
/// 删除流程（CLAUDE.md §2.5-20 防竞态）：
/// - 弹 AlertDialog 二次确认（由 [BottomActionBar] 负责）。
/// - 确认后调 `PhotoRepository.delete(id)` → `photosProvider.refresh()`。
/// - gallery 列表缩短 → PageView 自动 rebuild；空时 pop。
class PhotoDetailScreen extends ConsumerStatefulWidget {
  const PhotoDetailScreen({required this.assetId, super.key});

  final String assetId;

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(String photoId) async {
    await ref.read(photoRepositoryProvider).delete(photoId);
    await ref.read(photosProvider.notifier).refresh();
    if (!mounted) {
      return;
    }
    final remaining = ref.read(photosProvider).value ?? const <PhotoModel>[];
    if (remaining.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPhotos = ref.watch(photosProvider);
    final photos = asyncPhotos.value ?? const <PhotoModel>[];

    // gallery 还没有数据（首启 + loading / error）→ 空态。
    if (photos.isEmpty) {
      return Scaffold(
        key: const Key('photo_detail_screen_empty'),
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            key: const Key('photo_detail_screen_back'),
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            '相册为空',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final currentIndex = _currentIndex.clamp(0, photos.length - 1);
    final currentPhoto = photos[currentIndex];

    final fullImageLoader = ref.watch(fullImageLoaderProvider);

    return Scaffold(
      key: const Key('photo_detail_screen'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          key: const Key('photo_detail_screen_back'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${currentIndex + 1} / ${photos.length}',
          key: const Key('photo_detail_screen_position'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final photo = photos[index];
                return PhotoDetailPage(
                  key: ValueKey<String>('photo_detail_page_${photo.id}'),
                  assetId: photo.id,
                  fullImageLoader: fullImageLoader,
                );
              },
            ),
          ),
          BottomActionBar(
            photoId: currentPhoto.id,
            onDelete: _handleDelete,
          ),
        ],
      ),
    );
  }
}
