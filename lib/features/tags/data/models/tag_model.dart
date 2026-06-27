import 'package:hive/hive.dart';

part 'tag_model.g.dart';

/// Lightroom-style tag 标签模型。
///
/// [name] 是用户可见的标签名称，[colorValue] 是 ARGB 整型颜色值。
/// 标签存在独立 box 中，支持集中重命名后同步到所有照片。
///
/// Hive typeId 分配（与 PLAN.md R5 一致）：typeId: 8。
@HiveType(typeId: 8)
class TagModel {
  TagModel({
    required this.id,
    required this.name,
    required this.colorValue,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 标签唯一 ID（UUID）。
  @HiveField(0)
  final String id;

  /// 标签名称（用户自定义）。
  @HiveField(1)
  final String name;

  /// ARGB 整型颜色值（如 0xFF2196F3）。
  @HiveField(2)
  final int colorValue;

  /// 创建时间戳。
  @HiveField(3)
  final DateTime createdAt;

  /// 创建可变拷贝，支持字段覆盖。
  TagModel copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
  }) =>
      TagModel(
        id: id ?? this.id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        createdAt: createdAt ?? this.createdAt,
      );
}