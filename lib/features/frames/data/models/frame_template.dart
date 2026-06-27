import 'package:hive/hive.dart';

part 'frame_template.g.dart';

/// A user-defined frame template. Built from a list of "layers" that the
/// renderer composites on top of the source photo.
///
/// [usageCount] tracks how many times the user has applied this template;
/// it is persisted back to Hive alongside the template definition.
@HiveType(typeId: 2)
class FrameTemplate extends HiveObject {
  FrameTemplate({
    required this.id,
    required this.name,
    required this.layers,
    this.isBuiltIn = false,
    this.usageCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Persisted creation timestamp.
  @HiveField(5)
  final DateTime createdAt;

  /// Unique identifier. For built-in templates this matches the constant
  /// id used in [FrameRepository.builtInTemplates].
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// Ordered list of layers composited from bottom to top.
  @HiveField(2)
  final List<FrameLayer> layers;

  /// True for templates shipped with the app. Built-in templates are
  /// protected: they cannot be deleted or overwritten through the repo.
  @HiveField(3)
  final bool isBuiltIn;

  /// Number of times the user has applied this template.
  /// Incremented by [FrameRepository] after each successful export.
  @HiveField(4)
  int usageCount;

  /// Returns a mutable copy with an incremented [usageCount].
  FrameTemplate withIncrementedUsage() => FrameTemplate(
        id: id,
        name: name,
        layers: layers,
        isBuiltIn: isBuiltIn,
        usageCount: usageCount + 1,
        createdAt: createdAt,
      );

  /// Creates a copy with an optional new [usageCount] value.
  FrameTemplate copyWith({
    String? id,
    String? name,
    List<FrameLayer>? layers,
    bool? isBuiltIn,
    int? usageCount,
    DateTime? createdAt,
  }) =>
      FrameTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        layers: layers ?? this.layers,
        isBuiltIn: isBuiltIn ?? this.isBuiltIn,
        usageCount: usageCount ?? this.usageCount,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// One composable step in a frame. Renderers consume these in order.
sealed class FrameLayer {}

/// Blurred border around the outer ring of the photo.
@HiveType(typeId: 4)
class BlurBorderLayer extends FrameLayer {
  BlurBorderLayer({
    required this.intensity,
    this.edge = true,
  });

  /// Blur kernel size. Typical values: 3 (subtle) – 10 (heavy).
  @HiveField(0)
  final double intensity;

  /// True: blur only the outer ring. False: blur the entire image.
  @HiveField(1)
  final bool edge;
}

/// A text watermark rendered at a fixed corner / center position.
@HiveType(typeId: 5)
class TextWatermarkLayer extends FrameLayer {
  TextWatermarkLayer({
    required this.text,
    required this.position,
    this.fontSize = 14,
    this.color = 0xFFFFFFFF,
  });

  @HiveField(0)
  final String text;

  @HiveField(1)
  final WatermarkPosition position;

  @HiveField(2)
  final double fontSize;

  /// ARGB color value.
  @HiveField(3)
  final int color;
}

/// A solid-color bar rendered at the top or bottom edge.
@HiveType(typeId: 6)
class ColorStripeLayer extends FrameLayer {
  ColorStripeLayer({
    required this.color,
    required this.width,
    this.cornerRadius = 0,
    this.position = StripePosition.top,
  });

  /// ARGB color value.
  @HiveField(0)
  final int color;

  /// Stripe thickness in pixels (relative to the output image height).
  @HiveField(1)
  final double width;

  @HiveField(2)
  final double cornerRadius;

  @HiveField(3)
  final StripePosition position;
}

/// Position of a [TextWatermarkLayer] within the photo.
@HiveType(typeId: 9)
enum WatermarkPosition {
  @HiveField(0)
  topLeft,
  @HiveField(1)
  topRight,
  @HiveField(2)
  bottomLeft,
  @HiveField(3)
  bottomRight,
  @HiveField(4)
  center,
}

/// Position of a [ColorStripeLayer] along the vertical axis.
@HiveType(typeId: 10)
enum StripePosition {
  @HiveField(0)
  top,
  @HiveField(1)
  bottom,
}