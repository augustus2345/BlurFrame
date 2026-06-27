import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../frames/data/models/frame_template.dart';
import '../../../frames/data/repositories/frame_repository.dart';
import '../../../tags/presentation/widgets/tag_picker_sheet.dart';
import '../../data/models/photo_model.dart';
import '../providers/apply_template_provider.dart';
import '../providers/full_image_loader_provider.dart';
import '../providers/photos_provider.dart';
import '../widgets/apply_template_sheet.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/photo_detail_page.dart';

/// 照片详情页路由目标 — `/photo/:assetId`（rootNavigator 上 push，全屏沉浸）。
///
/// M1-T8 完整结构：
/// ```
/// Scaffold (黑底)
/// ├── AppBar (back + 第 N / 共 M)
/// └── Column
///     ├── Expanded → PageView.builder
///     │   └── PhotoDetailPage
///     │       └── PhotoDetailContent
///     │           ├── PhotoViewer（大图 + 双指缩放）
///     │           ├── ExifPanel（EXIF 字段表）
///     │           ├── TagPills（标签展示）
///     │           └── _DetailBottomButtons（分享 / 应用模版）
///     └── BottomActionBar (5 项操作：删除/标签/星级/影集/模版)
/// ```
///
/// 删除流程（CLAUDE.md §2.5-20 防竞态）：
/// - 弹 AlertDialog 二次确认（由 [BottomActionBar] 负责）。
/// - 确认后调 `PhotoRepository.delete(id)` → `photosProvider.refresh()`。
/// - gallery 列表缩短 → PageView 自动 rebuild；空时 pop。
///
/// M2-T6 导出流程：
/// - [BottomActionBar] 模版按钮 / [_DetailBottomButtons] "应用模版"按钮
///   → [showApplyTemplateSheet] → 用户选模板 → [ApplyTemplateNotifier.applyTemplate]
///   → 渲染中（loading）→ 保存中（loading）→ 成功 snackbar + usageCount += 1
///   → 失败 snackbar + 重置状态。
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

  /// 显示模板选择器 sheet，用户选好后启动导出流程。
  Future<void> _showTemplateSheet(String assetId) async {
    final repo = ref.read(frameRepositoryProvider);
    final fullLoader = ref.read(fullImageLoaderProvider);

    await showApplyTemplateSheet(
      context: context,
      assetId: assetId,
      onSelected: (template) async {
        final notifier = ref.read(applyTemplateProvider.notifier);
        notifier.addListener(_onApplyStateChanged);

        await notifier.applyTemplate(
          template: template,
          fullImageLoader: () => fullLoader(assetId),
          frameRepository: repo,
        );
      },
    );
  }

  /// 监听导出状态变化，显示对应 snackbar。
  void _onApplyStateChanged(ApplyTemplateState state) {
    if (!mounted) return;

    switch (state) {
      case ApplyTemplateInitial():
        // no-op
        break;
      case ApplyTemplateRendering():
        _showProgressSnackbar('正在渲染…');
        break;
      case ApplyTemplateSaving():
        _showProgressSnackbar('正在保存到相册…');
        break;
      case ApplyTemplateSuccess():
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              key: Key('apply_template_success_snackbar'),
              content: Text('已保存到相册'),
              duration: Duration(seconds: 2),
            ),
          );
        // 重置状态
        ref.read(applyTemplateProvider.notifier).reset();
        break;
      case ApplyTemplateError(msg: final message):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('apply_template_error_snackbar'),
              content: Text(message),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '重试',
                onPressed: () {
                  // 重置后用户可以重新选择模板
                  ref.read(applyTemplateProvider.notifier).reset();
                },
              ),
            ),
          );
        break;
    }
  }

  void _showProgressSnackbar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('apply_template_progress_snackbar'),
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text(message),
            ],
          ),
          duration: const Duration(days: 1), // 一直显示直到手动 hide
        ),
      );
  }

  /// 显示 Lightroom 风格标签选择器 sheet，更新照片标签后刷新列表。
  Future<void> _handleTags(String photoId, Set<String> currentTagIds) async {
    await showTagPickerSheet(
      context: context,
      selectedTagIds: currentTagIds,
      onConfirm: (selectedTagIds) async {
        final repo = ref.read(photoRepositoryProvider);
        await repo.updateTags(photoId, selectedTagIds.toList());
        await ref.read(photosProvider.notifier).refresh();
      },
    );
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
                  onApplyTemplate: () => _showTemplateSheet(photo.id),
                );
              },
            ),
          ),
          BottomActionBar(
            photoId: currentPhoto.id,
            onDelete: _handleDelete,
            onApplyTemplate: () => _showTemplateSheet(currentPhoto.id),
            onTags: () => _handleTags(currentPhoto.id, currentPhoto.tags.toSet()),
          ),
        ],
      ),
    );
  }
}

/// 显示"应用模版"底部选择器 sheet 并在用户选好后触发 [onSelected]。
///
/// [assetId] 用于加载原始图片字节。
Future<void> showApplyTemplateSheet({
  required BuildContext context,
  required String assetId,
  required void Function(FrameTemplate template) onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ApplyTemplateSheet(
      onSelect: (template) {
        Navigator.of(sheetContext).pop();
        onSelected(template);
      },
    ),
  );
}