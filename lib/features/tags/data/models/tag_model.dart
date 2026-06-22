/// A Lightroom-style tag. Tags live in their own box so we can rename
/// them centrally and reflect changes across all photos.
class TagModel {
  const TagModel({
    required this.id,
    required this.name,
    this.colorValue = 0xFF808080,
  });

  final String id;
  final String name;
  final int colorValue;
}