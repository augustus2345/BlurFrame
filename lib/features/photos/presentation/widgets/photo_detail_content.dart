import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/photo_model.dart';
import '../providers/exif_datasource_provider.dart';
import 'exif_panel.dart';
import 'photo_viewer.dart';
import 'star_rating.dart';
import 'tag_pills.dart';

/// 详情页完整内容区域 — 包含大图 + EXIF 字段表 + 标签 + 底部操作按钮。
///
/// 布局（从上到下）：
/// ```
/// Column
///   ├── Expanded → PhotoViewer（大图 + 双指缩放）
///   ├── ExifPanel（EXIF 字段表，可滚动）
///   ├── TagPills（标签展示）
///   └── BottomButtons（分享 / 应用模版）
/// ```
///
/// M1-T8 实现要点：
/// - EXIF 通过 [exifByIdProvider] 实时加载
/// - 标签直接读 [PhotoModel.tags]
/// - 分享 / 应用模版暂为占位 SnackBar
class PhotoDetailContent extends ConsumerWidget {
  const PhotoDetailContent({
    required this.photo,
    required this.imageBytes,
    this.onShare,
    this.onApplyTemplate,
    this.onStarChanged,
    super.key,
  });

  final PhotoModel photo;
  final Uint8List imageBytes;
  final VoidCallback? onShare;
  final VoidCallback? onApplyTemplate;
  final ValueChanged<int>? onStarChanged;

  double _computeAspectRatio() {
    final width = photo.width;
    final height = photo.height;
    if (width == null || height == null || height == 0) {
      return 1.0;
    }
    return width / height;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncExif = ref.watch(exifByIdProvider(photo.id));

    return Column(
      children: [
        // 顶部大图（可缩放）
        Expanded(
          child: PhotoViewer(
            imageBytes: imageBytes,
            aspectRatio: _computeAspectRatio(),
          ),
        ),

        // EXIF 字段表
        asyncExif.when(
          loading: () => const SizedBox(
            height: 60,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (exif) => exif.isEmpty
              ? const SizedBox.shrink()
              : ExifPanel(exif: exif),
        ),

        // 标签 pills
        TagPills(photo: photo),

        // 星级评分
        if (onStarChanged != null)
          StarRating(
            starRating: photo.starRating,
            onChanged: onStarChanged!,
          ),

        // 底部操作按钮
        _DetailBottomButtons(
          onShare: onShare,
          onApplyTemplate: onApplyTemplate,
        ),
      ],
    );
  }
}

/// 详情页底部操作按钮 — 分享 / 应用模版。
class _DetailBottomButtons extends StatelessWidget {
  const _DetailBottomButtons({
    this.onShare,
    this.onApplyTemplate,
  });

  final VoidCallback? onShare;
  final VoidCallback? onApplyTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('photo_detail_share_button'),
              onPressed: onShare ?? () => _showPlaceholder(context, '分享功能即将推出'),
              icon: const Icon(Icons.share_outlined),
              label: const Text('分享'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              key: const Key('photo_detail_apply_template_button'),
              onPressed: onApplyTemplate ?? () => _showPlaceholder(context, '模版功能即将推出'),
              icon: const Icon(Icons.filter_frames_outlined),
              label: const Text('应用模版'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}