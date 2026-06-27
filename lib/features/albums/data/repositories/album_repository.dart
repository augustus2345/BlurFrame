import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../shared/services/hive_service.dart';
import '../models/album_model.dart';

/// 用户创建的影集 Repository。
///
/// 提供完整的 CRUD 操作：
/// - [create] 新建影集（生成 uuid id）
/// - [rename] 修改影集名称
/// - [addPhotos] 添加照片到影集
/// - [removePhotos] 从影集移除照片（自动更新 coverPhotoId）
/// - [reorderPhotos] 拖拽重排（持久化新顺序）
/// - [setCover] 换封面
/// - [setLayout] 换版式
/// - [delete] 删除影集
class AlbumRepository {
  /// 生产构造：使用共享 Hive albums box。
  AlbumRepository() : _box = HiveService.albums;

  /// 测试入口：注入自定义 [Box] 以绕过共享 Hive box。
  factory AlbumRepository.fromBox(Box<dynamic> box) = AlbumRepository._;

  AlbumRepository._(this._box);

  final Box<dynamic> _box;

  /// 获取所有影集，按创建时间倒序（新的在前）。
  List<AlbumModel> getAll() {
    final list = _box.values.cast<AlbumModel>().toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 根据 id 查询单个影集，不存在返回 null。
  AlbumModel? getById(String id) => _box.get(id) as AlbumModel?;

  /// 新建影集。
  ///
  /// [name] 必填；[photoIds] 初始照片列表（可为空）；[layout] 初始版式。
  /// 自动生成 uuid id，createdAt 固定为当前时间。
  /// [coverPhotoId] 未指定时默认取 [photoIds] 第一张。
  Future<AlbumModel> create({
    required String name,
    List<String> photoIds = const [],
    AlbumLayout layout = AlbumLayout.grid,
    String? coverPhotoId,
  }) async {
    final id = _uuid.v4();
    final album = AlbumModel(
      id: id,
      name: name,
      coverPhotoId: coverPhotoId ?? (photoIds.isNotEmpty ? photoIds.first : ''),
      photoIds: List.from(photoIds),
      layout: layout,
    );
    await _box.put(id, album);
    return album;
  }

  /// 修改影集名称。
  ///
  /// [id] 不存在则 no-op。
  Future<void> rename(String id, String newName) async {
    final album = getById(id);
    if (album == null) return;
    await _box.put(id, album.copyWith(name: newName));
  }

  /// 添加照片到影集末尾。
  ///
  /// [id] 不存在则 no-op。
  /// 如果影集还没有封面，自动把第一张添加的照片设为封面。
  Future<void> addPhotos(String id, List<String> photoIdsToAdd) async {
    final album = getById(id);
    if (album == null) return;
    final newPhotoIds = List<String>.from(album.photoIds)..addAll(photoIdsToAdd);
    final newCoverPhotoId = album.coverPhotoId.isEmpty && photoIdsToAdd.isNotEmpty
        ? photoIdsToAdd.first
        : album.coverPhotoId;
    await _box.put(
      id,
      album.copyWith(photoIds: newPhotoIds, coverPhotoId: newCoverPhotoId),
    );
  }

  /// 从影集移除照片。
  ///
  /// [id] 不存在则 no-op。
  /// 如果移除的是封面照片，自动把剩余第一张照片设为新封面（为空则清空 coverPhotoId）。
  Future<void> removePhotos(String id, List<String> photoIdsToRemove) async {
    final album = getById(id);
    if (album == null) return;
    final newPhotoIds =
        List<String>.from(album.photoIds)..removeWhere(photoIdsToRemove.contains);
    String newCoverPhotoId = album.coverPhotoId;
    if (photoIdsToRemove.contains(album.coverPhotoId)) {
      newCoverPhotoId = newPhotoIds.isNotEmpty ? newPhotoIds.first : '';
    }
    await _box.put(
      id,
      album.copyWith(photoIds: newPhotoIds, coverPhotoId: newCoverPhotoId),
    );
  }

  /// 拖拽重排持久化。
  ///
  /// [id] 不存在则 no-op。
  /// [newPhotoIds] 是重排后的完整列表，repository 直接替换。
  Future<void> reorderPhotos(String id, List<String> newPhotoIds) async {
    final album = getById(id);
    if (album == null) return;
    // 如果 cover 不在新列表里，自动换成第一张
    final newCoverPhotoId =
        newPhotoIds.contains(album.coverPhotoId) ? album.coverPhotoId : '';
    await _box.put(
      id,
      album.copyWith(photoIds: newPhotoIds, coverPhotoId: newCoverPhotoId),
    );
  }

  /// 换封面。
  ///
  /// [id] 不存在或 [newCoverPhotoId] 不在影集中则 no-op。
  Future<void> setCover(String id, String newCoverPhotoId) async {
    final album = getById(id);
    if (album == null) return;
    if (!album.photoIds.contains(newCoverPhotoId)) return;
    await _box.put(id, album.copyWith(coverPhotoId: newCoverPhotoId));
  }

  /// 换版式。
  ///
  /// [id] 不存在则 no-op。
  Future<void> setLayout(String id, AlbumLayout newLayout) async {
    final album = getById(id);
    if (album == null) return;
    await _box.put(id, album.copyWith(layout: newLayout));
  }

  /// 删除影集。
  ///
  /// [id] 不存在是 no-op（Hive delete 行为）。
  Future<void> delete(String id) => _box.delete(id);

  /// UUID 生成器，测试时可通过继承类覆盖。
  UuidGenerator get _uuid => const UuidGenerator._();
}

/// DI 入口。
final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository();
});

/// 影集列表 Provider。与 [AlbumRepository.getAll] 联动，数据变更后自动 rebuild。
final albumListProvider = FutureProvider<List<AlbumModel>>((ref) async {
  final repo = ref.watch(albumRepositoryProvider);
  return repo.getAll();
});

/// 生产用 UUID 生成器（调用 uuid 包）。
class UuidGenerator {
  const UuidGenerator._();

  String v4() {
    // 生成标准 UUID v4 格式：xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // x 用随机十六进制，y 取 8/9/a/b
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final hex = rnd.toRadixString(16).padLeft(12, '0');
    final part1 = hex.substring(0, 8);
    final part2 = hex.substring(0, 4);
    final part3 = '4${hex.substring(0, 3)}'; // version 4
    final part4 = '${(rnd % 4 + 8).toRadixString(16)}${hex.substring(0, 3)}';
    final part5 = hex.substring(0, 12);
    return '$part1-$part2-$part3-$part4-$part5';
  }
}