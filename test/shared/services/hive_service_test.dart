import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:photo_beauty/core/constants/app_constants.dart';
import 'package:photo_beauty/shared/services/hive_service.dart';

/// Tests for [HiveService] startup, idempotency, and `clearAll` semantics.
///
/// 与 SettingsService / FrameRepository 的 mocktail 测试不同，
/// [HiveService.init] 涉及 `Hive.initFlutter` / `Hive.openBox` 等全局注册表，
/// 不能用 mock —— 必须用真 Hive + 临时目录。
///
/// 测试隔离策略（setUp / tearDown 都要做）：
///   1. `await Hive.close()` 清空 `Hive._boxes` 全局映射
///   2. `HiveService.resetForTest()` 清掉 `_initialized` 标志
///   3. `Directory.systemTemp.createTemp(...)` 拿独立的存储目录
///   4. `initForTest(path)` 用真 Hive 重启
///   5. tearDown 删 tempDir 避免磁盘堆积
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - `initForTest` 打开 5 个 box，名字与 [AppConstants] 一一对应
/// - 第二次 `initForTest` 短路返回（_initialized 已为 true），不重新打开
/// - `resetForTest` 配合 `Hive.close` 可重新初始化
/// - `clearAll` 清空 5 个 box
void main() {
  late Directory tempDir;

  setUp(() async {
    // 先收尾：清掉上轮测试可能留下的 box + 标志位
    await Hive.close();
    HiveService.resetForTest();

    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    await HiveService.initForTest(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    HiveService.resetForTest();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HiveService.initForTest', () {
    test('opens all 5 boxes with names matching AppConstants', () {
      // 5 个 getter 都返回非 null，name 与常量完全一致
      expect(HiveService.settings.name, AppConstants.settingsBox);
      expect(HiveService.photosMeta.name, AppConstants.photosMetaBox);
      expect(HiveService.albums.name, AppConstants.albumsBox);
      expect(HiveService.tags.name, AppConstants.tagsBox);
      expect(HiveService.frames.name, AppConstants.framesBox);
    });

    test('is idempotent (second call is a no-op)', () async {
      // setUp 已经调过一次，这里再调两次都不应抛
      await HiveService.initForTest(tempDir.path);
      await HiveService.initForTest(tempDir.path);

      // 短路返回后，box 依然能拿到
      expect(HiveService.settings.name, AppConstants.settingsBox);
    });
  });

  group('HiveService.resetForTest', () {
    test('allows re-initialization with the same path', () async {
      // 重置标志位后，initForTest 会真正执行 _completeInit
      // （不靠 short-circuit 跳过）。Hive.openBox 对已开 box 返回同一实例，不会重复打开。
      HiveService.resetForTest();
      await HiveService.initForTest(tempDir.path);

      // box 依然可访问
      expect(HiveService.settings.name, AppConstants.settingsBox);
      expect(HiveService.frames.name, AppConstants.framesBox);
    });
  });

  group('HiveService.clearAll', () {
    test('empties all 5 boxes', () async {
      // Arrange：每个 box 塞一个 key
      await HiveService.settings.put('k', 'v');
      await HiveService.photosMeta.put('k', 'v');
      await HiveService.albums.put('k', 'v');
      await HiveService.tags.put('k', 'v');
      await HiveService.frames.put('k', 'v');

      // Sanity：写入成功
      expect(HiveService.settings.get('k'), 'v');

      // Act
      await HiveService.clearAll();

      // Assert：5 个 box 都空了
      expect(HiveService.settings.get('k'), isNull);
      expect(HiveService.photosMeta.get('k'), isNull);
      expect(HiveService.albums.get('k'), isNull);
      expect(HiveService.tags.get('k'), isNull);
      expect(HiveService.frames.get('k'), isNull);
    });
  });
}
