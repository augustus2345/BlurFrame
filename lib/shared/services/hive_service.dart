import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';

/// Bootstraps Hive boxes and centralizes access. All persistence flows
/// through here so adapter registration and box lifecycle stay consistent.
///
/// Adapters for typed models (Photo, Album, FrameTemplate, Tag) should be
/// registered in [Hive.registerAdaptersSafe] before opening boxes.
class HiveService {
  HiveService._();

  static bool _initialized = false;

  /// Call once during app startup, after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    registerAdapters();
    await _openBoxes();
    _initialized = true;
  }

  /// Register Hive adapters here as features add typed models.
  /// Generated adapters (e.g. `PhotoAdapter`) plug in here.
  static void registerAdapters() {
    // Example pattern — uncomment when adapter exists:
    // if (!Hive.isAdapterRegistered(PhotoAdapter().typeId)) {
    //   Hive.registerAdapter(PhotoAdapter());
    // }
  }

  static Future<void> _openBoxes() async {
    await Future.wait<void>([
      Hive.openBox(AppConstants.settingsBox),
      Hive.openBox(AppConstants.photosMetaBox),
      Hive.openBox(AppConstants.albumsBox),
      Hive.openBox(AppConstants.tagsBox),
      Hive.openBox(AppConstants.framesBox),
    ]);
  }

  // Typed box accessors --------------------------------------------------

  static Box get settings =>
      Hive.box(AppConstants.settingsBox);

  static Box get photosMeta =>
      Hive.box(AppConstants.photosMetaBox);

  static Box get albums =>
      Hive.box(AppConstants.albumsBox);

  static Box get tags =>
      Hive.box(AppConstants.tagsBox);

  static Box get frames =>
      Hive.box(AppConstants.framesBox);

  /// Wipes every app-managed box. Used by Settings → Reset.
  static Future<void> clearAll() async {
    await Future.wait<void>([
      settings.clear(),
      photosMeta.clear(),
      albums.clear(),
      tags.clear(),
      frames.clear(),
    ]);
  }
}