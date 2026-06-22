import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/services/hive_service.dart';
import '../models/photo_model.dart';

/// Repository for photo metadata persistence.
///
/// The actual photo bytes stay on disk — we only keep references +
/// user-added data (tags, applied frame templates, etc.) in Hive.
class PhotoRepository {
  PhotoRepository();

  Box get _box => HiveService.photosMeta;

  Future<void> save(PhotoModel photo) async {
    await _box.put(photo.id, photo);
  }

  PhotoModel? get(String id) {
    return _box.get(id) as PhotoModel?;
  }

  List<PhotoModel> getAll() {
    return _box.values.cast<PhotoModel>().toList();
  }

  Future<void> delete(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();

  // ignore: unused_element
  static String get _boxName => AppConstants.photosMetaBox;
}