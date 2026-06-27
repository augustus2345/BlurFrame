import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/frame_template.dart';

/// Raised by [FrameRenderer.render] when the input bytes can't be decoded
/// into an image, or when the compositor itself fails.
///
/// Catch this in the UI to show "渲染失败 / 重试" — see M2-T6 / M6-T5.
class FrameRenderException implements Exception {
  const FrameRenderException(this.message);

  final String message;

  @override
  String toString() => 'FrameRenderException: $message';
}

/// Composites a source photo with a [FrameTemplate] into a framed image.
///
/// **Pipeline** (all inside a single `compute` isolate):
/// 1. `image.decodeImage(bytes)` — synchronous decode; null → [FrameRenderException].
/// 2. For each [FrameLayer] in the template (in list order = z-order, bottom
///    to top), apply the layer-specific compositor:
///    - [BlurBorderLayer] → gaussian-blur the source, optionally composite
///      the sharp original back over the blurred center for `edge == true`.
///    - [TextWatermarkLayer] → rasterize text using a built-in bitmap font
///      (`arial14/24/48`); chars outside the font's character set are
///      silently skipped by the underlying `drawString`.
///    - [ColorStripeLayer] → `fillRect` along the top/bottom edge with a
///      solid ARGB color and optional corner radius.
/// 3. `encodeJpg(quality: 90)` and return the bytes.
///
/// **Why isolate**: `gaussianBlur` is O(W·H·radius²); large photos (4032×3024)
/// at intensity 10 can take >500 ms on the main isolate. `compute` keeps the
/// UI responsive during M5 batch rendering (concurrent 2 — see M5-T1).
class FrameRenderer {
  /// Prevent instantiation — all entry points are static.
  const FrameRenderer._();

  /// Render [template] on top of [sourceBytes], returning JPEG bytes.
  ///
  /// Throws [FrameRenderException] if [sourceBytes] is empty or cannot be
  /// decoded as an image (PNG/JPEG/etc). The compositor itself is total:
  /// any combination of layers (including empty) is supported.
  static Future<Uint8List> render(
    Uint8List sourceBytes,
    FrameTemplate template,
  ) async {
    if (sourceBytes.isEmpty) {
      throw const FrameRenderException('source bytes are empty');
    }
    return compute(_renderIsolate, _RenderJob(sourceBytes, template));
  }
}

/// Input payload for [_renderIsolate]. A named record keeps the call site
/// readable while satisfying `compute`'s "one argument" requirement.
///
/// FrameTemplate + Uint8List are transfer-safe: HiveObject holds only
/// primitive fields (List<FrameLayer> where FrameLayer is a sealed class
/// of plain data classes), no closures or non-transferable references.
@immutable
class _RenderJob {
  const _RenderJob(this.sourceBytes, this.template);

  final Uint8List sourceBytes;
  final FrameTemplate template;
}

/// Top-level isolate entry point. Synchronous: must return a single value.
///
/// Splitting decode / composite / encode into this single top-level
/// function (rather than chaining multiple `compute` calls) avoids
/// repeated isolate spawn overhead — important for M5 batch rendering.
Uint8List _renderIsolate(_RenderJob job) {
  final source = img.decodeImage(job.sourceBytes);
  if (source == null) {
    throw const FrameRenderException(
      'failed to decode source bytes as image',
    );
  }

  // Layers are stored in z-order (bottom → top). Each layer composites
  // onto the current work image in turn.
  img.Image work = source;
  for (final layer in job.template.layers) {
    work = _compositeLayer(work, layer);
  }

  return Uint8List.fromList(img.encodeJpg(work, quality: 90));
}

/// Dispatch to the per-type compositor. Sealed-class switch ensures the
/// analyzer flags a missing case if a new [FrameLayer] subclass is added.
img.Image _compositeLayer(img.Image work, FrameLayer layer) {
  return switch (layer) {
    final BlurBorderLayer l => _compositeBlurBorder(work, l),
    final TextWatermarkLayer l => _compositeTextWatermark(work, l),
    final ColorStripeLayer l => _compositeColorStripe(work, l),
  };
}

// ─── BlurBorderLayer ─────────────────────────────────────────────────

/// Apply a gaussian blur to the image. For `edge == true`, the blurred
/// image's outer ring is preserved while the original sharp pixels are
/// composited back over the center.
///
/// `intensity` (0–10 in the editor's slider) maps linearly to a blur
/// `radius` of `intensity × 3` pixels. intensity 0 → no-op (early return).
img.Image _compositeBlurBorder(img.Image source, BlurBorderLayer layer) {
  // Editor's slider clamps intensity to 0–10; allow up to 16 for direct
  // construction (e.g. tests) but cap the actual radius.
  final radius = (layer.intensity * 3).round().clamp(0, 48);
  if (radius == 0) return source;

  // `gaussianBlur` returns the **same** Image instance (modified in place),
  // not a fresh copy — see CLAUDE.md §7.15. Snapshot the original first so
  // we can still composite the sharp pixels back over the center for the
  // `edge == true` case.
  final sharp = source.clone();
  final blurred = img.gaussianBlur(source, radius: radius);

  if (!layer.edge) {
    // Full-image blur — drop the sharp copy entirely.
    return blurred;
  }

  // Edge-only blur: keep the inner region sharp. `radius` is also the
  // width (in pixels) of the blurred ring on each side.
  final innerLeft = radius;
  final innerTop = radius;
  final innerRight = sharp.width - radius;
  final innerBottom = sharp.height - radius;

  // Defensive: tiny images where the ring would cover everything → just
  // return the blurred image rather than skipping the layer.
  if (innerLeft >= innerRight || innerTop >= innerBottom) {
    return blurred;
  }

  return img.compositeImage(
    blurred, // dst (modified)
    sharp, // src (read-only)
    srcX: innerLeft,
    srcY: innerTop,
    srcW: innerRight - innerLeft,
    srcH: innerBottom - innerTop,
    dstX: innerLeft,
    dstY: innerTop,
    dstW: innerRight - innerLeft,
    dstH: innerBottom - innerTop,
    blend: img.BlendMode.direct, // overwrite pixels (no alpha math needed)
  );
}

