/// Placeholder for an album aggregate. Will be a Hive entity once the
/// schema is finalized.
class AlbumModel {
  const AlbumModel({
    required this.id,
    required this.name,
    required this.coverPhotoId,
    required this.photoIds,
    this.createdAt,
    this.layout = AlbumLayout.grid,
  });

  final String id;
  final String name;
  final String coverPhotoId;
  final List<String> photoIds;
  final DateTime? createdAt;
  final AlbumLayout layout;
}

enum AlbumLayout { grid, magazine, collage, polaroid }