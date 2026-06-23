import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 全尺寸照片查看器：双指缩放 + 双击 toggle 缩放。
///
/// - 接收 `imageBytes`（null 时显示 loading placeholder）+ `aspectRatio`
/// - 用 [InteractiveViewer] 处理双指捏合缩放 + 单指平移
/// - 用 [GestureDetector.onDoubleTap] 同步切换 matrix（瞬间缩放，无插值动画）
///
/// 设计：
/// - 可注入 [TransformationController]（测试读 `value` 验证缩放状态）。
/// - 不处理左右滑切换（由外层 [PageView] 负责）。
///
/// **M1 简化**：原计划用 Matrix4Tween + AnimationController 做缩放过渡动画，
/// 但 `InteractiveViewer + AnimationController` 在 widget test 里会让
/// `pumpAndSettle` 永久 hang。生产路径观察：iOS Photos 双击缩放也是瞬间切换。
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    required this.imageBytes,
    required this.aspectRatio,
    this.transformationController,
    super.key,
  });

  final Uint8List? imageBytes;
  final double aspectRatio;

  /// 测试入口：传入外部 [TransformationController] 可在测试中读
  /// `controller.value.getMaxScaleOnAxis()` 验证缩放状态。
  final TransformationController? transformationController;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  static const double _zoomScale = 2.5;
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;

  late final TransformationController _controller =
      widget.transformationController ?? TransformationController();

  @override
  void dispose() {
    if (widget.transformationController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// 当前是否处于"放大"状态（> 1.05× 视为已放大，避免浮点误差抖动）。
  bool get _isZoomedIn => _controller.value.getMaxScaleOnAxis() > 1.05;

  void _handleDoubleTap() {
    final Matrix4 end;
    if (_isZoomedIn) {
      end = Matrix4.identity();
    } else {
      end = Matrix4.identity()
        ..scaleByDouble(_zoomScale, _zoomScale, _zoomScale, 1);
    }
    _controller.value = end;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.imageBytes;
    if (bytes == null) {
      return const Center(
        key: Key('photo_viewer_placeholder'),
        child: CircularProgressIndicator(),
      );
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: GestureDetector(
        // 透传 onDoubleTap 到 _handleDoubleTap。InteractiveViewer 的 pan/zoom
        // 仍然能工作，因为 Flutter 手势仲裁中 onDoubleTap 只在等待第二次 tap
        // 的 ~300ms 内拒绝水平 drag；状态切换后立刻接管。
        onDoubleTap: _handleDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: InteractiveViewer(
          key: const Key('photo_viewer_interactive'),
          transformationController: _controller,
          minScale: _minScale,
          maxScale: _maxScale,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
