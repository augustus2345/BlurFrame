import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../shared/services/hive_service.dart';
import '../models/frame_template.dart';

class FrameRepository {
  FrameRepository();

  Box get _box => HiveService.frames;

  List<FrameTemplate> getAll() => _box.values.cast<FrameTemplate>().toList();

  Future<void> save(FrameTemplate template) => _box.put(template.id, template);

  Future<void> delete(String id) => _box.delete(id);
}

final frameRepositoryProvider = Provider<FrameRepository>((ref) {
  return FrameRepository();
});

final frameTemplateListProvider = FutureProvider<List<FrameTemplate>>((ref) async {
  return ref.watch(frameRepositoryProvider).getAll();
});