// ─── TextWatermarkLayer ──────────────────────────────────────────────

/// Draw a text watermark at one of the seven [WatermarkPosition] values.
///
/// **Font choice**: `image` 4.x only ships ASCII bitmap fonts (`arial_14`,
/// `arial_24`, `arial_48`). Non-ASCII characters are silently skipped by
/// the underlying `drawString` — they advance by `base ~/ 2` pixels but
/// render no glyphs. This is a known limitation tracked for M6 polish.
///
/// **Font size mapping**: the editor exposes fontSize 8–48, but `image`'s
/// built-in fonts are fixed at 14/24/48. We pick the nearest match. To
/// support arbitrary sizes we'd need to bundle a TTF and rasterize via
/// a separate path — out of scope for M2-T5.
img.Image _compositeTextWatermark(img.Image source, TextWatermarkLayer layer) {
  final font = _pickFont(layer.fontSize);
  final (x, y) = _watermarkAnchor(
    source.width,
    source.height,
    layer.position,
    font,
    layer.text,
  );
  img.drawString(
    source,
    layer.text,
    font: font,
    x: x,
    y: y,
    color: _argbToColor(layer.color),
  );
  return source;
}

/// Pick the bitmap font whose built-in size is closest to [fontSize].
img.BitmapFont _pickFont(double fontSize) {
  if (fontSize <= 18) return img.arial14;
  if (fontSize <= 32) return img.arial24;
  return img.arial48;
}

/// Compute the top-left (x, y) anchor for a watermark at [position].
///
/// Returns the literal pixel coordinates to pass to `drawString`. Padding
/// from the image edge is `max(4, font.base ~/ 2)` so the text doesn't
/// touch the border.
(int, int) _watermarkAnchor(
  int imageW,
  int imageH,
  WatermarkPosition position,
  img.BitmapFont font,
  String text,
) {
  // Approximate text bounds (true width requires per-char advance calc).
  // Use font.base × char count as a conservative estimate.
  final textW = font.base * text.length;
  final textH = font.base;
  final padding = (font.base / 2).clamp(4, 24).toInt();

  switch (position) {
    case WatermarkPosition.topLeft:
      return (padding, padding);
    case WatermarkPosition.topCenter:
      return ((imageW - textW) ~/ 2, padding);
    case WatermarkPosition.topRight:
      return (imageW - textW - padding, padding);
    case WatermarkPosition.center:
      return ((imageW - textW) ~/ 2, (imageH - textH) ~/ 2);
    case WatermarkPosition.bottomLeft:
      return (padding, imageH - textH - padding);
    case WatermarkPosition.bottomCenter:
      return ((imageW - textW) ~/ 2, imageH - textH - padding);
    case WatermarkPosition.bottomRight:
      return (imageW - textW - padding, imageH - textH - padding);
  }
}

// ─── ColorStripeLayer ────────────────────────────────────────────────

/// Paint a solid-color bar along the top or bottom edge.
///
/// [ColorStripeLayer.width] is a relative ratio (0–1) of the image height —
/// the editor slider's 0.02–0.30 range maps directly. `cornerRadius` is
/// in pixels and applied via `fillRect`'s built-in `radius` parameter
/// (which renders the rectangle as a rounded rect internally).
img.Image _compositeColorStripe(img.Image source, ColorStripeLayer layer) {
  final h = source.height;
  final thickness = (h * layer.width.clamp(0.0, 1.0)).round();
  if (thickness <= 0) return source;

  const x1 = 0;
  final y1 = layer.position == StripePosition.top ? 0 : h - thickness;
  final x2 = source.width;
  final y2 = layer.position == StripePosition.top ? thickness : h;
  final radius = layer.cornerRadius.round().clamp(0, thickness);

  img.fillRect(
    source,
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    color: _argbToColor(layer.color),
    radius: radius,
  );
  return source;
}

// ─── Color helper ───────────────────────────────────────────────────

/// Convert an ARGB integer (e.g. `0xCCFFFFFF`) into the [img.Color]
/// subclass that `drawString` / `fillRect` accept.
///
/// `image` 4.x uses `ColorRgb8` for opaque colors and `ColorRgba8` for
/// colors with non-255 alpha. We branch on alpha so translucent stripes
/// and watermarks actually blend, rather than being drawn at full opacity.
img.Color _argbToColor(int argb) {
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  if (a == 0xFF) {
    return img.ColorRgb8(r, g, b);
  }
  return img.ColorRgba8(r, g, b, a);
}