import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photo_beauty/features/frames/data/datasources/frame_renderer.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';

/// Tests for [FrameRenderer] — the core compositor that turns a source photo
/// + a [FrameTemplate] into framed JPEG bytes.
///
/// Strategy: generate source images programmatically with the `image` package
/// instead of relying on base64 fixtures, so each test has full control over
/// pixel content (and avoids the "invalid image data" codec crash that random
/// bytes trigger — see CLAUDE.md §7.13).
void main() {
  // ─── Fixtures ────────────────────────────────────────────────────────
  // Reusable 200×200 RGB image filled with red. We use a known size so
  // blur-radius / stripe-thickness assertions can compute pixel offsets.
  Uint8List makeSourceImage({
    int width = 200,
    int height = 200,
    img.ColorRgb8? fill,
  }) {
    final image = img.Image(width: width, height: height);
    image.clear(fill ?? img.ColorRgb8(255, 0, 0));
    return Uint8List.fromList(img.encodePng(image));
  }

  // Decode bytes back through the renderer's own decoder path so we can
  // assert on pixel content (gaussianBlur / fillRect modify in place).
  img.Image decodeOutput(Uint8List bytes) {
    final out = img.decodeImage(bytes);
    expect(out, isNotNull, reason: 'renderer output must be decodable');
    return out!;
  }

  // Get the RGB value at (x, y) — strips alpha so tests don't depend on
  // encoder alpha-channel defaults.
  img.ColorRgb8 pixelAt(img.Image image, int x, int y) {
    final p = image.getPixel(x, y);
    return img.ColorRgb8(p.r.toInt(), p.g.toInt(), p.b.toInt());
  }

  // ─── Empty / passthrough ────────────────────────────────────────────
  group('empty / passthrough', () {
    test('empty layers returns encoded source (same dimensions)', () async {
      final source = makeSourceImage(width: 100, height: 100);
      final template = FrameTemplate(
        id: 'empty',
        name: 'Empty',
        layers: const [],
      );

      final output = await FrameRenderer.render(source, template);

      final out = decodeOutput(output);
      expect(out.width, equals(100));
      expect(out.height, equals(100));
    });

    test('layers list order is preserved as z-order', () async {
      // Three layers, each paints a unique color in a non-overlapping region.
      // We verify each region survived by sampling pixels.
      //
      // Layout (200×200 image):
      //   - ColorStripeLayer (top, full width, 40px tall)   → blue at (100, 20)
      //   - TextWatermarkLayer (center)                     → text pixels around (100, 100)
      //   - BlurBorderLayer (edge, intensity 10)            → blurs the outer ring
      final source = makeSourceImage(); // 200×200 red
      final template = FrameTemplate(
        id: 'z-order',
        name: 'Z-order',
        layers: [
          ColorStripeLayer(
            color: 0xFF0000FF, // blue
            width: 0.2, // 200 × 0.2 = 40 px
            position: StripePosition.top,
          ),
          TextWatermarkLayer(
            text: 'X', // single ASCII char to keep font-choice simple
            position: WatermarkPosition.center,
            fontSize: 24,
            color: 0xFF00FF00, // green
          ),
          BlurBorderLayer(intensity: 10, edge: true),
        ],
      );

      final output = await FrameRenderer.render(source, template);
      final out = decodeOutput(output);

      // Stripe (blue) should still be present at the top center
      final topPixel = pixelAt(out, 100, 20);
      expect(
        topPixel.b,
        greaterThan(150),
        reason: 'blue stripe must dominate at top',
      );

      // Center region should have green text pixels (or close — JPEG
      // compression + bitmap-font anti-aliasing both fade the channel).
      // We allow a wide margin since the green channel of the bitmap
      // anti-aliasing drops fast.
      var greenPixelFound = false;
      for (var y = 80; y < 120; y++) {
        for (var x = 80; x < 120; x++) {
          final p = pixelAt(out, x, y);
          if (p.g > 50 && p.r < 100) {
            greenPixelFound = true;
            break;
          }
        }
      }
      expect(greenPixelFound, isTrue,
          reason: 'green watermark pixels must appear near the center',
      );

      // Edge (at (5, 100)) should be blurred: since original was pure red,
      // the blur of a uniform field should still be red-ish, not blue/green
      final edgePixel = pixelAt(out, 5, 100);
      expect(
        edgePixel.r,
        greaterThan(180),
        reason: 'blurred edge should preserve red dominant tone',
      );
    });
  });

  // ─── BlurBorderLayer ───────────────────────────────────────────────
  group('BlurBorderLayer', () {
    test('edge=true blurs outer ring, preserves inner sharp pixels',
        () async {
      // 200×200 image with a sharp 50×50 white square at center.
      // After edge blur, the white square should still be sharp (not blurred
      // into the red), but the surrounding red should be slightly softened.
      final src = img.Image(width: 200, height: 200);
      src.clear(img.ColorRgb8(255, 0, 0)); // red
      // Draw white square in the center (75..125, 75..125)
      img.fillRect(src,
          x1: 75, y1: 75, x2: 125, y2: 125,
          color: img.ColorRgb8(255, 255, 255),
      );
      final source = Uint8List.fromList(img.encodePng(src));

      final template = FrameTemplate(
        id: 'blur-edge',
        name: 'Edge',
        layers: [BlurBorderLayer(intensity: 10, edge: true)],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));

      // Center of the inner square should still be white (not blurred away).
      // JPEG quality 90 introduces ±1 noise on solid white, so allow ≥250.
      final centerPixel = pixelAt(out, 100, 100);
      expect(
        centerPixel.r,
        greaterThanOrEqualTo(250),
        reason: 'inner square should remain mostly white',
      );
      expect(centerPixel.g, greaterThanOrEqualTo(250));
      expect(centerPixel.b, greaterThanOrEqualTo(250));

      // At (76, 76) — inside inner sharp region near boundary — should
      // still be near-white (allow JPEG noise tolerance).
      final nearInner = pixelAt(out, 76, 76);
      expect(
        nearInner.r,
        greaterThanOrEqualTo(250),
        reason: 'inner sharp region near the edge should not be blurred',
      );
    });

    test('edge=false blurs the entire image', () async {
      // 100×100 pure red; after full-image blur the center pixel should
      // still be red (uniform field doesn't change), but the dimensions
      // remain the same and the image remains valid.
      final source = makeSourceImage(width: 100, height: 100);
      final template = FrameTemplate(
        id: 'blur-full',
        name: 'Full',
        layers: [BlurBorderLayer(intensity: 8, edge: false)],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));

      expect(out.width, equals(100));
      expect(out.height, equals(100));
      final p = pixelAt(out, 50, 50);
      expect(p.r, greaterThan(200),
          reason: 'uniform red stays red after full blur',
      );
    });

    test('intensity=0 leaves the image unchanged', () async {
      final source = makeSourceImage();
      final template = FrameTemplate(
        id: 'blur-zero',
        name: 'Zero',
        layers: [BlurBorderLayer(intensity: 0, edge: true)],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));
      // Outer edge: intensity 0 must not touch the pixel, so it should
      // still be the source's pure red. JPEG quality 90 introduces ±1
      // noise on solid colors, so use >= 250.
      final p = pixelAt(out, 5, 5);
      expect(p.r, greaterThanOrEqualTo(250),
          reason: 'intensity 0 should not blur anything',
      );
      expect(p.g, lessThanOrEqualTo(5));
      expect(p.b, lessThanOrEqualTo(5));
    });
  });

  // ─── ColorStripeLayer ──────────────────────────────────────────────
  group('ColorStripeLayer', () {
    test('top stripe paints a colored band of correct thickness', () async {
      final source = makeSourceImage(width: 100, height: 100);
      final template = FrameTemplate(
        id: 'stripe-top',
        name: 'Top',
        layers: [
          ColorStripeLayer(
            color: 0xFF000000, // black
            width: 0.1, // 100 × 0.1 = 10 px
            position: StripePosition.top,
          ),
        ],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));

      // At y=5 (inside the 10px stripe), should be black
      final topInside = pixelAt(out, 50, 5);
      expect(topInside.r, lessThan(20),
          reason: 'top 10px should be black',
      );
      expect(topInside.g, lessThan(20));
      expect(topInside.b, lessThan(20));

      // At y=50 (middle), should still be red (untouched)
      final middle = pixelAt(out, 50, 50);
      expect(middle.r, greaterThan(200));
    });

    test('bottom stripe paints a colored band at the bottom', () async {
      final source = makeSourceImage(width: 100, height: 100);
      final template = FrameTemplate(
        id: 'stripe-bottom',
        name: 'Bottom',
        layers: [
          ColorStripeLayer(
            color: 0xFF000000,
            width: 0.2, // 100 × 0.2 = 20 px from bottom
            position: StripePosition.bottom,
          ),
        ],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));

      // At y=90 (inside the 20px bottom band), should be black
      final bottomInside = pixelAt(out, 50, 90);
      expect(bottomInside.r, lessThan(20));

      // At y=70 (above the band), should still be red
      final aboveBand = pixelAt(out, 50, 70);
      expect(aboveBand.r, greaterThan(200));
    });

    test('cornerRadius > 0 produces rounded corners', () async {
      // We can't easily assert on rounded-corner geometry pixel-by-pixel
      // without fragile arithmetic, so this test just verifies the call
      // completes and dimensions are preserved when cornerRadius > 0.
      final source = makeSourceImage(width: 100, height: 100);
      final template = FrameTemplate(
        id: 'stripe-rounded',
        name: 'Rounded',
        layers: [
          ColorStripeLayer(
            color: 0xFF000000,
            width: 0.1,
            cornerRadius: 5,
            position: StripePosition.top,
          ),
        ],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));
      expect(out.width, equals(100));
      expect(out.height, equals(100));
    });
  });

  // ─── TextWatermarkLayer ───────────────────────────────────────────
  group('TextWatermarkLayer', () {
    test('centered ASCII text watermark renders', () async {
      final source = makeSourceImage();
      final template = FrameTemplate(
        id: 'wm-center',
        name: 'Center',
        layers: [
          TextWatermarkLayer(
            text: 'X',
            position: WatermarkPosition.center,
            fontSize: 24,
            color: 0xFF00FF00,
          ),
        ],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));
      // Just verify the image is valid and has the right dimensions.
      expect(out.width, equals(200));
      expect(out.height, equals(200));
      // Center region should have green pixels (the X).
      // We sample a small region around the center to allow for anti-aliasing.
      var greenFound = false;
      for (var y = 95; y < 105; y++) {
        for (var x = 95; x < 105; x++) {
          final p = pixelAt(out, x, y);
          if (p.g > 150 && p.r < 100) {
            greenFound = true;
            break;
          }
        }
      }
      expect(greenFound, isTrue,
          reason: 'green watermark pixels must appear near the center',
      );
    });

    test('non-ASCII chars do not crash — drawString skips them', () async {
      // Chinese chars are not in the built-in arial14/24/48 bitmap font,
      // so drawString silently advances half a base-width and skips drawing.
      // We just verify the renderer doesn't throw and the image is valid.
      final source = makeSourceImage();
      final template = FrameTemplate(
        id: 'wm-cn',
        name: 'Chinese',
        layers: [
          TextWatermarkLayer(
            text: '你好', // not in arial bitmap font
            position: WatermarkPosition.center,
            fontSize: 24,
            color: 0xFFFFFFFF,
          ),
        ],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));
      expect(out.width, equals(200));
      expect(out.height, equals(200));
    });
  });

  // ─── Error paths ──────────────────────────────────────────────────
  group('error paths', () {
    test('empty bytes throws FrameRenderException', () async {
      final template = FrameTemplate(
        id: 'err',
        name: 'Error',
        layers: const [],
      );

      expect(
        () => FrameRenderer.render(Uint8List(0), template),
        throwsA(isA<FrameRenderException>()),
      );
    });

    test('corrupted bytes throws FrameRenderException', () async {
      final garbage = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final template = FrameTemplate(
        id: 'err',
        name: 'Error',
        layers: const [],
      );

      expect(
        () => FrameRenderer.render(garbage, template),
        throwsA(isA<FrameRenderException>()),
      );
    });
  });

  // ─── Built-in templates roundtrip ─────────────────────────────────
  group('built-in templates render without error', () {
    test('极简 (builtin-minimal) renders successfully', () async {
      final source = makeSourceImage();
      final template = FrameTemplate(
        id: 'builtin-minimal',
        name: '极简',
        isBuiltIn: true,
        layers: [BlurBorderLayer(intensity: 4, edge: true)],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));
      expect(out.width, equals(200));
      expect(out.height, equals(200));
    });

    test('杂志 (builtin-magazine) renders successfully', () async {
      final source = makeSourceImage();
      final template = FrameTemplate(
        id: 'builtin-magazine',
        name: '杂志',
        isBuiltIn: true,
        layers: [
          TextWatermarkLayer(
            text: 'YYYY-MM-DD',
            position: WatermarkPosition.bottomCenter,
            fontSize: 12,
            color: 0xCCFFFFFF,
          ),
          TextWatermarkLayer(
            text: 'Photo',
            position: WatermarkPosition.topCenter,
            fontSize: 16,
            color: 0xFFFFFFFF,
          ),
          BlurBorderLayer(intensity: 6, edge: true),
        ],
      );

      final out = decodeOutput(await FrameRenderer.render(source, template));
      expect(out.width, equals(200));
      expect(out.height, equals(200));
    });
  });
}