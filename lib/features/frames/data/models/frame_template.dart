/// A user-defined frame template. Built from a list of "layers" that the
/// renderer composites on top of the source photo.
class FrameTemplate {
  const FrameTemplate({
    required this.id,
    required this.name,
    required this.layers,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final List<FrameLayer> layers;
  final bool isBuiltIn;
}

/// One composable step in a frame. Renderers consume these in order.
sealed class FrameLayer {
  const FrameLayer();
}

class BorderLayer extends FrameLayer {
  const BorderLayer({required this.color, required this.width, this.cornerRadius = 0});
  final int color; // ARGB
  final double width;
  final double cornerRadius;
}

class WatermarkLayer extends FrameLayer {
  const WatermarkLayer({
    required this.text,
    required this.position,
    this.fontSize = 14,
    this.color = 0xFFFFFFFF,
  });
  final String text;
  final WatermarkPosition position;
  final double fontSize;
  final int color;
}

class BlurLayer extends FrameLayer {
  const BlurLayer({required this.intensity, this.edge = true});
  final double intensity;
  final bool edge; // true: blur the outer ring, false: full-image blur
}

class ExifBadgeLayer extends FrameLayer {
  const ExifBadgeLayer({required this.fields, required this.position});
  final List<String> fields; // e.g. ['camera', 'lens', 'iso', 'aperture']
  final WatermarkPosition position;
}

enum WatermarkPosition { topLeft, topRight, bottomLeft, bottomRight, center }