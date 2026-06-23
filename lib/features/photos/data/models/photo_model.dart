import 'package:hive/hive.dart';

part 'photo_model.g.dart';

/// 单张照片的本地元数据 / 业务数据。
///
/// 设计原则：
/// 1. **只存元数据，不存原图** — `id` 指向 `photo_manager` 的 `AssetEntity`，
///    `path` 是系统路径 / 内容 URI。实际像素仍在系统相册里。
/// 2. **flat 字段** — 不嵌自定义对象，避免后续改字段时重排 typeId。
/// 3. **可选字段一律 `null`，不用哨兵值** — 配合 Hive 默认值 `null`。
///
/// Hive typeId 分配（与 PLAN.md R5 一致）：`typeId: 1`。
/// 后续新增字段用下一个空闲 `@HiveField(N)`，**绝不重用旧编号** —
/// 重用会让旧 box 数据反序列化时丢字段（CLAUDE.md §1.5 风险点）。
@HiveType(typeId: 1)
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

  /// `photo_manager` 平台资源 ID（Android 上是 media store id，iOS 上是 PHAsset localIdentifier）。
  ///
  /// 也是 Hive box 的 key（参见 `PhotoRepository.save`）。
  @HiveField(0)
  final String id;

  /// 文件系统路径或 content URI。
  ///
  /// 用于快速打开 / 重建 `AssetEntity`（不依赖 photo_manager 的 path 索引）。
  @HiveField(1)
  final String path;

  /// 像素宽。原图为横屏时 > 竖屏。读取失败时为 `null`。
  @HiveField(2)
  final int? width;

  /// 像素高。
  @HiveField(3)
  final int? height;

  /// EXIF 中的拍摄时间；读取失败时为 `null`。
  @HiveField(4)
  final DateTime? takenAt;

  /// 用户打的标签 ID 列表（M4 接入 `TagModel` 后用其 id）。
  ///
  /// `List<String>` 是 Hive 内建支持类型，无需自定义适配器。
  @HiveField(5)
  final List<String> tags;

  /// 已套用的相框模板 ID（`FrameTemplate.id`）。未套用时为 `null`。
  @HiveField(6)
  final String? frameTemplateId;
}
