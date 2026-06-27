import 'package:flutter/material.dart';

import '../../data/models/frame_template.dart';

/// 模版预览图（无 photo 字节的"抽象版"）。
///
/// 在模版 tab 列表里，每张卡片都要展示"模板长啥样"，但拿不到真实照片。
/// 这里用 [CustomPainter] 画一个 **结构化缩略**：
/// - 中间一块渐变灰底模拟照片
/// - 各种 [FrameLayer] 按 z-order 叠加：
///   - [BlurBorderLayer] — 模糊边框（用半透明高斯近似：边缘软阴影）
///   - [TextWatermarkLayer] — 文字水印（指定位置）
///   - [ColorStripeLayer] — 颜色条（顶/底/带圆角）
///
/// 这个 widget 的目标不是"看效果"（那是 M2-T5 渲染器的活），而是让用户
/// 在列表里 **一眼区分** 两种模板（"极简"窄边 vs "杂志"3 层 vs "自定义带条"）。
class FramePreview extends StatelessWidget {
  const FramePreview({
    required this.template,
    this.borderRadius = 8,
    super.key,
  });

  final FrameTemplate template;

  /// 外层圆角（与卡片 ClipRRect 对齐）。默认 8。
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _FramePreviewPainter(template: template),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _FramePreviewPainter extends CustomPainter {
  _FramePreviewPainter({required this.template});

  final FrameTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    // 1) 底色：模拟照片的渐变灰。
    final photoRect = Offset.zero & size;
    final photoPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB8B5AE), Color(0xFF7A7670)],
      ).createShader(photoRect);
    canvas.drawRect(photoRect, photoPaint);

    // 一条对角"光斑"提示这是张图（不是纯色块）。
    final highlight = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.2, 0)
      ..lineTo(size.width * 0.6, 0)
      ..lineTo(size.width * 0.1, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, highlight);

    // 2) 按 z-order 叠加 layers（layers 列表本身就是绘制顺序）。
    for (final layer in template.layers) {
      switch (layer) {
        case BlurBorderLayer():
          _paintBlurBorder(canvas, size, layer);
        case TextWatermarkLayer():
          _paintWatermark(canvas, size, layer);
        case ColorStripeLayer():
          _paintStripe(canvas, size, layer);
      }
    }
  }

  /// 模糊边框：用边缘软阴影近似 [intensity] 强度的模糊效果。
  ///
  /// 不能在 [CustomPainter] 里真做高斯模糊（要 ui.Image），所以用
  /// 半透明径向渐变 + 多层 stroke 模拟"边糊"的感觉。`intensity` 大 → 阴影
  /// 半径大 + 透明度高。
  void _paintBlurBorder(Canvas canvas, Size size, BlurBorderLayer layer) {
    if (layer.edge) {
      // 边缘模糊：四边各画一条从外缘到内 [intensity] px 的渐变条。
      final intensity = layer.intensity.clamp(1.0, 16.0);
      final ratio = (intensity / 16.0).clamp(0.0, 1.0);
      final edgeThickness = size.shortestSide * 0.18 * ratio;
      final edgeColor = Colors.black.withOpacity(0.35 * ratio);

      final topRect = Rect.fromLTWH(
        0,
        0,
        size.width,
        edgeThickness,
      );
      final bottomRect = Rect.fromLTWH(
        0,
        size.height - edgeThickness,
        size.width,
        edgeThickness,
      );
      final leftRect = Rect.fromLTWH(0, 0, edgeThickness, size.height);
      final rightRect = Rect.fromLTWH(
        size.width - edgeThickness,
        0,
        edgeThickness,
        size.height,
      );

      final edgePaint = Paint()..color = edgeColor;
      canvas.drawRect(topRect, edgePaint);
      canvas.drawRect(bottomRect, edgePaint);
      canvas.drawRect(leftRect, edgePaint);
      canvas.drawRect(rightRect, edgePaint);
    } else {
      // 全图模糊：整张盖一层低透明度灰雾。
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withOpacity(0.35),
      );
    }
  }

  /// 文字水印：根据 [position] 摆放 + 字号按预览 size 缩放。
  void _paintWatermark(
    Canvas canvas,
    Size size,
    TextWatermarkLayer layer,
  ) {
    // preview 缩放：原图 1080×1080 大致映射到这里 200×200，缩 5x。
    // 字号保留两位有效数字就行，不强求精确。
    final scaleFactor = size.shortestSide / 200.0;
    final fontSize = (layer.fontSize * scaleFactor).clamp(6.0, 28.0);
    final textColor = Color(layer.color);

    final textPainter = TextPainter(
      text: TextSpan(
        text: layer.text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          shadows: const [
            Shadow(
              color: Colors.black54,
              offset: Offset(0.5, 0.5),
              blurRadius: 1,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width * 0.9);

    final padding = size.shortestSide * 0.04;
    final offset = _positionOffset(
      layer.position,
      size,
      textPainter.size,
      padding,
    );
    textPainter.paint(canvas, offset);
  }

  /// 颜色条：顶/底对齐 + 圆角。
  void _paintStripe(
    Canvas canvas,
    Size size,
    ColorStripeLayer layer,
  ) {
    final thickness = size.height * layer.width.clamp(0.02, 0.5);
    final rect = layer.position == StripePosition.top
        ? Rect.fromLTWH(0, 0, size.width, thickness)
        : Rect.fromLTWH(
            0,
            size.height - thickness,
            size.width,
            thickness,
          );

    final paint = Paint()..color = Color(layer.color);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(
        (layer.cornerRadius.clamp(0.0, 1.0)) * thickness * 0.5,
      ),
    );
    canvas.drawRRect(rrect, paint);
  }

  /// 根据 9 宫格位置算水印左上角 offset。
  Offset _positionOffset(
    WatermarkPosition position,
    Size canvasSize,
    Size textSize,
    double padding,
  ) {
    final w = canvasSize.width;
    final h = canvasSize.height;
    final tw = textSize.width;
    final th = textSize.height;
    switch (position) {
      case WatermarkPosition.topLeft:
        return Offset(padding, padding);
      case WatermarkPosition.topCenter:
        return Offset((w - tw) / 2, padding);
      case WatermarkPosition.topRight:
        return Offset(w - tw - padding, padding);
      case WatermarkPosition.center:
        return Offset((w - tw) / 2, (h - th) / 2);
      case WatermarkPosition.bottomLeft:
        return Offset(padding, h - th - padding);
      case WatermarkPosition.bottomCenter:
        return Offset((w - tw) / 2, h - th - padding);
      case WatermarkPosition.bottomRight:
        return Offset(w - tw - padding, h - th - padding);
    }
  }

  @override
  bool shouldRepaint(_FramePreviewPainter oldDelegate) {
    return oldDelegate.template != template;
  }
}
