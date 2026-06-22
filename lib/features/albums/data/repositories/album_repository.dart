import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../shared/services/hive_service.dart';
import '../models/album_model.dart';

class AlbumRepository {
  AlbumRepository();

  Box get _box => HiveService.albums;

  List<AlbumModel> getAll() => _box.values.cast<AlbumModel>().toList();

  Future<void> save(AlbumModel album) => _box.put(album.id, album);

  Future<void> delete(String id) => _box.delete(id);
}

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository();
});

final albumListProvider = FutureProvider<List<AlbumModel>>((ref) async {
  final repo = ref.watch(albumRepositoryProvider);
  return repo.getAll();
});