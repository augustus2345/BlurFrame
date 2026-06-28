import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../../frames/data/datasources/frame_renderer.dart';
import '../../../frames/data/models/frame_template.dart';
import '../../../frames/data/repositories/frame_repository.dart';
import '../widgets/image_saver.dart';

/// 批量套模版状态.
///
/// 描述从"用户选了模板"到"批量保存完成"的完整流程.
/// 包含进度跟踪（current/total）和结果统计（success/failure）。
sealed class BatchApplyTemplateState {
  const BatchApplyTemplateState();
}

/// 初始态 — 未开始.
class BatchApplyTemplateInitial extends BatchApplyTemplateState {
  const BatchApplyTemplateInitial();
}

/// 进行中 — [current] 当前处理到第几张，[total] 总数，[templateName] 模板名.
class BatchApplyTemplateProcessing extends BatchApplyTemplateState {
  const BatchApplyTemplateProcessing({
    required this.current,
    required this.total,
    required this.templateName,
    this.successCount = 0,
    this.failureCount = 0,
  });

  final int current;
  final int total;
  final String templateName;
  final int successCount;
  final int failureCount;

  double get progress => total > 0 ? current / total : 0;
}

/// 完成 — [successCount] 成功数，[failureCount] 失败数.
class BatchApplyTemplateDone extends BatchApplyTemplateState {
  const BatchApplyTemplateDone({
    required this.successCount,
    required this.failureCount,
    required this.templateName,
  });

  final int successCount;
  final int failureCount;
  final String templateName;
}

/// 错误态 — 批量处理中途遇到无法恢复的错误（而非部分失败）。
class BatchApplyTemplateError extends BatchApplyTemplateState {
  const BatchApplyTemplateError({required this.message});

  final String message;
}

/// 批量套模版编排 Notifier.
///
/// 管理批量渲染流程：
/// 1. 并发控制：最多同时渲染 2 张（防止 OOM）
/// 2. 进度跟踪：每批完成后更新进度
/// 3. 结果统计：成功/失败计数
/// 4. 重试支持：失败时保留上次参数，支持重新执行
class BatchApplyTemplateNotifier extends StateNotifier<BatchApplyTemplateState> {
  BatchApplyTemplateNotifier({ImageSaver? imageSaver})
      : _imageSaver = imageSaver ?? const GalImageSaver(),
        super(const BatchApplyTemplateInitial());

  final ImageSaver _imageSaver;

  /// 上次执行的参数（用于重试）。
  FrameTemplate? _lastTemplate;
  Map<String, Future<Uint8List?> Function()> _lastPhotoLoaders = {};
  FrameRepository? _lastFrameRepository;

  /// 批量套模版流程.
  ///
  /// [template] 选中的模板
  /// [photoLoaders] Map<photoId, 获取原始图片字节的函数>
  /// [frameRepository] 用于更新 usageCount
  Future<void> applyTemplateBatch({
    required FrameTemplate template,
    required Map<String, Future<Uint8List?> Function()> photoLoaders,
    required FrameRepository frameRepository,
  }) async {
    // 保存参数以便重试
    _lastTemplate = template;
    _lastPhotoLoaders = photoLoaders;
    _lastFrameRepository = frameRepository;

    final total = photoLoaders.length;
    if (total == 0) return;

    int successCount = 0;
    int failureCount = 0;

    // 并发控制：最多同时渲染 2 张
    final entries = photoLoaders.entries.toList();
    int index = 0;

    while (index < total) {
      // 启动一批（最多 2 个）
      final batch = <Future<bool>>[];
      while (batch.length < 2 && index < total) {
        final entry = entries[index];
        index++;
        batch.add(_processPhoto(
          photoId: entry.key,
          fullImageLoader: entry.value,
          template: template,
        ),);
      }

      // 等待这批全部完成
      final results = await Future.wait(batch);

      // 统计结果
      for (final success in results) {
        if (success) {
          successCount++;
        } else {
          failureCount++;
        }
      }

      // 更新进度状态
      state = BatchApplyTemplateProcessing(
        current: index,
        total: total,
        templateName: template.name,
        successCount: successCount,
        failureCount: failureCount,
      );
    }

    // 最终更新 usageCount
    if (successCount > 0) {
      try {
        await frameRepository.incrementUsageCount(template.id);
      } catch (_) {
        // usageCount 更新失败不影响结果
      }
    }

    state = BatchApplyTemplateDone(
      successCount: successCount,
      failureCount: failureCount,
      templateName: template.name,
    );
  }

  /// 处理单张照片：加载 → 渲染 → 保存.
  Future<bool> _processPhoto({
    required String photoId,
    required Future<Uint8List?> Function() fullImageLoader,
    required FrameTemplate template,
  }) async {
    try {
      // Step 1: 获取原始图片字节
      final sourceBytes = await fullImageLoader();
      if (sourceBytes == null) return false;

      // Step 2: 渲染
      Uint8List jpegBytes;
      try {
        jpegBytes = await FrameRenderer.render(sourceBytes, template);
      } on FrameRenderException {
        return false;
      } catch (_) {
        return false;
      }

      // Step 3: 保存到相册
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await _imageSaver.save(jpegBytes, name: 'photo_beauty_$timestamp');
      } on GalException {
        return false;
      } catch (_) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 重置到初始态.
  void reset() => state = const BatchApplyTemplateInitial();

  /// 重试上次失败的批量操作.
  ///
  /// 仅在 [_lastTemplate] 等参数有效时可用。
  Future<void> retry() async {
    final template = _lastTemplate;
    final photoLoaders = _lastPhotoLoaders;
    final frameRepository = _lastFrameRepository;
    if (template == null || frameRepository == null || photoLoaders.isEmpty) {
      return;
    }
    // 重置后重新执行
    state = const BatchApplyTemplateInitial();
    await applyTemplateBatch(
      template: template,
      photoLoaders: photoLoaders,
      frameRepository: frameRepository,
    );
  }
}

/// DI entry point.
final batchApplyTemplateProvider =
    StateNotifierProvider<BatchApplyTemplateNotifier, BatchApplyTemplateState>((ref) {
  return BatchApplyTemplateNotifier();
});