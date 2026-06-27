import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../shared/services/hive_service.dart';
import '../../../photos/data/models/photo_model.dart';
import '../models/tag_model.dart';

/// Thrown when a caller tries to delete a tag that is still referenced by
/// one or more photos. The UI should prompt the user to unbind the tag from
/// those photos first, then retry deletion.
///
/// Catch this to show "该标签已被使用，请先移除照片中的标签后再删除" snackbar.
class TagInUseException implements Exception {
  const TagInUseException(this.tagId, this.photoCount);

  /// The id of the tag the caller tried to delete.
  final String tagId;

  /// Number of photos that still reference this tag.
  final int photoCount;

  @override
  String toString() => 'TagInUseException: tag '
      "'$tagId' is still referenced by $photoCount photo(s)";
}

/// Lightroom-style tag 标签 Repository。
///
/// 提供完整的 CRUD 操作：
/// - [create] 新建标签
/// - [rename] 重命名标签
/// - [setColor] 修改颜色
/// - [delete] 删除标签（被引用时抛出 [TagInUseException]）
///
/// 标签被照片引用时禁止直接删除（[TagInUseException]），调用方需先解绑。
class TagRepository {
  /// 生产构造：使用共享 Hive tags box 和 photosMeta box。
  TagRepository() : this._(HiveService.tags, HiveService.photosMeta);

  /// 测试入口：注入自定义 [Box] 以绕过共享 Hive box。
  ///
  /// [tagsBox] 用于 tag 自身的 CRUD。
  /// [photosBox] 用于检查标签是否被照片引用（删除保护）。
  factory TagRepository.fromBox(Box<dynamic> tagsBox, Box<dynamic> photosBox) =
      TagRepository._;

  TagRepository._(this._box, this._photosBox);

  final Box<dynamic> _box;
  final Box<dynamic> _photosBox;

  /// 获取所有标签。
  List<TagModel> getAll() => _box.values.cast<TagModel>().toList();

  /// 根据 id 查询单个标签，不存在返回 null。
  TagModel? getById(String id) => _box.get(id) as TagModel?;

  /// 新建标签。
  ///
  /// [name] 必填；[colorValue] 默认为 0xFF808080（灰色）。
  /// 自动生成 uuid id，createdAt 固定为当前时间。
  Future<TagModel> create({
    required String name,
    int colorValue = 0xFF808080,
  }) async {
    final id = _uuid.v4();
    final tag = TagModel(
      id: id,
      name: name,
      colorValue: colorValue,
    );
    await _box.put(id, tag);
    return tag;
  }

  /// 重命名标签。
  ///
  /// [id] 不存在则 no-op。
  Future<void> rename(String id, String newName) async {
    final tag = getById(id);
    if (tag == null) return;
    await _box.put(id, tag.copyWith(name: newName));
  }

  /// 修改标签颜色。
  ///
  /// [id] 不存在则 no-op。
  Future<void> setColor(String id, int newColorValue) async {
    final tag = getById(id);
    if (tag == null) return;
    await _box.put(id, tag.copyWith(colorValue: newColorValue));
  }

  /// 删除标签。
  ///
  /// [id] 不存在是 no-op（Hive 的行为）。
  /// 如果标签被照片引用，抛出 [TagInUseException]；调用方需先解绑。
  Future<void> delete(String id) async {
    final inUseCount = _countPhotosUsingTag(id);
    if (inUseCount > 0) {
      throw TagInUseException(id, inUseCount);
    }
    await _box.delete(id);
  }

  /// 检查标签是否被照片引用。
  bool isTagInUse(String tagId) => _countPhotosUsingTag(tagId) > 0;

  /// 统计引用该标签的照片数量。
  int _countPhotosUsingTag(String tagId) {
    var count = 0;
    for (final entry in _photosBox.toMap().values) {
      if (entry is PhotoModel && entry.tags.contains(tagId)) {
        count++;
      }
    }
    return count;
  }

  /// UUID 生成器。
  UuidGenerator get _uuid => const UuidGenerator._();
}

/// UUID 生成器（与 AlbumRepository 共用）。
class UuidGenerator {
  const UuidGenerator._();

  String v4() {
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final hex = rnd.toRadixString(16).padLeft(12, '0');
    final part1 = hex.substring(0, 8);
    final part2 = hex.substring(0, 4);
    final part3 = '4${hex.substring(0, 3)}';
    final part4 = '${(rnd % 4 + 8).toRadixString(16)}${hex.substring(0, 3)}';
    final part5 = hex.substring(0, 12);
    return '$part1-$part2-$part3-$part4-$part5';
  }
}

/// DI entry point for the [TagRepository].
final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository();
});
