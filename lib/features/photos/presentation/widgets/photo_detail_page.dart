import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/photo_model.dart';
import '../providers/photo_by_id_provider.dart';
import 'photo_viewer.dart';

/// 单张照片详情页 —— PageView 内的一页。
///
/// 4 态：
/// - **loading**：fullImageLoader 还在跑
/// - **error**：fullImageLoader 抛错 / 返回 null
/// - **empty**：photoByIdProvider 返回 null
/// - **success**：拿到 PhotoModel + bytes → 渲染 PhotoViewer
///
/// 设计：
/// - 不持有任何状态 —— 4 态完全由 props + `photoByIdProvider` 派生。
/// - `fullImageLoader` 异步加载全尺寸图，**不进 Hive**，每次进入详情页重新加载。
class PhotoDetailPage extends ConsumerWidget {
  const PhotoDetailPage({
    required this.assetId,
    required this.fullImageLoader,
    super.key,
  });

  final String assetId;
  final Future<Uint8List?> Function(String assetId) fullImageLoader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(photoByIdProvider(assetId));
    if (photo == null) {
      return const _PhotoNotFoundView();
    }
    return _PhotoLoadedView(
      assetId: assetId,
      photo: photo,
      fullImageLoader: fullImageLoader,
    );
  }
}

/// 拿到 [PhotoModel] 后的视图 —— 再用 FutureBuilder 加载全尺寸图。
class _PhotoLoadedView extends StatelessWidget {
  const _PhotoLoadedView({
    required this.assetId,
    required this.photo,
    required this.fullImageLoader,
  });

  final String assetId;
  final PhotoModel photo;
  final Future<Uint8List?> Function(String assetId) fullImageLoader;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: fullImageLoader(assetId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PhotoLoadingView();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _PhotoErrorView(error: snapshot.error);
        }
        final bytes = snapshot.data!;
        return PhotoViewer(
          imageBytes: bytes,
          aspectRatio: _computeAspectRatio(),
        );
      },
    );
  }

  double _computeAspectRatio() {
    final width = photo.width;
    final height = photo.height;
    if (width == null || height == null || height == 0) {
      return 1.0;
    }
    return width / height;
  }
}

class _PhotoLoadingView extends StatelessWidget {
  const _PhotoLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        key: Key('photo_detail_page_loading'),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _PhotoErrorView extends StatelessWidget {
  const _PhotoErrorView({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        key: const Key('photo_detail_page_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                '$error',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoNotFoundView extends StatelessWidget {
  const _PhotoNotFoundView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        key: Key('photo_detail_page_not_found'),
        child: Text(
          '照片不存在',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
