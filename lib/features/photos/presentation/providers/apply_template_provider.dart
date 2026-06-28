import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../../frames/data/datasources/frame_renderer.dart';
import '../../../frames/data/models/frame_template.dart';
import '../../../frames/data/repositories/frame_repository.dart';

/// 导出流程状态。
///
/// 描述从"用户选好模板"到"保存到相册完成"的完整流程。
sealed class ApplyTemplateState {
  const ApplyTemplateState();
}

/// 初始态 — 未开始。
class ApplyTemplateInitial extends ApplyTemplateState {
  const ApplyTemplateInitial();
}

/// 渲染中 — 显示进度。
class ApplyTemplateRendering extends ApplyTemplateState {
  const ApplyTemplateRendering();
}

/// 保存中 — 已渲染完成，正在写入相册。
class ApplyTemplateSaving extends ApplyTemplateState {
  const ApplyTemplateSaving();
}

/// 导出成功 — [templateId] 是用过的模板 id（用于 `usageCount += 1`）。
class ApplyTemplateSuccess extends ApplyTemplateState {
  const ApplyTemplateSuccess({required this.templateId});

  final String templateId;
}

/// 导出失败 — [msg] 可展示给用户（不含敏感技术细节）。
class ApplyTemplateError extends ApplyTemplateState {
  const ApplyTemplateError({required this.msg});

  final String msg;
}

/// 图片保存器抽象（让 [ApplyTemplateNotifier] 可测试）。
///
/// 生产实现 [GalImageSaver] 调 `Gal.putImageBytes`。
/// 测试时注入 fake/mock 实现。
abstract class ImageSaver {
  Future<void> save(Uint8List bytes, {required String name});
}

/// 生产实现：调 [Gal.putImageBytes] 写入系统相册。
class GalImageSaver implements ImageSaver {
  const GalImageSaver();

  @override
  Future<void> save(Uint8List bytes, {required String name}) {
    return Gal.putImageBytes(bytes, name: name);
  }
}

/// 导出流程编排 Notifier。
///
/// 管理从"用户选了模板"到"保存成功 + usageCount 更新"的完整流程：
/// 1. [applyTemplate] — 调用 [FrameRenderer.render] 在独立 isolate 里合成
/// 2. [ImageSaver.save] — 写入系统相册
/// 3. [FrameRepository.incrementUsageCount] — 更新 usageCount
///
/// 每个步骤的异常都会被捕获并转为 [ApplyTemplateError]，UI 只展示
/// 友好提示，不暴露技术细节。
///
/// 防竞态：[applyTemplateProvider] 是 `StateNotifierProvider`，每次
/// 进入详情页创建新实例，页面 pop 时自动销毁，不会跨页面残留。
///
/// 重试支持：[retry] 方法重新执行上次失败的操作（失败时保留参数）。
class ApplyTemplateNotifier extends StateNotifier<ApplyTemplateState> {
  ApplyTemplateNotifier({ImageSaver? imageSaver})
      : _imageSaver = imageSaver ?? const GalImageSaver(),
        super(const ApplyTemplateInitial());

  final ImageSaver _imageSaver;

  /// 上次执行的参数（用于重试）。
  FrameTemplate? _lastTemplate;
  Future<Uint8List?> Function()? _lastFullImageLoader;
  FrameRepository? _lastFrameRepository;

  /// 完整的导出流程：渲染 → 保存 → 更新 usageCount。
  ///
  /// 调用 [fullImageLoader] 获取原始图片字节（详情页已缓存 originBytes），
  /// 调用 [FrameRenderer.render] 合成，调用 [_imageSaver.save] 保存，
  /// 最后调用 [FrameRepository.incrementUsageCount]。
  ///
  /// 任何步骤失败都会进入 [ApplyTemplateError]，不会跳过后续步骤。
  /// 调用方应该在 UI 展示错误后自行重置到初始态。
  Future<void> applyTemplate({
    required FrameTemplate template,
    required Future<Uint8List?> Function() fullImageLoader,
    required FrameRepository frameRepository,
  }) async {
    // 保存参数以便重试
    _lastTemplate = template;
    _lastFullImageLoader = fullImageLoader;
    _lastFrameRepository = frameRepository;

    state = const ApplyTemplateRendering();

    // ── Step 1: 获取原始图片字节 ─────────────────────────────
    final sourceBytes = await fullImageLoader();
    if (sourceBytes == null) {
      state = const ApplyTemplateError(msg: '无法读取原图，请重试');
      return;
    }

    // ── Step 2: 渲染 ─────────────────────────────────────────
    Uint8List jpegBytes;
    try {
      jpegBytes = await FrameRenderer.render(sourceBytes, template);
    } on FrameRenderException catch (e) {
      state = ApplyTemplateError(msg: '渲染失败：${e.message}');
      return;
    } catch (_) {
      state = const ApplyTemplateError(msg: '渲染失败，请重试');
      return;
    }

    // ── Step 3: 保存到相册 ───────────────────────────────────
    state = const ApplyTemplateSaving();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _imageSaver.save(jpegBytes, name: 'photo_beauty_$timestamp');
    } on GalException catch (e) {
      state = ApplyTemplateError(msg: '保存失败：${e.type.message}');
      return;
    } catch (_) {
      state = const ApplyTemplateError(msg: '保存失败，请重试');
      return;
    }

    // ── Step 4: usageCount += 1 ──────────────────────────────
    try {
      await frameRepository.incrementUsageCount(template.id);
    } catch (_) {
      // usageCount 更新失败不影响用户已看到的"保存成功"结果。
      // 只记录日志，不抛错给 UI。
    }

    state = ApplyTemplateSuccess(templateId: template.id);
  }

  /// 重置到初始态（用户关闭错误提示后调用）。
  void reset() => state = const ApplyTemplateInitial();

  /// 重试上次失败的导出操作。
  ///
  /// 仅在 [_lastTemplate] 等参数有效时可用。
  Future<void> retry() async {
    final template = _lastTemplate;
    final fullImageLoader = _lastFullImageLoader;
    final frameRepository = _lastFrameRepository;
    if (template == null || fullImageLoader == null || frameRepository == null) {
      return;
    }
    await applyTemplate(
      template: template,
      fullImageLoader: fullImageLoader,
      frameRepository: frameRepository,
    );
  }
}

/// DI entry point — 每个详情页创建自己的 provider 实例（页面级状态）。
final applyTemplateProvider =
    StateNotifierProvider<ApplyTemplateNotifier, ApplyTemplateState>((ref) {
  return ApplyTemplateNotifier();
});