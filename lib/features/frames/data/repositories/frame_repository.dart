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

/// Returns the two built-in templates shipped with the app.
///
/// These are used to seed the frames box on first launch (see
/// [ensureBuiltInsSeeded]). Each id is stable and unique.
///
/// - **极简** (`builtin-minimal`): single [BlurBorderLayer] (intensity 4,
///   edge-only blur) — clean, distraction-free border.
/// - **杂志** (`builtin-magazine`): 3-layer composite — top-center brand
///   text watermark, bottom-center EXIF-placeholder text watermark, and a
///   blurred edge border. The bottom watermark text `"YYYY-MM-DD"` is a
///   placeholder that will be replaced with actual EXIF data at render time
///   (M2-T5 / M2-T6).
///
/// Built-in templates are immutable through the repository: they cannot be
/// [delete]d or overwritten by [save].
List<FrameTemplate> builtInTemplates() {
  return [
    // ── 极简 ───────────────────────────────────────────────
    FrameTemplate(
      id: 'builtin-minimal',
      name: '极简',
      isBuiltIn: true,
      usageCount: 0,
      layers: [
        BlurBorderLayer(intensity: 4, edge: true),
      ],
    ),
    // ── 杂志 ───────────────────────────────────────────────
    FrameTemplate(
      id: 'builtin-magazine',
      name: '杂志',
      isBuiltIn: true,
      usageCount: 0,
      layers: [
        // Bottom EXIF placeholder (z-order: below top watermark)
        TextWatermarkLayer(
          text: 'YYYY-MM-DD',
          position: WatermarkPosition.bottomCenter,
          fontSize: 12,
          color: 0xCCFFFFFF,
        ),
        // Top brand watermark (z-order: above bottom watermark)
        TextWatermarkLayer(
          text: 'Photo',
          position: WatermarkPosition.topCenter,
          fontSize: 16,
          color: 0xFFFFFFFF,
        ),
        // Blurred edge border (z-order: lowest, painted first)
        BlurBorderLayer(intensity: 6, edge: true),
      ],
    ),
  ];
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

  /// Seed the box with built-in templates if they are not yet present.
  ///
  /// Idempotent: safe to call on every app startup. Only writes when a
  /// built-in id is missing from the box (i.e. first launch, or the user
  /// somehow deleted a built-in).
  Future<void> ensureBuiltInsSeeded() async {
    for (final tmpl in builtInTemplates()) {
      if (!(_box.containsKey(tmpl.id))) {
        await _box.put(tmpl.id, tmpl);
      }
    }
  }
}

final frameRepositoryProvider = Provider<FrameRepository>((ref) {
  return FrameRepository();
});

final frameTemplateListProvider =
    FutureProvider<List<FrameTemplate>>((ref) async {
  return ref.watch(frameRepositoryProvider).getAll();
});
