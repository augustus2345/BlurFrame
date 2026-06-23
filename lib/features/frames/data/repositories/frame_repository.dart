import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../shared/services/hive_service.dart';
import '../models/frame_template.dart';

/// Thrown when a caller tries to mutate a built-in frame template
/// (delete, overwrite). Built-in templates ship with the app and are
/// immutable — users customize by [copying] them, not editing in place.
///
/// Catch this in the UI to show "内置模板不可修改" snackbar.
class BuiltInTemplateException implements Exception {
  const BuiltInTemplateException(this.id);

  /// The id of the built-in template the caller tried to mutate.
  final String id;

  @override
  String toString() => 'BuiltInTemplateException: built-in template '
      "'$id' is immutable";
}

/// Persistence + protection rules for frame templates.
///
/// Built-in templates (those seeded by the app, `isBuiltIn == true`) are
/// immutable through this repository: they cannot be [delete]d, and their
/// id cannot be reused by a [save] call. This prevents a user action from
/// silently shadowing a built-in template.
class FrameRepository {
  /// Production constructor — uses the shared Hive frames box.
  FrameRepository() : _box = HiveService.frames;

  /// Test seam — inject a custom [Box] (e.g. a mocktail mock) to bypass
  /// the shared Hive box. Should only be used in unit tests.
  ///
  /// Internally delegates to the private [FrameRepository._] constructor.
  factory FrameRepository.fromBox(Box<dynamic> box) = FrameRepository._;

  /// Private constructor backing [FrameRepository.fromBox]. Keeps the
  /// injection path out of the public default constructor.
  FrameRepository._(this._box);

  final Box<dynamic> _box;

  /// All templates currently persisted, including built-ins.
  List<FrameTemplate> getAll() => _box.values.cast<FrameTemplate>().toList();

  /// Look up a single template by id. Returns `null` if not present.
  FrameTemplate? getById(String id) => _box.get(id) as FrameTemplate?;

  /// Persist a user template, or update an existing one.
  ///
  /// Throws [BuiltInTemplateException] if the id is already taken by a
  /// built-in template — even with the same payload. Use a copy
  /// (M2 会在编辑器里实现 "复制为我的模板") for customization.
  Future<void> save(FrameTemplate template) async {
    final existing = getById(template.id);
    if (existing != null && existing.isBuiltIn) {
      throw BuiltInTemplateException(template.id);
    }
    await _box.put(template.id, template);
  }

  /// Delete a template by id.
  ///
  /// Throws [BuiltInTemplateException] if the target is built-in. Deleting
  /// a non-existent id is a no-op (Hive's behavior), so the caller does
  /// not need to pre-check existence.
  Future<void> delete(String id) async {
    final existing = getById(id);
    if (existing != null && existing.isBuiltIn) {
      throw BuiltInTemplateException(id);
    }
    await _box.delete(id);
  }
}

final frameRepositoryProvider = Provider<FrameRepository>((ref) {
  return FrameRepository();
});

final frameTemplateListProvider =
    FutureProvider<List<FrameTemplate>>((ref) async {
  return ref.watch(frameRepositoryProvider).getAll();
});
