import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../shared/services/hive_service.dart';
import '../datasources/photo_manager_datasource.dart';
import '../models/photo_model.dart';

/// Repository for photo metadata persistence.
///
/// 实际照片字节仍在系统相册 — 我们只存引用 + 用户数据（标签 / 套用模板等）。
/// 字段定义见 [PhotoModel]（`@HiveType(typeId: 1)`）。
///
/// 构造路径：
///   - [PhotoRepository]（默认）— 生产路径，读 [HiveService.photosMeta] +
///     真实 [PhotoManagerDatasource]。要求 `HiveService.init()` 已先调用。
///   - [PhotoRepository.fromBox] — DI / 测试路径，传入 box 与可选 datasource。
///     与 `FrameRepository.fromBox` / `SettingsService.fromBox` 保持同样的约定。
class PhotoRepository {
  /// 默认构造：走全局 [HiveService.photosMeta] + 真实 `PhotoManagerDatasource`。
  PhotoRepository()
      : _box = HiveService.photosMeta,
        _datasource = PhotoManagerDatasource();

  /// 测试 / DI 构造：传入 box；`datasource` 不传则用真实默认（通常测试中必传）。
  @visibleForTesting
  PhotoRepository.fromBox(
    Box<dynamic> box, {
    PhotoManagerDatasource? datasource,
  })  : _box = box,
        _datasource = datasource ?? PhotoManagerDatasource();

  final Box<dynamic> _box;
  final PhotoManagerDatasource _datasource;

  /// 把模型写入 box，key 为 [PhotoModel.id]。
  Future<void> save(PhotoModel photo) async {
    await _box.put(photo.id, photo);
  }

  /// 根据 [id] 读取模型。box 中无此 key 时返回 `null`。
  PhotoModel? get(String id) {
    return _box.get(id) as PhotoModel?;
  }

  /// 列出 box 中所有模型（按写入顺序，不保证）。
  List<PhotoModel> getAll() {
    return _box.values.cast<PhotoModel>().toList();
  }

  /// 删除指定 id 的条目。
  Future<void> delete(String id) => _box.delete(id);

  /// 清空整个 box（保留 box 本身）。
  Future<void> clear() => _box.clear();

  /// 更新照片的标签列表。
  ///
  /// [id] 不存在则 no-op。
  Future<void> updateTags(String id, List<String> tags) async {
    final photo = get(id);
    if (photo == null) return;
    await save(PhotoModel(
      id: photo.id,
      path: photo.path,
      width: photo.width,
      height: photo.height,
      takenAt: photo.takenAt,
      tags: tags,
      frameTemplateId: photo.frameTemplateId,
      starRating: photo.starRating,
    ));
  }

  /// 更新照片的星级评分。
  ///
  /// [id] 不存在则 no-op。
  /// [starRating] 有效范围 0–5，超出范围会被 clamp。
  Future<void> updateStarRating(String id, int starRating) async {
    final photo = get(id);
    if (photo == null) return;
    await save(PhotoModel(
      id: photo.id,
      path: photo.path,
      width: photo.width,
      height: photo.height,
      takenAt: photo.takenAt,
      tags: photo.tags,
      frameTemplateId: photo.frameTemplateId,
      starRating: starRating.clamp(0, 5),
    ));
  }

  /// 扫描系统相册，返回合并后的照片列表。
  ///
  /// 合并规则：
  /// - 对每个系统照片，先用 `get(id)` 找 Hive 中已有的 [PhotoModel]
  /// - 系统元数据（`path` / `width` / `height` / `takenAt`）覆盖 Hive 同名字段
  ///   — 系统是这些字段的**唯一权威源**
  /// - 用户元数据（`tags` / `frameTemplateId`）从 Hive 继承，**不**被系统覆盖
  /// - 若系统某字段为 `null`（EXIF 解析失败 / 平台无 path），
  ///   回退到 Hive 中已有值；都没有就用业务默认（`path = ''` 等）
  ///
  /// 副作用：每个合并结果都 `save` 回 Hive，便于下次扫描对齐 + 重启后能列出
  /// "已扫过但没用户数据"的照片（M5 清理模式可据此显示进度）。
  Future<List<PhotoModel>> loadAllFromSystem() async {
    final systemPhotos = await _datasource.fetchAll();
    final result = <PhotoModel>[];
    for (final sys in systemPhotos) {
      final existing = get(sys.id);
      final merged = PhotoModel(
        id: sys.id,
        path: sys.path ?? existing?.path ?? '',
        width: sys.width ?? existing?.width,
        height: sys.height ?? existing?.height,
        takenAt: sys.takenAt ?? existing?.takenAt,
        tags: existing?.tags ?? const <String>[],
        frameTemplateId: existing?.frameTemplateId,
      );
      await save(merged);
      result.add(merged);
    }
    return result;
  }
}
