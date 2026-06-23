import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../shared/services/hive_service.dart';
import '../models/tag_model.dart';

class TagRepository {
  TagRepository();

  Box<dynamic> get _box => HiveService.tags;

  List<TagModel> getAll() => _box.values.cast<TagModel>().toList();

  Future<void> save(TagModel tag) => _box.put(tag.id, tag);

  Future<void> delete(String id) => _box.delete(id);
}

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository();
});

final tagListProvider = FutureProvider<List<TagModel>>((ref) async {
  return ref.watch(tagRepositoryProvider).getAll();
});
