import 'package:hive/hive.dart';

part 'album_model.g.dart';

/// 用户创建的影集 Aggregate Root。
///
/// [photoIds] 保持插入顺序，用于 [ReorderableListView] 拖拽重排。
/// [layout] 控制详情页的版式（autoLayout / 1/2/3/4 宫格）。
@HiveType(typeId: 7)
class AlbumModel extends HiveObject {
  AlbumModel({
    required this.id,
    required this.name,
    required this.coverPhotoId,
    required this.photoIds,
    DateTime? createdAt,
    this.layout = AlbumLayout.grid,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Persisted creation timestamp.
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// 封面照片 ID（来自 [photoIds] 之一）。
  @HiveField(2)
  final String coverPhotoId;

  /// 影集中照片 ID 有序列表。拖拽重排时更新顺序。
  @HiveField(3)
  final List<String> photoIds;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final AlbumLayout layout;

  /// Creates a mutable copy with optional field overrides.
  AlbumModel copyWith({
    String? id,
    String? name,
    String? coverPhotoId,
    List<String>? photoIds,
    DateTime? createdAt,
    AlbumLayout? layout,
  }) =>
      AlbumModel(
        id: id ?? this.id,
        name: name ?? this.name,
        coverPhotoId: coverPhotoId ?? this.coverPhotoId,
        photoIds: photoIds ?? List.from(this.photoIds),
        createdAt: createdAt ?? this.createdAt,
        layout: layout ?? this.layout,
      );
}

/// 影集详情页的版式选项。
@HiveType(typeId: 11)
enum AlbumLayout {
  @HiveField(0)
  grid,

  @HiveField(1)
  magazine,

  @HiveField(2)
  collage,

  @HiveField(3)
  polaroid,
}