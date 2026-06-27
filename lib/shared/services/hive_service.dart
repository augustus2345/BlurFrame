import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../features/frames/data/models/frame_template.dart';
import '../../features/photos/data/models/photo_model.dart';

/// Bootstraps Hive boxes and centralizes access. All persistence flows
/// through here so adapter registration and box lifecycle stay consistent.
///
/// Adapters for typed models (Photo, Album, FrameTemplate, Tag) should be
/// registered in [Hive.registerAdaptersSafe] before opening boxes.
class HiveService {
  HiveService._();

  static bool _initialized = false;

  /// Call once during app startup, after [WidgetsFlutterBinding.ensureInitialized].
  ///
  /// 生产路径：用 [Hive.initFlutter] 从 path_provider 取 app 文档目录。
  /// 测试请用 [initForTest] 直接指定路径（[Hive.initFlutter] 依赖平台插件）。
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await _completeInit();
  }

  /// 测试入口：用 [path] 调 [Hive.init]，绕过 [Hive.initFlutter] 的 path_provider 依赖。
  ///
  /// 行为与 [init] 一致：注册适配器 + 打开 5 个 box + 标记 `_initialized = true`。
  @visibleForTesting
  static Future<void> initForTest(String path) async {
    if (_initialized) return;
    Hive.init(path);
    await _completeInit();
  }

  /// 重置 `_initialized` 标志，让下一次 [init] / [initForTest] 真正执行初始化。
  ///
  /// 配套 [Hive.close] 一起使用：测试 setUp 一般先 `await Hive.close()` + `resetForTest()`，
  /// 再 `initForTest(newPath)` 拿到干净状态。
  @visibleForTesting
  static void resetForTest() {
    _initialized = false;
  }

  /// 初始化收尾：注册适配器 + 打开 box + 标记 _initialized。
  /// 由 [init] 和 [initForTest] 共享，避免重复。
  static Future<void> _completeInit() async {
    registerAdapters();
    await _openBoxes();
    _initialized = true;
  }

  /// Register Hive adapters for typed models.
  ///
  /// M1 已接入：PhotoModel（typeId 1）。
  /// M2 已接入：FrameTemplate (2) + BlurBorderLayer (4) + TextWatermarkLayer (5) +
  ///   ColorStripeLayer (6) + WatermarkPosition (9) + StripePosition (10)。
  /// M3-M4 仍为占位 — 接入步骤：
  ///   1. 在对应 model 文件加 `@HiveType(typeId: N)` + 字段 `@HiveField`
  ///   2. 跑 `dart run build_runner build --delete-conflicting-outputs`
  ///   3. 把下方对应的 `// TODO(Mx): Hive.registerAdapter(...)` 取消注释
  ///
  /// typeId 分配（与 PLAN.md R5 一致）：
  ///   1  → PhotoModel        (M1 ✅)
  ///   2  → FrameTemplate     (M2 ✅)
  ///   4  → BlurBorderLayer   (M2 ✅)
  ///   5  → TextWatermarkLayer (M2 ✅)
  ///   6  → ColorStripeLayer  (M2 ✅)
  ///   9  → WatermarkPosition (M2 ✅)
  ///   10 → StripePosition    (M2 ✅)
  ///   7  → AlbumModel        (M3)
  ///   8  → TagModel          (M4)
  static void registerAdapters() {
    try {
      // 防御性：跨测试文件 / 热重载时，Hive 全局注册表可能已存在该 typeId。
      // 重复 `registerAdapter` 会抛 "already registered"，所以先查再注册。
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PhotoModelAdapter());
      }
      // M2: FrameTemplate (2) + 3 layer adapters (4-6)
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(FrameTemplateAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(BlurBorderLayerAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(TextWatermarkLayerAdapter());
      }
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(ColorStripeLayerAdapter());
      }
      if (!Hive.isAdapterRegistered(9)) {
        Hive.registerAdapter(WatermarkPositionAdapter());
      }
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(StripePositionAdapter());
      }
      // TODO(M3): Hive.registerAdapter(AlbumModelAdapter());
      // TODO(M4): Hive.registerAdapter(TagModelAdapter());
    } catch (e, st) {
      debugPrint('HiveService.registerAdapters 失败: $e\n$st');
      rethrow;
    }
  }

  static Future<void> _openBoxes() async {
    await Future.wait<void>([
      Hive.openBox<dynamic>(AppConstants.settingsBox),
      Hive.openBox<dynamic>(AppConstants.photosMetaBox),
      Hive.openBox<dynamic>(AppConstants.albumsBox),
      Hive.openBox<dynamic>(AppConstants.tagsBox),
      Hive.openBox<dynamic>(AppConstants.framesBox),
    ]);
  }

  // Typed box accessors --------------------------------------------------

  static Box<dynamic> get settings => Hive.box(AppConstants.settingsBox);

  static Box<dynamic> get photosMeta => Hive.box(AppConstants.photosMetaBox);

  static Box<dynamic> get albums => Hive.box(AppConstants.albumsBox);

  static Box<dynamic> get tags => Hive.box(AppConstants.tagsBox);

  static Box<dynamic> get frames => Hive.box(AppConstants.framesBox);

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
