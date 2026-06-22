/// Domain placeholder for a single photo asset.
///
/// Will become a Hive type (with @HiveType) once the schema stabilizes —
/// keep fields flat so adapters stay simple.
class PhotoModel {
  const PhotoModel({
    required this.id,
    required this.path,
    this.width,
    this.height,
    this.takenAt,
    this.tags = const <String>[],
    this.frameTemplateId,
  });

  /// Platform-specific asset identifier (photo_manager id).
  final String id;

  /// Filesystem path or content URI.
  final String path;

  final int? width;
  final int? height;
  final DateTime? takenAt;
  final List<String> tags;
  final String? frameTemplateId;
}