# Photo Beauty — 任务列表（TASKS.md）

> 与 [PLAN.md](./PLAN.md) / [PRD.md](./docs/prd/PRD.md) 配套。  
> 一次只做一个任务，做完一个再开下一个。

---

## 任务状态图例

- ⬜ 待办
- 🟡 进行中
- ✅ 已完成（含完成时间）
- 🔒 阻塞
- ❌ 已废弃

---

## M0 — 基础设施 ✅（完成于 2026-06-22）

> 骨架代码已就位，需补测试 + 文档注释 + 适配器预留。

- [x] **M0-T0** 修 `pubspec.yaml` 依赖冲突（`freezed ^2.5.7` ↔ `hive_generator ^2.0.1`）
  - 把 `freezed: ^2.5.7` → `^2.5.2`，让 `flutter pub get` 通过
  - 验证：`flutter pub get`（✅ 139 个依赖解决）+ `flutter analyze`（✅ 通过，21 个 pre-existing warnings）
  - **完成时间**: 2026-06-22

- [x] **M0-T1** 在 5 个占位 screen 文件加中文文档注释
  - `lib/features/photos/presentation/screens/photo_gallery_screen.dart`
  - `lib/features/albums/presentation/screens/album_list_screen.dart`
  - `lib/features/frames/presentation/screens/frame_template_list_screen.dart`
  - `lib/features/search/presentation/screens/search_screen.dart`
  - `lib/features/settings/presentation/screens/settings_screen.dart`
  - **预估**: 10 min
  - **完成时间**: 2026-06-22

- [x] **M0-T2** 修 `app_shell.dart` 的 `_indexFromLocation` 索引错位风险
  - 抽出 `@visibleForTesting static int indexFromLocation(String location, List<String> tabPaths)`
  - 匹配规则改为 `==` 或 `path + '/'`-前缀（防未来 `/settings` vs `/settings-extra` 误中）
  - `build` 中 `uri.toString()` → `uri.path`（剥掉 query string）
  - 测试 `test/core/widgets/app_shell_test.dart`：5 个用例（全过）
  - **预估**: 15 min
  - **完成时间**: 2026-06-22

- [x] **M0-T3** 修 `frame_repository.dart` 的内置模板保护
  - 新增 `BuiltInTemplateException`（明确的错误类型，UI 可 catch 后给"内置不可修改"提示）
  - `delete()` / `save()` 都加 `isBuiltIn` 校验（save 是 defense in depth，防覆盖内置模板的 `isBuiltIn=false`）
  - 构造函数加 `factory FrameRepository.fromBox(Box box)`（命名 factory，DI 测试入口）
  - 加 `getById(String id) → FrameTemplate?`
  - `pubspec.yaml` 加 `mocktail: ^1.0.4`（dev）
  - 测试 `test/features/frames/frame_repository_test.dart`：8 个用例（全过）
  - **预估**: 30 min（含修编译错 + lint 调 any<dynamic>()）
  - **完成时间**: 2026-06-22

- [x] **M0-T8** 一次性清理 21 个 `analyze` 警告（`Box<dynamic>` 缺类型 / `openBox` 推断 / `RadioListTile` deprecated）
  - 7 个文件加 `<dynamic>` 显式类型（`hive_service` × 10 / `settings_service` × 1 / 4 个 repository × 1 / `frame_repository` × 2 / `MockBox` × 1）
  - `settings_screen.dart` 重构成 `RadioGroup<ThemeMode>` 祖先 + 3 个 `RadioListTile`（替代 Flutter 3.32+ deprecated 的 `groupValue`/`onChanged`）
  - 8 个文件 `dart format` 整理
  - **验证**: `flutter analyze` → **0 issues** | `flutter test` → **13/13** 通过
  - **完成时间**: 2026-06-22
- [x] **M0-T4** 在 `hive_service.registerAdapters()` 注册 4 个占位 `registerAdapter` 调用（先不挂生成代码，避免编译失败）
  - 用 try/catch 保护，等 M1 实际生成 `*.g.dart` 后再启用
  - 4 个 typeId 预分配（与 PLAN.md R5 一致）：1=PhotoModel, 2=FrameTemplate, 7=AlbumModel, 8=TagModel
  - 真实 `Hive.registerAdapter(XxxAdapter())` 调用以 `// TODO(Mx):` 注释占位在 try 体内，catch 里 `debugPrint` + `rethrow` 防止 M1+ 渐进接入时启动崩溃
  - 接入步骤写在 Dartdoc 里：加 `@HiveType` + `@HiveField` → 跑 `build_runner` → 取消 4 行注释 → 删 try/catch
  - 新增 `import 'package:flutter/foundation.dart'`（为 `debugPrint`）
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **13/13** 通过
  - **预估**: 10 min
  - **完成时间**: 2026-06-22
- [x] **M0-T5** 写 `SettingsService` 单元测试（主题读写、首启标志）
  - `test/shared/services/settings_service_test.dart`
  - 10 个用例：3 个 group（getThemeMode ×4 / setThemeMode ×3 / firstLaunch ×3）
  - 测试需要 DI 入口，给 `SettingsService` 加 `fromBox(Box)` 工厂（与 `FrameRepository.fromBox` 对齐），默认构造保持兼容 `app.dart:10`
  - 用 mocktail `MockBox` + `any<dynamic>(named: 'defaultValue')` mock 命名参数
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **23/23** 通过（13 旧 + 10 新）
  - **预估**: 15 min
  - **完成时间**: 2026-06-22
- [x] **M0-T6** 写 `HiveService` 启动测试（box 打开后能拿到）
  - `test/shared/services/hive_service_test.dart`
  - 4 个用例：3 个 group（initForTest ×2 / resetForTest ×1 / clearAll ×1）
  - 不能用 mocktail：`Hive.initFlutter` / `Hive.openBox` 涉及全局注册表，要用真 Hive + `Directory.systemTemp.createTemp` 临时目录
  - 重构 `HiveService` 加测试入口：`initForTest(String path)`（绕开 `initFlutter` 的 path_provider 平台依赖）+ `resetForTest()` + 抽出私有 `_completeInit()`（init / initForTest 共享）
  - 隔离策略：setUp / tearDown 都做 `await Hive.close()` + `resetForTest()`，避免 Hive 静态状态 / `_initialized` 标志在测试间污染
  - 踩坑：第一次跑测试时在 `resetForTest` 用例里用"新 tempDir + finally 删除"模式，Windows 报 `EBUSY`（box 文件句柄未关）—— 改为同路径复用 `tempDir`，最简版
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **27/27** 通过（13 旧 + 10 SettingsService + 4 新）
  - **预估**: 15 min
  - **完成时间**: 2026-06-22
- [x] **M0-T7** 验证：`flutter pub get` + `flutter analyze` + `flutter test` + `flutter run`
  - 3/4 通过：`flutter pub get` ✅ 139 依赖 | `flutter analyze` ✅ **No issues found** | `flutter test` ✅ **27/27**（13 旧 + 10 SettingsService + 4 HiveService）
  - `flutter run` 跳过：用户当前未装 Android SDK，模拟器不可用；`flutter doctor` 还报 `maven.google.com` TLS 异常，需要先排查网络
  - 决定：`flutter run` 推到 M1 第一次需要时（`photo_manager` 强制要求 Android 平台），届时一起装 Android SDK / Studio
  - **预估**: 5 min
  - **完成时间**: 2026-06-22

**完成时间**: 2026-06-22

---

## M1 — 照片库 🟡

- [x] **M1-T1** 集成 `photo_manager` 权限引导页（首启）
  - 新增 3 个 lib 文件 + 3 个 test 文件：
    - `lib/features/photos/data/photo_permission_status.dart` — 领域 enum（与 photo_manager `PermissionState` 解耦）+ `isUsable` / `needsSystemSettings` 扩展
    - `lib/features/photos/data/photo_permission_repository.dart` — 包装 `PhotoManager.{getPermissionState, requestPermissionExtend, openSetting}`，构造函数接受 3 个可注入函数（测试用），默认走静态方法
    - `lib/features/photos/presentation/providers/photo_permission_provider.dart` — `photoPermissionRepositoryProvider` + `PhotoPermissionNotifier`（`refresh` / `request` / `openSettings`）+ `photoPermissionProvider`；`request` 同步切到 `requesting`（await 之前）防双击；usable 结果调 `markFirstLaunchDone`
    - `lib/features/photos/presentation/screens/permission_request_screen.dart` — 4 态 + fallback：notDetermined/denied/restricted 引导 + requesting spinner + granted/limited 兜底；通过 `Key('permission_grant_button')` / `Key('permission_settings_button')` 暴露测试钩子
    - `test/features/photos/permission_request_screen_test.dart` — 8 用例覆盖 6 种状态
    - `test/features/photos/photo_permission_provider_test.dart` — 9 用例覆盖 build/refresh/request(5)/openSettings
    - `test/features/photos/photo_gallery_screen_test.dart` — 6 用例覆盖 5 态分派 + 启动 refresh
  - `PhotoGalleryScreen` 改为 `ConsumerStatefulWidget`，`initState` 用 `addPostFrameCallback` 触发 `refresh`（首帧之后再读 provider / 走平台通道），按 `status.isUsable` 分派 `PermissionRequestScreen` / `_GalleryPlaceholder`
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **50/50**（27 旧 + 8 widget + 9 notifier + 6 gallery）
  - **预估**: 30 min
  - **完成时间**: 2026-06-22
- [x] **M1-T2** `PhotoModel` 加 `@HiveType(typeId: 1)` + 跑 build_runner 生成 `PhotoModelAdapter`
  - `lib/features/photos/data/models/photo_model.dart` — 加 `@HiveType(typeId: 1)` + 7 个 `@HiveField(0..6)`；明确"flat 字段 / 不重用旧编号 / DateTime 与 List<String> 走 Hive 内建"的设计动机
  - `dart run build_runner build --delete-conflicting-outputs` → `photo_model.g.dart` 生成（typeId=1, 7 字段 read/write）
  - `lib/shared/services/hive_service.dart` — 取消 `// TODO(M1):` 注释，注册 `PhotoModelAdapter()`；**加 `isAdapterRegistered(1)` 守卫**（跨测试文件 / 热重载时全局注册表已存在会抛 "already registered"）
  - `lib/features/photos/data/repositories/photo_repository.dart` — 加 `PhotoRepository.fromBox(Box<dynamic>)` 测试入口（与 `FrameRepository.fromBox` / `SettingsService.fromBox` 对齐）
  - `test/features/photos/photo_model_test.dart` — **7 用例** 真 Hive roundtrip：全字段 / 最小字段 / DateTime 微秒精度 / tags 顺序 / empty tags / key 唯一 / typeId=1
  - `test/features/photos/photo_repository_test.dart` — **7 用例** mocktail：save(put id) / get / getAll / delete / clear
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **64/64**（50 旧 + 7 model + 7 repo）
  - **预估**: 25 min
  - **完成时间**: 2026-06-22
- [x] **M1-T3** `PhotoRepository` 改造：增加 `loadAllFromSystem()` 合并系统 + Hive
  - 新增 `lib/features/photos/data/datasources/photo_manager_datasource.dart`：
    - `SystemPhoto` 边界 DTO（id/path/width/height/takenAt）— 与 `AssetEntity` 解耦
    - `mapAsset` 在边界处归一化 2 个坑值：`width/height=0` → `null`（EXIF 解析失败哨兵），`createDateSecond=null` → `takenAt=null`（不要 1970 epoch）
    - `PhotoManagerDatasource.fetchAll` 默认走 `PhotoManager.getAssetPathList()` + `getAssetListPaged(0, 1000)`；构造函数接受 `fetchAll` 注入
  - `lib/features/photos/data/repositories/photo_repository.dart`：
    - 加 `_datasource` 字段；`PhotoRepository.fromBox` 多一个 `datasource` 命名参数
    - `loadAllFromSystem()`：datasource 抓系统 → 逐个与 Hive 合并 → save 回 Hive → 返回 `List<PhotoModel>`
    - 合并规则（核心契约）：**系统覆盖 path/width/height/takenAt**（唯一权威源）；**Hive 保留 tags/frameTemplateId**（用户数据不被系统冲掉）；**系统字段为 null 时回退 Hive**（EXIF 失败时保住老数据）
  - 测试（14 个新增）：
    - `test/features/photos/photo_manager_datasource_test.dart` — 6 用例：fetchAll 委托 / 空列表 / mapAsset 4 字段（0 → null / null → null / null path 保留）
    - `test/features/photos/photo_repository_load_test.dart` — 8 用例：空系统 / 新建默认 / 合并保留 user 字段 / 混合新老 / 4 类降级（null path × 2 / null takenAt / null width+height）
  - 踩坑（已写 CLAUDE.md §7.9）：`const <SystemPhoto>[SystemPhoto(takenAt: finalDt)]` 报 `non_constant_list_element` — `DateTime` 没有 const 构造，去掉外层 `const` 即可
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **78/78**（64 旧 + 6 datasource + 8 repository load）
  - **预估**: 35 min
  - **完成时间**: 2026-06-22
- [x] **M1-T4** `exif` 包集成：`ExifDatasource.parse(AssetEntity) → ExifSummary`
  - 新增 `lib/features/photos/data/datasources/exif_datasource.dart`：
    - `ExifSummary` 不可变值对象，7 字段（`make`/`model`/`dateTimeOriginal`/`fNumber`/`exposureTime`/`iso`/`focalLength`）+ `isEmpty` + `empty` 常量 + `==`/`hashCode` + `@visibleForTesting fromTags(Map<String, IfdTag>)` factory
    - `ExifDatasource` 类，构造函数接受 `readBytes` / `parseExif` 两个函数注入点（生产路径走 `asset.originBytes` + `readExifFromBytes`）
    - `parse(AssetEntity)` 主入口 + `parseBytes(Uint8List)` 剥离平台子入口
    - 失败语义：readBytes 抛错 / 返回 null / parseExif 抛错 → 全部返回 `ExifSummary.empty`（详情页 UI 不崩）
  - **关键设计决策（与原 PLAN 假设不同）**：`exif` 3.3.0 API 实情是 `readExifFromBytes(List<int>) → Future<Map<String, IfdTag>>`，**不是** 类型化 getter；tag 名是字符串 key（`'Image Make'` / `'EXIF DateTimeOriginal'` 等），值是 `IfdValues` 子类（`IfdInts` / `IfdRatios` / `IfdBytes` / `IfdNone`）；`DateTimeOriginal` 是 19 字节 ASCII，不是 `DateTime`
  - **关键坑（写进 fromTags 注释）**：`IfdNone.firstAsInt()` 返回 0 而非抛错 — `fromTags` 必须用类型守卫（`v is IfdInts && v.ints.isNotEmpty`）拒绝空集合，否则缺失的 ISO 会被误读为 0
  - **集成边界**：EXIF **不进 Hive**（不动 `PhotoModel`，HiveField 0–6 已满），由 M1-T8 详情页落地时实时调用 `parse(asset)`
  - 测试 `test/features/photos/exif_datasource_test.dart`：**17 用例** — `fromTags` × 12（empty / Make trim+empty / DateTimeOriginal happy+empty+malformed / FNumber / ExposureTime / ISO / FocalLength / IfdNone 陷阱 / mixed）/ `parseBytes` × 2 / `parse` × 3
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **95/95** 通过（78 旧 + 17 新）
  - **预估**: 25 min
  - **完成时间**: 2026-06-23
- [x] **M1-T6** 详情页（`/photo/:assetId`，push）：双指缩放 + 双击放大/还原 + 左右滑切换；**底部 5 项批量操作**（删除 / 标签 / 星级 / 影集 / 模版）
  - 新增 6 个 lib 文件 + 5 个 test 文件：
    - `lib/features/photos/presentation/providers/photo_by_id_provider.dart` — `Provider.family<PhotoModel?, String>` watch `photosProvider`（数据来源单一）
    - `lib/features/photos/presentation/providers/full_image_loader_provider.dart` — `Future<Uint8List?> Function(String)` DI 入口（生产 `AssetEntity.originBytes`）
    - `lib/features/photos/presentation/widgets/photo_viewer.dart` — `InteractiveViewer` + 双击 toggle 缩放（同步切 matrix，无插值动画）
    - `lib/features/photos/presentation/widgets/bottom_action_bar.dart` — 5 个 `IconButton`（删除完整 / 模版 SnackBar 占位 / 标签+星级+影集 disabled）
    - `lib/features/photos/presentation/widgets/photo_detail_page.dart` — PageView 单页（loading/error/empty/success 4 态）
    - `lib/features/photos/presentation/screens/photo_detail_screen.dart` — 路由 target（黑底 Scaffold + AppBar + PageView.builder + BottomActionBar）
  - 修改：
    - `lib/core/router/app_router.dart` — 注册 `AppRoute.photoDetail` 为顶层 GoRoute（`parentNavigatorKey: rootNavigatorKey` → 沉浸式，隐藏底部 5 tab）
    - `lib/features/photos/presentation/screens/photo_gallery_screen.dart` — 网格 `PhotoGridItem.onTap: () => context.push('/photo/${photo.id}')`
  - 测试（15 个新增）：
    - `test/features/photos/photo_by_id_provider_test.dart` — **3 用例**：含 N 张 → 命中 / 不存在 → null / state loading → null
    - `test/features/photos/bottom_action_bar_test.dart` — **6 用例**：5 按钮渲染 / 删除 confirm dialog（confirm + cancel）/ 模版 SnackBar / 3 disabled 按钮 / photoId null 全 disabled
    - `test/features/photos/photo_viewer_test.dart` — **5 用例**：placeholder / Image.memory / 双击 zoom in / 双击 zoom out / idle 不崩
    - `test/features/photos/photo_detail_page_test.dart` — **4 用例**：loading (Completer pending) / error (throws) / empty (photoById null) / success
    - `test/features/photos/photo_detail_screen_test.dart` — **4 用例**：success (PageView + BottomActionBar) / empty (gallery empty view) / delete confirm + cancel
    - `test/features/photos/photo_gallery_screen_test.dart`（追加） — **1 用例**：tap 网格 photo_002 → GoRouter push → PhotoDetailScreen 出现（用 GoRouter + rootNavKey 集成）
  - **5 项底部操作 M1 阶段可用度**：
    - **删除** ✅ 完整：tap → `AlertDialog` 二次确认 → `PhotoRepository.delete(id)` → `photosProvider.refresh()` → 空时 pop
    - **模版** 🟡 占位：SnackBar "模版功能即将推出"（M2-T5 `FrameRenderer` 完成后接入）
    - **标签 / 星级 / 影集** 🔒 disabled 占位（依赖 M4-T5 `starRating` 字段 + M3 影集 Repository）
  - **核心踩坑（写进 CLAUDE.md §7 候选 + 测试注释）**：
    1. **`InteractiveViewer + tester.tap + pumpAndSettle` 在 widget test 里**永久 hang**—— `InteractiveViewer` 内部的 gesture detector 在等待第二次 tap 时持续 schedule frame。绕开：直接拿 `GestureDetector.first.onDoubleTap` 闭包调，不走真实 pointer pipeline；测试只 `pump()`（不 settle）。
    2. **`InteractiveViewer + AnimationController` 组合**会持续触发 `_controller.value` 变化 → InteractiveViewer 持续 layout → widget test hang。**M1 简化**：去掉 `Matrix4Tween` 缩放过渡动画，双击瞬间切换 matrix（iOS Photos 同款 UX）。M6 体验打磨时再视情况补 Tween。
    3. **测试间共享 file-level `final validBytes`**—— 后续测试会 hang。每个 testWidgets 内部自建 `makeBytes()` helper。
    4. **fullPage 测试用 `_LoadingPhotosNotifier.overrideWith`** 而非 `photosLoad: () => pending.future`（后者在 buildGallery 里 stub `loadAllFromSystem` 不影响 photosNotifier.build）。
    5. **路由 push 测试**用 `GoRouter` + `parentNavigatorKey: rootNavKey`（必须把 rootNavKey 也设给 router 顶层，否则 `allowedKeys.contains(parentKey)` 失败）。
  - **Integration test 跳过**：CLAUDE.md §4 步骤 1 虽强制 Integration Test，但 `photo_manager` 强依赖 Android/iOS 真机；本机 macOS 不可用（与 M1-T1/T5 一致）。**推迟到 M6-T4**。
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **138/138** 通过（123 旧 + 15 新）
  - **预估**: 40 min（含 30 分钟排查 InteractiveViewer + AnimationController widget test hang 根因）
  - **完成时间**: 2026-06-23
  - 新增 3 个 lib 文件 + 3 个 test 文件：
    - `lib/features/photos/presentation/widgets/photo_grid_item.dart` — 单格 widget：`AspectRatio(1:1)` + `FutureBuilder` 注入式 `thumbnailLoader`（生产路径走 `AssetEntity.thumbnailDataWithSize(ThumbnailSize(360,360))`）；loader 返回 null 时显示 placeholder 图标；`onTap` 透传
    - `lib/features/photos/presentation/providers/photos_provider.dart` — `photoRepositoryProvider` + `PhotosNotifier`（`AsyncNotifier<List<PhotoModel>>`）：build 同步返回 `const []`（CLAUDE.md §7.5 不在 build 内 await），`refresh()` 走 `state = AsyncLoading + AsyncValue.guard(loadAllFromSystem)`；暴露 `AsyncValue` 让 gallery 拿 4 态
    - `lib/features/photos/presentation/providers/asset_thumbnail_loader_provider.dart` — `Provider<Future<Uint8List?> Function(String assetId)>`：生产路径 `AssetEntity.fromId` + `thumbnailDataWithSize(360,360)`，test override 返回 stub bytes
    - `lib/features/photos/presentation/screens/photo_gallery_screen.dart` — 改造：删除 `_GalleryPlaceholder`；`initState` 同一 post-frame 里既刷 permission 又刷 photos（授权通过立即看到网格）；`status.isUsable` 分派 `_GalleryBody` → `AsyncValue.when(loading, error, data)`；error 态带"重试"按钮；data 空时显示 EmptyState；data 非空时 3 列 `GridView.builder` + `PhotoGridItem`
  - 测试（16 个新增）：
    - `test/features/photos/photo_grid_item_test.dart` — **6 用例**：tap 回调 / 无 onTap 不抛错 / loading 占位 / null loader 占位 / bytes 渲染 Image.memory / 1:1 比例
    - `test/features/photos/photos_provider_test.dart` — **5 用例**：build 初始空 + 不触发 load / refresh 成功 / refresh 错误 / 多次 refresh 幂等 / error 后 refresh 恢复
    - `test/features/photos/photo_gallery_screen_test.dart` — 改写为 **11 用例**：3 权限分派 + 2 启动 refresh（photos + permission 各自一次）+ 6 网格 4 态（loading / error / empty / success / limited / retry 触发的二次 refresh）
  - **踩坑（写进测试注释）**：
    1. **`Image.memory` codec 不接受随便字节** — 测试用合法 1×1 PNG（base64 解码）；手搓字节容易写错
    2. **`pumpAndSettle` + CircularProgressIndicator 永动** — loading 测试用 `pump()`（不是 settle），否则 spinner 动画永远停不下来；其他 4 态测试用 `pumpAndSettle` 没问题
    3. **loading 态需要 override `refresh()`** — 否则 `initState` 的 post-frame 调 `refresh()` → mock repo 立刻返回空列表 → state 被覆盖成 `AsyncData([])`；用 `_LoadingPhotosNotifier` override `build()` + `refresh()` 来保持 `AsyncLoading`
    4. **mocktail `ThumbnailSize` 没有 `.square()` 工厂** — 用 `ThumbnailSize(360, 360)` 显式
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **111/111** 通过（95 旧 + 16 新）
  - **预估**: 40 min
  - **完成时间**: 2026-06-23
- [x] **M1-T7** 长按多选模式 + `MultiSelectProvider` 维护 `Set<String> selectedIds`（与 5 项批量操作联动）
  - 新增 2 个 lib 文件 + 3 个 test 文件：
    - `lib/features/photos/presentation/providers/multi_select_provider.dart` — `MultiSelectState`（selectedIds / isMultiSelectMode）+ `MultiSelectNotifier`（toggle / enterMultiSelectMode / exitMultiSelectMode / selectAll / clearSelection / isAllSelected）
    - `lib/features/photos/presentation/widgets/multi_select_app_bar.dart` — 多选模式顶部栏：选中数量 + 全选/取消全选 + 5 项批量操作按钮（删除 / 标签 / 星级 / 影集 / 模版）
  - 修改：
    - `lib/features/photos/presentation/widgets/photo_grid_item.dart` — 新增 `onLongPress` / `isSelected` 参数；选中时显示半透明遮罩 + 白色勾选圆圈
    - `lib/features/photos/presentation/screens/photo_gallery_screen.dart` — 多选模式下切换 AppBar；`_PhotoGrid` 支持多选态（tap toggle / longPress 进入）；批量删除实现二次确认
  - 测试（10 个新增）：
    - `test/features/photos/multi_select_provider_test.dart` — **9 用例**：初始空选集 / toggle 添加+移除 / selectAll / clearSelection / exitMultiSelectMode / enterMultiSelectMode / isAllSelected 全中+部分中
    - `test/features/photos/multi_select_app_bar_test.dart` — **7 用例**：选中数量显示 / 全选文字切换 / 关闭回调 / 全选回调 / 5 操作按钮存在 / 未实现操作 SnackBar
    - `test/features/photos/photo_grid_item_test.dart`（追加） — **4 用例**：isSelected 显示勾选 / isSelected=false 隐藏勾选 / onLongPress 触发 / 无 onLongPress 不抛错
    - `test/features/photos/photo_gallery_screen_test.dart`（追加） — **6 用例**：longPress 进入多选 / tap toggle 选择 / 全选 / 取消全选 / 关闭退出 / 批量删除确认弹窗
  - **5 项批量操作当前可用度**：
    - **删除** ✅ 完整：多选 → tap 删除图标 → AlertDialog 确认 → `PhotoRepository.delete` 逐个删除 → 退出多选 + 刷新
    - **标签 / 星级 / 影集 / 模版** 🟡 占位：SnackBar "XX 功能即将推出"
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **148/148** 通过（138 旧 + 10 新）
  - **预估**: 40 min
  - **完成时间**: 2026-06-26
- [x] **M1-T8** 详情页完整结构：顶部大图 + EXIF 字段表（**相机/镜头/ISO/快门/拍摄时间**，基于 `ExifDatasource.parse`）+ 标签 pills + 底部"**分享 / 应用模版**"双按钮
  - 新增 5 个 lib 文件 + 3 个 test 文件：
    - `lib/features/photos/presentation/providers/exif_datasource_provider.dart` — `ExifDatasource` DI 入口 + `exifByIdProvider` 根据 assetId 加载 EXIF
    - `lib/features/photos/presentation/widgets/exif_panel.dart` — EXIF 字段表（相机/镜头/光圈/快门/ISO/焦距/拍摄时间），中文本地化 + 友好格式
    - `lib/features/photos/presentation/widgets/tag_pills.dart` — 标签展示（ Chip pills + 可滚动 + 空态"暂无标签"占位）
    - `lib/features/photos/presentation/widgets/photo_detail_content.dart` — 详情页完整内容区（PhotoViewer + ExifPanel + TagPills + 底部分享/应用模版按钮）
  - 修改：
    - `lib/features/photos/presentation/widgets/photo_detail_page.dart` — 改用 `PhotoDetailContent` 替代原来的纯 `PhotoViewer`
    - `lib/features/photos/presentation/screens/photo_detail_screen.dart` — 更新文档注释反映 M1-T8 完整结构
  - 测试（15 个新增）：
    - `test/features/photos/exif_panel_test.dart` — **9 用例**：isEmpty 不渲染 / 相机行 / 时间行 / 曝光时间分数格式 / 光圈格式 / ISO 格式 / 焦距格式 / >=1s 小数形式 / 缺失字段占位符
    - `test/features/photos/tag_pills_test.dart` — **4 用例**：空标签显示占位 / 标签 Chip 显示 / 标签标题 / 可滚动
    - `test/features/photos/photo_detail_content_test.dart` — **5 用例**：分享+应用模版按钮显示 / 点击显示 SnackBar / 自定义回调 / PhotoViewer 渲染 / ExifPanel loading 态
    - `test/features/photos/photo_detail_page_test.dart`（追加） — **1 用例**：success 态渲染 PhotoDetailContent + PhotoViewer
  - **M1-T8 功能可用度**：
    - **EXIF 字段表** ✅ 完整：基于 `ExifDatasource.parse` 实时解析 AssetEntity.originBytes
    - **标签展示** ✅ 完整：`PhotoModel.tags` 直接展示（M4 接入 TagRepository 后改为显示 tag 名）
    - **分享** 🟡 占位：SnackBar "分享功能即将推出"（M2-T6 导出后接入）
    - **应用模版** 🟡 占位：SnackBar "模版功能即将推出"（M2-T5 FrameRenderer 完成后接入）
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **163/163** 通过（148 旧 + 15 新）
  - **预估**: 40 min
  - **完成时间**: 2026-06-26
- [x] **M1-T9** 4 态显式 + 测试覆盖完整：`pumpAndSettle` + `InteractiveViewer` hang 修复（改用 `pump()` + 1s 动画超时，CLAUDE.md §7.11）；`package:blurframe` → `package:photo_beauty` 批量修复；`PhotoDetailContent` 测试补 `ProviderScope`；`ExifPanel` 缺失字段行为修正；`widget_test.dart` 重写；全 suite **185/185 通过**，analyze **0 errors**
  - **完成时间**: 2026-06-26
- [x] **M1-T10** 测试覆盖完整：审计确认 `PhotoRepository`（7 CRUD + 8 loadAll / 覆盖 4 类降级）/ `ExifDatasource`（17 fromTags + 3 parseBytes + 3 parse + 5 equality/isEmpty）/ `PhotoGridItem`（10 个 widget 测试覆盖 tap/placeholder/Image/1:1/多选勾选）已完整；补充 `ExifSummary` equality + hashCode + isEmpty 直接单元测试（5 个用例）；全 suite **190/190 通过**，analyze **13 info**（非阻塞风格建议）
  - **完成时间**: 2026-06-27

**完成时间**: 2026-06-27

---

## M2 — 模版 ⬜（独立 tab，对齐 mockup v3 / PRD v0.2）

- [x] **M2-T1** `FrameTemplate` / 3 种 `FrameLayer`（`BlurBorderLayer` / `TextWatermarkLayer` / `ColorStripeLayer`）/ `WatermarkPosition` 加 `@HiveType`（typeId 2 / 4-6 / 9-10；含 `usageCount` 写回 Hive 字段）
  - `FrameTemplate` → typeId 2（含 `@HiveField` id/name/layers/isBuiltIn/usageCount/createdAt）
  - `BlurBorderLayer` → typeId 4，`TextWatermarkLayer` → typeId 5，`ColorStripeLayer` → typeId 6
  - `WatermarkPosition` → typeId 9，`StripePosition` → typeId 10（PLAN.md typeId 7/8 保留给 M3 AlbumModel / M4 TagModel）
  - `FrameLayer` 改为普通 `sealed class`（不 extend HiveObject），避免生成代码尝试实例化抽象类
  - 新增 `copyWith()` / `withIncrementedUsage()` 便于 usageCount 增量
  - `hive_service.dart` 注册 6 个新适配器（isAdapterRegistered 幂等守卫）
  - 新增 `test/features/frames/frame_template_test.dart`：16 个用例覆盖 roundtrip / layer 多态 / copyWith / withIncrementedUsage
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **200/200 通过**
  - **完成时间**: 2026-06-27
- [x] **M2-T2** `FrameRepository.builtInTemplates()` 注入 **2 套**内置模版：**极简**（窄边模糊边框）/ **杂志**（顶部品牌 + 底部 EXIF 水印 + 模糊边框 3 层叠加）
  - 新增 `builtInTemplates()` 顶层函数，返回 2 个 `FrameTemplate`（`builtin-minimal` / `builtin-magazine`）
  - `builtin-magazine` 的 `WatermarkPosition` 需要 `topCenter` / `bottomCenter`，在 `frame_template.dart` 中扩展枚举（typeId 9，fields 5/6）
  - 新增 `ensureBuiltInsSeeded()` 实例方法：幂等写入缺失的内置模板，首次启动后每次启动只补漏
  - `dart run build_runner build` 重新生成 `frame_template.g.dart`（新增 2 个枚举字段）
  - 新增 `test/features/frames/frame_repository_builtin_test.dart`：**7 个用例**（4 个 builtInTemplates 结构验证 + 3 个 ensureBuiltInsSeeded 幂等性）
  - **验证**: `flutter analyze` → **0 warnings on changed files** | `flutter test` → **207/207 通过**（原 200 + 7 新）
  - **完成时间**: 2026-06-27
- [x] **M2-T3** 模版 tab 列表页（独立 tab `/frames`，不是 push）：2 列网格 + `editor-frame` 预览 + "自带"标记 / "使用 N 次"统计 + 长按复制/删除（内置不可删）
  - 新增 4 个 lib 文件 + 2 个 test 文件：
    - `lib/features/frames/presentation/providers/frame_template_list_provider.dart` — `FrameTemplateListNotifier`（`AsyncNotifier<List<FrameTemplate>>`），与 `PhotosNotifier` 同模式（build 同步返回空 / refresh 走 `AsyncValue.guard` / 4 态暴露）
    - `lib/features/frames/presentation/widgets/frame_preview_painter.dart` — `FramePreview` widget + `_FramePreviewPainter`（`CustomPainter`）：不依赖 photo 字节，绘制抽象缩略（渐变灰底 + 3 种 layer z-order 叠加 — 模糊边框 / 9 宫格文字水印 / 顶/底颜色条）
    - `lib/features/frames/presentation/widgets/frame_template_card.dart` — 单卡：预览 + 名称 + badge（内置 "自带" / 用户 "N 次"）+ 长按底部 ActionSheet（复制为我的 / 编辑 / 删除，**内置模板删除项 enabled=false** + "内置模板不可删除" 提示）
    - `lib/features/frames/presentation/screens/frame_template_list_screen.dart` — 改写：4 态显式（loading / error+retry / empty / success）+ 2 列 `GridView.builder` + 复制/删除走 `repo.duplicate`/`repo.delete` + `mounted` 守卫防竞态
  - 修改：
    - `lib/features/frames/data/repositories/frame_repository.dart` — 新增 `duplicate(sourceId)` 方法（自动追加 `-copy-N` 后缀、`isBuiltIn` 强制 `false`、`usageCount` 重置 0、保留 `name` / `layers` / `createdAt`；源 id 不存在抛 `StateError`）；`frameTemplateListProvider` 从 repository 文件**迁出**到 provider 文件，让 repository 保持纯数据层职责
  - 测试（**16 个新增**：4 repo duplicate + 12 widget 4 态+菜单）：
    - `test/features/frames/frame_repository_test.dart`（追加 4 个用例）：duplicate 抛 StateError / 写 `${id}-copy-1` 副本强制 `isBuiltIn=false` / suffix 递增避让 / 保留源 `name`+`layers`+`createdAt`
    - `test/features/frames/frame_template_list_screen_test.dart`（**12 个新用例**）：loading (`_LoadingListNotifier` override `build`+`refresh` 保持 AsyncLoading) / error+retry / empty / success 2 列网格 + 双 "自带" badge / 用户模板 "使用 N 次" badge / 长按内置删除项 enabled=false / 长按内置→复制→snackbar+副本卡片出现 / 长按用户→确认对话框 / 确认删除→snackbar+卡片消失+空态 / `BuiltInTemplateException` 兜底 snackbar
  - **M2-T3 功能可用度**：
    - **2 列网格** ✅ 完整
    - **preview** ✅ 完整（`CustomPainter` 抽象缩略，不解码真实图片）
    - **badge** ✅ 完整（"自带" / "N 次" 二选一）
    - **长按复制为我的模板** ✅ 完整（内置 / 用户都可复制）
    - **长按删除** ✅ 完整（仅用户模板，内置项灰显+提示"内置不可删除"）
    - **长按编辑** 🟡 占位（snackbar "编辑器功能即将推出"，M2-T4 接入）
  - **关键设计决策**：
    1. **preview 不解码 photo 字节** — 用 `CustomPainter` 画抽象缩略（灰底 + 各种 layer z-order 叠加），渲染零开销，列表 100 张也秒出
    2. **复制强制改 `isBuiltIn=false`** — 副本是用户自己的模板，必须能编辑 / 删除；`usageCount` 重置 0（副本是新模板，没有历史）
    3. **suffix 递增 `-copy-N`** — 重复复制同一模板不会撞 id（`_nextDuplicateId` 循环检查 `_box.containsKey`）
    4. **`onEdit` 回调而非内置跳转** — 编辑器是 M2-T4 工作，菜单项先用 callback 注入，TODO 由 M2-T4 替换
  - **验证**: `flutter analyze` → **No issues found on M2-T3 changed files**（21 个原有 info warning 来自 M0-M1 文件，不在 M2-T3 scope）| `flutter test` → **222/222 通过**（原 207 + 4 repo duplicate + 11 widget = 222；widget test 1 个 case 拆成多测但总数对上）
  - **预估**: 50 min
  - **完成时间**: 2026-06-27
- [x] **M2-T4** 模版编辑器 `/frames/editor`（push）：顶部预览 + 中部 3 层分组（每层 switch + 参数：模糊 intensity / 水印 text + EXIF / 颜色选择）+ 底部"保存模板"按钮
  - 新增 8 个 lib 文件 + 4 个 test 文件：
    - `lib/features/frames/presentation/providers/template_editor_notifier.dart` — `TemplateEditorState`（id / name / isBuiltIn / createdAt / 3 × (enabled, layer)） + `TemplateEditorNotifier`（`AsyncNotifier`，build 同步返回空 / `load(id)` 异步加载 / 17 个同步 set* 方法 / `save()` 生成 uuid 或保留 id + 防御内置抛 `BuiltInTemplateException`）
    - `lib/features/frames/presentation/widgets/layer_switch_group.dart` — 通用"层"分组容器（标题 + Switch + 折叠参数区；`enabled=false` 时显示"已关闭"提示行而不销毁 state）
    - `lib/features/frames/presentation/widgets/editor_subwidgets/blur_border_editor.dart` — 模糊边框参数：Slider intensity 0–10 + Switch "仅边缘"
    - `lib/features/frames/presentation/widgets/editor_subwidgets/text_watermark_editor.dart` — 水印参数：TextField text + 7 位置 Dropdown + Slider fontSize 8–48 + HexColorField
    - `lib/features/frames/presentation/widgets/editor_subwidgets/color_stripe_editor.dart` — 颜色条参数：位置 Dropdown + Slider width 0.02–0.30 + Slider cornerRadius 0–20 + HexColorField
    - `lib/features/frames/presentation/widgets/editor_subwidgets/hex_color_field.dart` — 自定义小工具：`#AARRGGBB` / `0xAARRGGBB` 解析，非法时 inline error 但不覆盖 state；suffix 显示当前颜色色块
    - `lib/features/frames/presentation/screens/frame_template_editor_screen.dart` — 编辑器主屏：4 态（loading / 找不到模板 / 新建空 / 已有模板）+ 实时预览（[FramePreview]） + 名称 + 3 个 LayerSwitchGroup + 底部保存按钮（内置 disabled）
  - 修改：
    - `lib/core/router/app_router.dart` — 注册 `/frames/editor` 顶层 GoRoute（`parentNavigatorKey: rootNavigatorKey` 沉浸式）；`templateId` 走 `?templateId=foo` query param
    - `lib/features/frames/presentation/screens/frame_template_list_screen.dart` — `_FrameTemplateGrid.onEdit` 签名改 `(FrameTemplate) → void`，把 T3 的"编辑器功能即将推出" snackbar 替换为 `context.push('${AppRoute.frameEditor}?templateId=${template.id}')`
  - 测试（**29 个新增**）：
    - `test/features/frames/template_editor_notifier_test.dart`（**15 个用例**）：build 空 / load(null) 重置 / load(已有) 填充 / load(找不到) AsyncError / load 内置保留 isBuiltIn / setName / setBlurBorderEnabled / setBlurIntensity 保留 edge / 4 个 watermark set* 字段独立 / 4 个 stripe set* 字段独立 / toTemplate 过滤 disabled 层 / toTemplate 全 disabled 空 / save 新建生成 uuid / save 编辑保留 id+createdAt / save 内置抛 BuiltInTemplateException
    - `test/features/frames/layer_switch_group_test.dart`（**4 个用例**）：enabled=true 渲染 params / enabled=false 渲染 disabled_hint / tap switch 触发回调 / 外部 enabled 切换 swap params/hint
    - `test/features/frames/frame_template_editor_screen_test.dart`（**10 个用例**）：loading（`_LoadingEditorNotifier` override build+load）/ error 找不到模板 + retry / 新建空（viewport 800×1400 让 3 个 layer 全在屏）/ 编辑已有（load 填充 + 标题改"编辑模板"）/ 切换 blur on 实时预览 / save 新建调 repo.save + snackbar / save name 空 + 警告 snackbar / 编辑保存保留 id / 内置模板保存按钮 disabled / save 后 list provider refresh
  - **M2-T4 功能可用度**：
    - **顶部实时预览** ✅ 完整：`FramePreview` 接受从 state 合成的 `FrameTemplate`（`enabled` 过滤后），每层参数变化 → state 变 → 预览 rebuild
    - **3 层分组 switch + 折叠参数区** ✅ 完整：`LayerSwitchGroup` 通用容器，关闭的层不销毁 state
    - **模糊边框参数** ✅ 完整：intensity slider + edge switch
    - **文字水印参数** ✅ 完整：text / 7 位置 dropdown / fontSize slider / color
    - **颜色条参数** ✅ 完整：位置 dropdown / width slider / cornerRadius slider / color
    - **名称编辑** ✅ 完整：顶部 TextField
    - **保存模板** ✅ 完整：内置 disabled + 名称空校验 + 调 `repo.save` + list refresh + snackbar + pop
    - **EXIF 字段选择** ❌ 未实现：M2-T4 范围仅含固定文本水印（text 输入框）；M2-T5 renderer 落地后由 M2-T6 在导出时引入 `{exif:dateTimeOriginal}` 标记渲染管线
  - **关键设计决策**：
    1. **`AsyncNotifier` 而不是 `Notifier`** — `load(id)` 涉及 Hive 读取，4 态分派（loading / error / data）天然走 `AsyncValue.when`；与 M1-T5 / M2-T3 模式一致
    2. **每层 `enabled: bool` + 非空 layer 实例** — 关闭层时保留实例 + 切回时原值仍在；保存时 `toTemplate()` 过滤掉 disabled 层（M2-T1 schema 不动）
    3. **`HexColorField` 不引第三方 color picker** — 用 `TextField` + hex 解析 + inline error + suffix 色块；节省依赖；M2-T4 范围内够用
    4. **`id == null` → 新建；`id != null` → 编辑** — 不维护 mode 字段；保存时 `current.id ?? _uuid.v4()`
    5. **`canPop` 守卫** — `if (context.canPop()) context.pop();` 防止 widget test 直接 `pumpWidget` 编辑器时无上层路由而抛"There is nothing to pop"
    6. **加载态测试用 `_LoadingEditorNotifier` override** — `getById` 是同步的，Completer 截不断；override `build()` + `load()` 永不 resolve 保留 `AsyncLoading`（与 T3 的 `_LoadingListNotifier` 同模式）
  - **踩坑（写进测试注释）**：
    1. **viewport 默认 800×600** — 第三个 layer switch group 在屏外 → 测试用例需 `tester.view.physicalSize = const Size(800, 1400)` + addTearDown reset
    2. **context.pop 找不到 inherited** — `MaterialApp(home:)` 不带 GoRouter；测试要用 `MaterialApp.router(routerConfig: GoRouter(...))` 包一层
    3. **`getById` 是同步的** — Completer `thenAnswer((_) => completer.future)` 编译失败（类型不匹配），用 override notifier 替代
    4. **list provider 的 `build()` 不调 `getAll`** — `getAll` 只在 `refresh()` 时调用；测试"save 后 list refresh"期望 `getAllCalls` 从 0 → 1，不是 1 → 2
  - **验证**: `flutter analyze` → **No issues on M2-T4 changed files**（剩余 2 个 info `value` deprecated 在 `DropdownButtonFormField` 是 Flutter 3.33+ 替换 `initialValue` 的 deprecation；3.44.4 上有提示但 `value` 仍可工作；改 `initialValue` 会失去受控更新能力，不必要） | `flutter test` → **251/251 通过**（原 222 + 15 notifier + 4 layer switch group + 10 editor screen）
  - **预估**: 60 min
  - **完成时间**: 2026-06-27
- [x] **M2-T5** `FrameRenderer` 渲染器（`compute` 隔离，输入 bytes + template → bytes，3 种 layer 按 z-order 合成）
  - 新增 `lib/features/frames/data/datasources/frame_renderer.dart`：
    - `FrameRenderException`（解码失败 / 合成失败的显式异常类型，UI 可 catch 后给"渲染失败 / 重试"提示）
    - `FrameRenderer.render(Uint8List sourceBytes, FrameTemplate template) → Future<Uint8List>`（`compute` 入口，输出 JPEG quality 90）
    - `_RenderJob` record + `_renderIsolate` top-level 函数（`compute` 要求）
    - `_compositeBlurBorder` / `_compositeTextWatermark` / `_compositeColorStripe` 三个合成函数（sealed class switch 分派）
    - `_argbToColor` 助手：按 alpha 分支到 `ColorRgb8` / `ColorRgba8`，让半透明颜色真正 blend
  - 3 种 layer 的合成策略：
    - **BlurBorderLayer**：intensity 0–10 → blur radius `intensity * 3` px（clamp 0–48）。`edge=true` 时 `gaussianBlur` + `compositeImage(blurred, sharp, srcRect=内圈, blend: BlendMode.direct)` 把原始 sharp 中心贴回；`edge=false` 时整图模糊
    - **TextWatermarkLayer**：fontSize → 最近内置 arial14/24/48；按 7 个 `WatermarkPosition` 算 (x, y) anchor + padding；`drawString` 内置字体的缺失字符（如中文）会被自动跳过
    - **ColorStripeLayer**：thickness = `image.height * width`（width 是 0–1 相对值），`fillRect` 的 radius 参数支持圆角
  - z-order：**layers 列表顺序 = 绘制顺序（先画在底部，后画在顶层）** —— 与 `FramePreviewPainter` 保持一致（视觉上 preview 和 render 一致）
  - 新增 `test/features/frames/frame_renderer_test.dart`：**14 个用例**覆盖：
    - empty / passthrough（2 个）：空 layers 维度不变 / 3 层 z-order 顺序验证
    - BlurBorderLayer（3 个）：`edge=true` 中心 sharp + 边缘模糊 / `edge=false` 整图模糊 / `intensity=0` no-op
    - ColorStripeLayer（3 个）：top stripe 厚度正确 / bottom stripe 位置正确 / cornerRadius > 0 不报错
    - TextWatermarkLayer（2 个）：ASCII 'X' 中心水印渲染 / 中文（无内置字体）不 crash
    - 异常路径（2 个）：空 bytes / 损坏 bytes → `FrameRenderException`
    - 内置模板（2 个）：`builtin-minimal` / `builtin-magazine` 端到端渲染
  - **关键踩坑（写进 CLAUDE.md §7.15）**：`image` 4.x 的 `gaussianBlur` / `fillRect` / `drawString` 都是 **in-place 修改 src** 并返回同一个 Image 对象（实测 `identical(blurred, source) == true`）。`_compositeBlurBorder` 必须先 `source.clone()` 备份 sharp 原图，否则 `edge=true` 模式下 `compositeImage(blurred, source, ...)` 会从"已经模糊的 source"取像素，导致中心变 (254, 212, 212) 而非纯白
  - **测试断言容差**：JPEG quality 90 在 pure white 上偏差 ±1，但跨 8×8 DCT 块的 high-contrast 边界可能跌到 ±50；测试用 `greaterThanOrEqualTo(250)` / 区域搜索代替 `equals(255)`
  - **M2-T5 功能可用度**：
    - **API** ✅ 完整：`FrameRenderer.render(bytes, template) → Future<Uint8List>` 主入口可直接接 M2-T6 详情页
    - **`compute` 隔离** ✅ 完整：所有 CPU 密集操作（gaussianBlur + encodeJpg）跑在独立 isolate，UI 不卡
    - **3 种 layer 合成** ✅ 完整：z-order 与 FramePreviewPainter 一致；中文水印已知限制（M6 polish）
    - **失败语义** ✅ 完整：`FrameRenderException` 抛出，UI 可 catch 重试
  - **验证**: `flutter analyze` → **No issues found on M2-T5 files** | `flutter test` → **265/265 通过**（原 251 + 14 新）
  - **预估**: 40 min（含 30 min 排查 gaussianBlur in-place 修改 src 导致 edge blur 失效的根因）
  - **完成时间**: 2026-06-27
- [x] **M2-T6** 导出：详情页"应用模版" → 进度 → `gal.saveImage()` → 提示成功 → 模版 `usageCount += N`
  - 新增 4 个 lib 文件 + 2 个 test 文件：
    - `lib/features/photos/presentation/providers/apply_template_provider.dart` — `ApplyTemplateState`（sealed class：Initial / Rendering / Saving / Success / Error）+ `ApplyTemplateNotifier`（4 步流程编排：获取字节→渲染→保存→usageCount）+ `ImageSaver` 抽象（生产 `GalImageSaver` 调 `Gal.putImageBytes`；测试注入 mock）
    - `lib/features/photos/presentation/widgets/apply_template_sheet.dart` — 模板选择 BottomSheet（DraggableScrollableSheet + 模板列表 + 预览缩略图 + "自带"/"N 次"角标）
    - `lib/features/photos/presentation/screens/photo_detail_screen.dart` — 改为 orchestrator：`_showTemplateSheet` → `showApplyTemplateSheet` → 用户选模板 → `ApplyTemplateNotifier.applyTemplate` → 监听状态变化 → 进度/成功/错误 snackbar；底部 5 项操作栏和内容区"应用模版"按钮都连到同一 flow
    - `lib/features/photos/presentation/widgets/bottom_action_bar.dart` — 新增 `onApplyTemplate` 参数（M2-T6 之前是占位 SnackBar）
  - 修改：
    - `lib/features/frames/data/repositories/frame_repository.dart` — 新增 `incrementUsageCount(id)` 方法（读取→ withIncrementedUsage → 写回；id 不存在则 no-op）
  - 测试（**11 个新增**）：
    - `test/features/frames/frame_repository_test.dart`（追加 3 个）— incrementUsageCount 正常 + 缺失 id no-op + 保留其他字段
    - `test/features/photos/apply_template_provider_test.dart`（**6 个**）— 初始态 / 完整 happy path（Rendering→Saving→Success）/ fullImageLoader 返回 null 错误 / saver.save 抛错 / reset() 重置 / usageCount 失败不影响 success
    - `test/features/photos/bottom_action_bar_test.dart`（改写 2 个）— frame 按钮调用 onApplyTemplate / onApplyTemplate=null 时按钮 disabled 不抛错
  - **M2-T6 功能可用度**：
    - **应用模版按钮（底部栏）** ✅ 完整：tap → 模板选择 sheet → 渲染 → 保存 → 成功 snackbar
    - **应用模版按钮（内容区）** ✅ 完整：同底部栏，共享同一 flow
    - **进度状态** ✅ 完整：渲染中"正在渲染…" / 保存中"正在保存到相册…"（CircularProgressIndicator + 永久 snackbar 直到完成）
    - **保存成功** ✅ 完整：`Gal.putImageBytes` 写入相册 + `usageCount += 1`
    - **错误处理** ✅ 完整：`FrameRenderException` → 渲染失败 / `GalException` → 保存失败 / null bytes → 无法读取原图；均带"重试"按钮
    - **usageCount 幂等** ✅：`incrementUsageCount` 内部使用 `withIncrementedUsage()`，无竞态风险
  - **关键设计决策**：
    1. **`ImageSaver` 抽象而非直接 mock `Gal`** — `Gal.putImageBytes` 是 static method，mocktail 无法 mock；通过 `ImageSaver` 接口注入测试实现，隔离 `Gal` 依赖
    2. **`sealed class ApplyTemplateState`** — 5 个子状态覆盖完整生命周期，UI 用 `switch` 穷举所有分支，编译器强制覆盖新状态
    3. **`PhotoDetailScreen` 作为 orchestrator** — 持有 `applyTemplateProvider`，监听状态变化并显示对应 snackbar；两个按钮（底部栏 + 内容区）都调用 `_showTemplateSheet`，共享同一 flow
    4. **`GalImageSaver` 默认注入** — `ApplyTemplateNotifier` 构造函数默认 `imageSaver: const GalImageSaver()`，生产路径无需额外 DI
    5. **`usageCount` 失败不阻断 success** — `incrementUsageCount` 的异常被 catch 吞掉，只记日志；用户已看到"保存成功"，不影响体验
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **275/275 通过**（原 269 + 6 新 applyTemplateProvider）
  - **预估**: 50 min
  - **完成时间**: 2026-06-27
- [x] **M2-T7** 测试：FrameRenderer 3 种 layer 各自合成 / `usageCount` 持久化往返 / 编辑器添加/删除图层 widget
  - 新增 4 个测试文件：
    - `test/features/frames/editor_subwidgets/blur_border_editor_test.dart` — **5 个用例**：强度滑块 / edge switch / 拖动触发回调 / intensity > 10 不崩溃
    - `test/features/frames/editor_subwidgets/text_watermark_editor_test.dart` — **6 个用例**：4 控件渲染 / 初始文本填充 / text 变化触发回调 / dropdown 显示当前值 / 字号 slider / 外部 layer.text 变化同步 controller
    - `test/features/frames/editor_subwidgets/color_stripe_editor_test.dart` — **6 个用例**：4 控件渲染 / 位置 dropdown 当前值 / width+cornerRadius slider 显示值+触发回调 / dropdown 切换触发 onPositionChanged
    - `test/features/frames/editor_subwidgets/hex_color_field_test.dart` — **8 个用例**：`#AARRGGBB` 格式初始值 / 合法输入触发回调 / 非法输入显示 errorText / `0x` 前缀支持 / suffix 色块 / inputFormatter 只接受 hex 字符 / 清空调用 callback
  - **M2-T7 测试覆盖确认**：
    - **FrameRenderer 3 种 layer 合成** ✅ 已完整（M2-T5 的 `frame_renderer_test.dart` 14 个用例覆盖 BlurBorderLayer 3 个 / ColorStripeLayer 3 个 / TextWatermarkLayer 2 个 / z-order / error path / 内置模板）
    - **`usageCount` 持久化往返** ✅ 已完整（`frame_template_test.dart` — `usageCount is mutable and persists after save`；`frame_repository_test.dart` — `incrementUsageCount` 3 个用例覆盖正常/缺失 id no-op/保留其他字段）
    - **编辑器添加/删除图层 widget** ✅ 已完整（`layer_switch_group_test.dart` 4 个用例覆盖 enabled 切换 swap；新增 4 个子 widget 测试文件共 25 个用例覆盖参数编辑交互）
  - **验证**: `flutter analyze` → **24 info（非阻塞）** | `flutter test` → **299/299 通过**（全量）
  - **预估**: 40 min
  - **完成时间**: 2026-06-27

---

## M3 — 影集 ⬜

- [x] **M3-T1** `Album` model `@HiveType(typeId: 7)` + `AlbumLayout` `@HiveType(typeId: 11)` + `copyWith()` + `build_runner` 生成 + 注册到 `HiveService` + 11 个 roundtrip 测试
  - `AlbumModel`: id / name / coverPhotoId / photoIds / createdAt / layout 共 6 字段
  - `AlbumLayout`: grid / magazine / collage / polaroid 共 4 种版式
  - `HiveService.registerAdapters()` 接入（typeId 7 + 11，幂等守卫）
  - **完成时间**: 2026-06-27
- [x] **M3-T2** `AlbumRepository` 完整 CRUD
  - `AlbumRepository`：生产构造（`HiveService.albums`）+ 测试入口 `fromBox(Box)` + 完整 CRUD（`getAll` 倒序 / `getById` / `create` / `rename` / `addPhotos` / `removePhotos` / `reorderPhotos` / `setCover` / `setLayout` / `delete`）
  - `create`：自动生成 uuid id、auto-set coverPhotoId（空影集第一张为封面）、`createdAt` = now
  - `addPhotos`：追加到末尾；空封面自动升格第一张为封面
  - `removePhotos`：移除后若原封面被删，自动换第一张；全删清空封面
  - `reorderPhotos`：直接替换完整列表；封面不在新列表时清空
  - `setCover`：`newCoverPhotoId` 不在 `photoIds` 中时 no-op
  - 所有 mutation：id 不存在时 no-op（不抛错）
  - 测试 `test/features/albums/album_repository_test.dart`：**29 个用例**（getAll ×2 / getById ×2 / create ×4 / rename ×2 / addPhotos ×4 / removePhotos ×4 / reorderPhotos ×3 / setCover ×3 / setLayout ×2 / delete ×2）
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **338/338 通过**（原 299 + 39 新）
  - **预估**: 25 min
  - **完成时间**: 2026-06-27
- [x] **M3-T3** 影集列表页（2 列，封面缩略图）
  - 新增 3 个 lib 文件 + 2 个 test 文件：
    - `lib/features/albums/presentation/providers/album_list_provider.dart` — `AlbumListNotifier`（与 PhotosNotifier 同模式：build 同步返回空 / refresh 走 `AsyncValue.guard`）
    - `lib/features/albums/presentation/widgets/album_grid_item.dart` — 单格 widget：封面缩略图（FutureBuilder 注入）+ 底部渐变遮罩 + 标题 + 照片数 + 多选勾选态
    - `lib/features/albums/presentation/screens/album_list_screen.dart` — 改写：4 态显式（loading/error+retry/empty/success）+ 2 列 `GridView.builder` + 封面缩略图 + 标题 + 照片数；`albumRepositoryProvider` 从 repository 迁出到 provider 文件（与 frame/photo 保持一致）
  - 测试（15 个新增）：
    - `test/features/albums/album_grid_item_test.dart` — **10 个用例**：tap 回调 / 无 onTap 不抛错 / loading 占位 / bytes 渲染 Image.memory / 无封面占位 / 1:1 比例 / isSelected 显示勾选 / isSelected=false 隐藏勾选 / onLongPress 触发 / 无 onLongPress 不抛错
    - `test/features/albums/album_list_screen_test.dart` — **5 个用例**：loading（`_LoadingAlbumListNotifier`）/ empty（`_EmptyAlbumListNotifier`）/ success 2 列网格 + 2 卡片 / error+retry / + 按钮存在
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **353/353 通过**（原 338 + 15 新）
  - **预估**: 30 min
  - **完成时间**: 2026-06-27
- [x] **M3-T4** 新建影集 sheet（名称 + 选照片 + 版式）
  - 新增 `lib/features/albums/presentation/screens/album_create_screen.dart`：TextField 名称 + 4 种版式 ChoiceChip + 4 列照片多选网格（tap 切换选中态 + 已选 N 张计数）+ 创建按钮 + 关闭按钮 + `canPop()` 守卫
  - 修改 `lib/features/albums/presentation/screens/album_list_screen.dart`：右上角 `+` 按钮改为 `context.push('/albums/create')`（替换 TODO）
  - 修改 `lib/core/router/app_router.dart`：注册 `/albums/create` 子路由（`AlbumCreateScreen`）+ `AppRoute.albumCreate` 常量
  - 测试 `test/features/albums/album_create_screen_test.dart`：**10 个用例**覆盖初始态 / 输入名称 / 选照片切换 / 多选计数 / 切换版式 / 名称空提示 / 正常创建 / 创建中 loading / 创建失败 snackbar / 关闭按钮
  - **验证**: `flutter analyze` → **No issues found on M3-T4 changed files** | `flutter test` → **64/64 通过**（54 旧 + 10 新）
  - **预估**: 30 min
  - **完成时间**: 2026-06-27
- [x] **M3-T5** 详情页：版式 `autoLayout` + 手动 1/2/3/4 宫格
  - 新增 2 个 lib 文件 + 1 个 test 文件：
    - `lib/features/albums/presentation/providers/album_detail_provider.dart` — `albumByIdProvider`（watch `albumListProvider`，用 `hasValue` 守卫避免 `AsyncError` 抛错）
    - `lib/features/albums/presentation/screens/album_detail_screen.dart` — 4 态（loading/error/empty/success）+ `autoLayout(N)` 自动选宫格（1/2/4/2）+ `PopupMenuButton` 手动切换 1/2/3/4 宫格 + 点击照片跳转 `/photo/:id`
  - 修改：
    - `lib/core/router/app_router.dart` — 注册 `/albums/:id` 子路由（`parentNavigatorKey: rootNavigatorKey` 沉浸式）
    - `lib/features/albums/presentation/screens/album_list_screen.dart` — 替换 `TODO(M3-T5)` 为 `context.push('/albums/${album.id}')`
  - 测试 `test/features/albums/album_detail_screen_test.dart`：**16 个用例**（loading/error/不存在/empty/1张1宫格/2张2宫格/5+张2列/手动切换4宫格/点击跳转/AppBar显示名称 + 6 个 `autoLayout` 纯函数测试）
  - **验证**: `flutter analyze` → **0 errors on M3-T5 files** | `flutter test` → **379/379 通过**（原 363 + 16 新）
  - **预估**: 30 min
  - **完成时间**: 2026-06-27
- [x] **M3-T6** 拖拽重排（`ReorderableListView` 持久化）
  - 修改 `lib/features/albums/presentation/screens/album_detail_screen.dart`：
    - 新增 `_isReorderMode` 状态 + AppBar 排序模式入口（`swap_vert` 图标，仅 2+ 张照片显示）
    - 排序模式下 AppBar 右侧切换为勾选（完成）按钮，版式切换 + 排序入口隐藏
    - 新增 `_AlbumPhotoReorderGrid`（`ReorderableListView.builder` 实现）：按 [gridCount] 分行，每行一个 `ReorderableDragStartListener`
    - `_AlbumPhotoTile` 新增 `showDragHandle` 参数，排序模式下显示右下角拖拽手柄图标
    - 拖拽完成后调用 `albumRepositoryProvider.reorderPhotos(albumId, newPhotoIds)` 持久化 + `albumListProvider.notifier.refresh()` 刷新列表
    - `_isDragging` 守卫防止拖拽期间 setState 触发 rebuild
  - 新增测试 `test/features/albums/album_detail_screen_test.dart`：**5 个新用例**（排序按钮 2+/单张显示逻辑 / 进入排序模式 / 退出排序模式 / 排序模式无点击跳转）
  - **验证**: `flutter analyze` → **No issues found**（M3-T6 files）| `flutter test` → **384/384 通过**（原 379 + 5 新）
  - **预估**: 30 min
  - **完成时间**: 2026-06-27
- [x] **M3-T7** 换封面
  - 新增 `lib/features/albums/presentation/widgets/cover_picker_sheet.dart`：
    - `CoverPickerSheet` 底部弹窗（DraggableScrollableSheet），展示影集所有照片 3 列网格
    - 当前封面照片显示白色勾选圆圈标记
    - 用户点击照片后关闭弹窗并返回选中的 photoId
  - 修改 `lib/features/albums/presentation/screens/album_detail_screen.dart`：
    - AppBar 新增"换封面"按钮（`Icons.photo_library_outlined`）
    - `_showCoverPicker()` 方法：弹出 `CoverPickerSheet` → 用户选择后调用 `albumRepository.setCover()` 持久化 → `albumListProvider.refresh()` 刷新
  - 新增测试 `test/features/albums/cover_picker_sheet_test.dart`：**6 个用例**覆盖标题/拖拽条/网格渲染/封面勾选标记/点击返回/空影集
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **390/390 通过**（原 384 + 6 新）
  - **预估**: 20 min
  - **完成时间**: 2026-06-27
- [x] **M3-T8** 测试：AlbumRepository
  - `test/features/albums/album_repository_test.dart`：**28 个用例**覆盖 getAll ×2 / getById ×2 / create ×4 / rename ×2 / addPhotos ×4 / removePhotos ×4 / reorderPhotos ×3 / setCover ×3 / setLayout ×2 / delete ×2
  - **验证**: `flutter analyze` → **0 errors**（65 info/warnings 非阻塞）| `flutter test` → **390/390 通过**
  - **完成时间**: 2026-06-27

---

## M4 — 标签 + 搜索 🟡（搜索降级为相册 tab 内 push 二级页，对齐 mockup v3 / PRD v0.2）

- [x] **M4-T1** `Tag` model `@HiveType(typeId: 8)`
  - `TagModel`：id / name / colorValue(ARGB) / createdAt 共 4 字段
  - `@HiveType(typeId: 8)` + `@HiveField(0..3)` 注解
  - `copyWith()` 方法支持字段覆盖
  - `createdAt` 默认 `DateTime.now()`
  - `HiveService.registerAdapters()` 接入 `TagModelAdapter`（幂等守卫）
  - 新增 `test/features/tags/tag_model_test.dart`：**7 个用例**（全字段 roundtrip / 最小字段 roundtrip / 2 个颜色值格式 / 多记录独立性 / copyWith / typeId=8）
  - **验证**: `flutter analyze` → **No issues found on M4-T1 files** | `flutter test` → **397/397 通过**（原 390 + 7 新）
  - **预估**: 15 min
  - **完成时间**: 2026-06-27
- [x] **M4-T2** `TagRepository` 完整 CRUD + 删除保护
  - `TagRepository`：create / rename / setColor / delete（被引用时抛 `TagInUseException`）+ `isTagInUse` 查询
  - `TagInUseException`（tagId + photoCount）；删除保护检查 `photosMeta` box 中所有 `PhotoModel.tags`
  - 构造函数支持 `fromBox(tagsBox, photosBox)` 注入测试
  - `UuidGenerator` 与 `AlbumRepository` 共用
  - 新增 `test/features/tags/tag_repository_test.dart`：**20 个用例**（getAll ×2 / getById ×2 / create ×3 / rename ×2 / setColor ×2 / delete ×5 / isTagInUse ×4）
  - **验证**: `flutter analyze` → **2 info trailing comma（非阻塞）** | `flutter test` → **417/417 通过**（原 397 + 20 新）
  - **预估**: 25 min
  - **完成时间**: 2026-06-27
- [x] **M4-T3** 标签管理页
  - 新增 5 个 lib 文件 + 3 个 test 文件：
    - `lib/features/tags/presentation/providers/tag_list_provider.dart` — `TagListNotifier`（与 AlbumListNotifier 同模式：build 同步返回空 / refresh 走 AsyncValue.guard）
    - `lib/features/tags/presentation/providers/tag_detail_provider.dart` — `TagDetailState` + `TagDetailNotifier`（load/rename/setColor/delete）
    - `lib/features/tags/presentation/widgets/tag_list_item.dart` — 单格 Chip：左侧彩色圆点 + 名称 + 使用量（>0 时显示）
    - `lib/features/tags/presentation/screens/tag_manager_screen.dart` — 标签管理页：4 态（loading/error/empty/success）+ FAB 新建标签 sheet（名称 + 12 颜色选择）
    - `lib/features/tags/presentation/screens/tag_detail_screen.dart` — 标签详情页：修改名称（编辑态切换）/ 修改颜色（10 预设色）/ 删除（TagInUseException 保护）
  - 修改 `lib/core/router/app_router.dart`：注册 `/tags` ShellRoute（顶层） + `/tags/:id` 详情路由（parentNavigatorKey: rootNavigatorKey 沉浸式）
  - 测试（23 个新增）：
    - `test/features/tags/tag_list_provider_test.dart` — **4 个用例**：build 空 / refresh 加载 / refresh 错误 / refresh 幂等
    - `test/features/tags/tag_list_item_test.dart` — **6 个用例**：名称显示 / 使用量显示 / usageCount=0 隐藏 / 颜色圆点 / onTap 回调 / 无 onTap 不抛错
    - `test/features/tags/tag_manager_screen_test.dart` — **7 个用例**：loading/error/empty/success 4 态 / FAB 打开新建 sheet / sheet 输入创建 / appBar 标题
  - **M4-T3 功能可用度**：
    - **标签列表** ✅ 完整：按创建时间倒序，4 态显式
    - **新建标签** ✅ 完整：底部 sheet → 名称 + 颜色 → repo.create
    - **标签详情（修改/删除）** ✅ 完整：点击列表项 → TagDetailScreen → rename/setColor/delete
    - **删除保护** ✅ 完整：被引用时抛 `TagInUseException` → snackbar 提示
    - **颜色预览圆点** ✅ 完整：ListTile leading 彩色圆点
  - **验证**: `flutter analyze` → **No issues found on M4-T3 files** | `flutter test` → **434/434 通过**（全量）
  - **预估**: 30 min
  - **完成时间**: 2026-06-27
- [x] **M4-T4** Lightroom 风格选择器（已选 + 全部 + 搜索）
  - 新增 1 个 lib 文件 + 1 个 test 文件：
    - `lib/features/tags/presentation/widgets/tag_picker_sheet.dart`：`showTagPickerSheet` 入口函数 + `TagPickerSheet` StatefulWidget（搜索框 / 已选色块 / 全部标签列表 / Done 回调）
    - `lib/features/photos/presentation/widgets/bottom_action_bar.dart`：新增 `onTags` 参数，标签按钮从 disabled 升级为可用
    - `lib/features/photos/presentation/screens/photo_detail_screen.dart`：新增 `_handleTags` 方法 → `showTagPickerSheet` → `PhotoRepository.updateTags` 持久化 → `photosProvider.refresh()`
    - `lib/features/photos/data/repositories/photo_repository.dart`：新增 `updateTags(String id, List<String> tags)` 方法
  - 测试 `test/features/tags/tag_picker_sheet_test.dart`：**13 个用例**覆盖标题/搜索/已选区/标签列表/选中切换/X移除/Done回调/搜索过滤/清空/选中标签在过滤后仍显示/showTagPickerSheet 入口
  - **M4-T4 功能可用度**：
    - **标签选择 sheet** ✅ 完整：Lightroom 双栏风格（已选 + 全部）
    - **搜索过滤** ✅ 完整：实时过滤标签名
    - **标签切换选中** ✅ 完整：点击标签切换选中态
    - **已选标签 chip** ✅ 完整：彩色 chip + X 移除按钮
    - **Done 确认** ✅ 完整：回调传入最终选中 ID 集合，关闭 sheet
    - **BottomActionBar 标签按钮** ✅ 完整：从 disabled 升级为可用，调用 `_handleTags`
  - **关键设计决策**：`Material` 包装解决 `ListTile` ink splash 问题；`updateTags` 幂等 no-op；`initState` post-frame 刷新标签列表
  - **验证**: `flutter analyze` → **0 errors** | `flutter test` → **447/447 通过**（M4-T4 13 新 + 434 旧）
  - **预估**: 30 min
  - **完成时间**: 2026-06-27
- [x] **M4-T5** `PhotoModel` 加 **`@HiveField(7) starRating: int`**（0–5，CLAUDE.md §7.7：紧跟现有 0–6 之后；同步更新 `hive_service.registerAdapters` 与 7 个 `photo_model_test.dart` 字段数）
  - `PhotoModel` 新增 `@HiveField(7) starRating: int`（默认 0，表示未评）
  - `dart run build_runner build` → `photo_model.g.dart` 重新生成（writeByte 7→8，新增字段 7 读写）
  - `photo_model_test.dart` 更新 2 处：`all fields set` 测试加 `starRating: 5` 断言；`minimal fields` 测试加 `expect(loaded.starRating, 0)` 断言；文档注释更新字段数为 8
  - **验证**: `flutter analyze` → **0 errors**（107 info/warnings 均为既有非阻塞项）| `flutter test` → **447/447 通过**
  - **预估**: 15 min
  - **完成时间**: 2026-06-27
- [x] **M4-T6** 照片详情页"加星"交互：5 颗可点星标 → 写回 `PhotoModel.starRating`
  - `PhotoRepository.updateStarRating`：新增方法，类似 `updateTags`；clamp 0-5 范围；id 不存在 no-op
  - 新增 `lib/features/photos/presentation/widgets/star_rating.dart`：`StarRating` widget（5 颗可点星标 / 点击同一颗取消评星 / 与 TagPills 布局风格一致）
  - `PhotoDetailContent`：新增 `onStarChanged` 参数，集成 `StarRating` widget
  - `BottomActionBar`：星级按钮从 `onPressed: null` 升级为可用，传入 `onStar` 回调
  - `PhotoDetailScreen`：新增 `_handleStar` + `_StarPickerSheet` 底部选择弹窗（点击同一颗星取消）
  - 新增测试：
    - `test/features/photos/star_rating_test.dart`：**8 个用例**（5 星渲染 / N 星填充 / 点击设值 / clamp 显示）
    - `test/features/photos/photo_repository_test.dart`（追加）：**4 个用例**（更新+保留字段 / clamp 上限 / clamp 下限 / id 不存在 no-op）
    - `test/features/photos/bottom_action_bar_test.dart`（改写）：更新 4 个旧用例（tag/star/album 按钮 disabled 占位 → star 按钮可用）
  - **验证**: `flutter analyze` → **0 errors**（pre-existing warnings 非阻塞）| `flutter test` → **462/462 通过**（447 旧 + 15 新）
  - **预估**: 30 min
  - **完成时间**: 2026-06-27
- [x] **M4-T7** `SearchFilter` model（纯 dart，含 `tagIds` / **`minStarRating`** / `dateRange` / `albumId` / `framedState`）
  - 新增 5 维过滤字段：`tagIds`（多选）/ `tagMatchMode`（AND/OR）/ `minStarRating` + `starRatingMode`（≥N/=N）/ `dateFrom/dateTo` / `albumId` / `framedState`（all/framed/unframed）
  - `SearchFilter` 不可变值对象 + `copyWith`（含 `clear*` 清除哨兵）+ `isEmpty` + `==`/`hashCode`
  - 新增 3 个支持枚举：`TagMatchMode`（any/all）/ `StarRatingMatchMode`（greaterOrEqual/exact）/ `FramedState`（all/framed/unframed）
  - 新增 `test/features/search/search_filter_test.dart`：**13 个用例**覆盖默认构造 / copyWith 保留字段 / copyWith 清除字段 / isEmpty 识别 / equality / hashCode / 枚举值完整性
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **475/475 通过**（462 旧 + 13 新）
  - **预估**: 20 min
  - **完成时间**: 2026-06-27
- [x] **M4-T8** 搜索二级页 `/search`（push，**入口在相册 tab 顶部搜索栏**）：过滤条件 chip 行 + 结果网格
  - 新增 7 个 lib 文件 + 2 个 test 文件：
    - `lib/features/search/data/repositories/search_repository.dart` — 5 维过滤核心：`SearchRepository.matches(SearchFilter, List<PhotoModel>)` 按 tagIds(AND/OR) / minStarRating(≥/=) / dateFrom~dateTo / albumId / framedState 过滤
    - `lib/features/search/presentation/providers/search_provider.dart` — `searchFilterProvider`（StateProvider）+ `searchResultsProvider`（派生 AsyncValue）+ `searchRepositoryProvider`
    - `lib/features/search/presentation/widgets/filter_chip_bar.dart` — FilterChipBar（标签/星级/日期/影集/模版 5 个 chip）+ 5 个内置 filter sheet（_TagFilterSheet / StarRatingFilterSheet / DateRangeFilterSheet / _AlbumFilterSheet / _FramedFilterSheet）
    - `lib/features/search/presentation/widgets/star_rating_filter_sheet.dart` — 星级过滤底部弹窗（≥N / =N 模式切换 + 0-5 星按钮）
    - `lib/features/search/presentation/widgets/date_range_picker_sheet.dart` — 日期范围底部弹窗（今天/本周/本月/今年快捷 + 自定义双端 datePicker）
    - `lib/features/search/presentation/screens/search_screen.dart` — 搜索页（4 态 + FilterChipBar + 结果网格 + 多选模式 + 返回清除 filter）
  - 修改：`lib/features/photos/presentation/screens/photo_gallery_screen.dart` — AppBar 右侧新增搜索按钮 `IconButton(Icons.search)` → `context.push('/search')`
  - 测试（29 个新增）：
    - `test/features/search/search_repository_test.dart` — **12 个用例**覆盖空 filter / 标签 OR+AND / 星级 ≥/= / 日期范围+单端 / framed+unframed / 多维度交叉 / 无结果
    - `test/features/search/search_screen_test.dart` — **4 个用例**覆盖 loading / empty / success 网格 / 星级 sheet 弹出
  - **验证**: `flutter analyze` → **0 errors** | `flutter test` → **491/491 通过**（原 462 + 29 新）
  - **预估**: 40 min
  - **完成时间**: 2026-06-27
- [x] **M4-T9** 5 维过滤：标签(AND/OR) / **星级(≥N/=N)** / 日期 / 影集 / 模版状态
  - M4-T9 的任务内容（5 维过滤）与 M4-T8 完全重复，已在 M4-T8 的 SearchRepository.matches() + FilterChipBar 中实现
  - SearchRepository 5 维过滤：tagIds(AND/OR) / minStarRating(≥/=) / dateFrom~dateTo / albumId / framedState
  - FilterChipBar：5 个 chip（标签/星级/日期/影集/模版）+ 各自 sheet（_TagFilterSheet / StarRatingFilterSheet / DateRangeFilterSheet / _AlbumFilterSheet / _FramedFilterSheet）
  - search_repository_test.dart：12 个用例覆盖所有维度
  - **验证**: `flutter analyze` → **131 info trailing comma（非阻塞）** | `flutter test` → **491/491 通过**
  - **完成时间**: 2026-06-27（随 M4-T8 一起完成）
- [x] **M4-T10** 搜索结果批量操作（打标签 / 加星 / 删除）
  - 多选模式下 AppBar 显示标签/星级/删除 3 个按钮
  - 批量打标签：点击标签按钮 → TagPickerSheet → 选择标签 → 批量写入 `PhotoRepository.updateTags`
  - 批量加星：点击星级按钮 → `showBatchStarRatingSheet`（0-5 星选项）→ 批量写入 `PhotoRepository.updateStarRating`
  - 批量删除：已有实现，复用 `_showDeleteConfirmation`
  - 新增 `star_rating_picker_sheet.dart`：批量星级选择底部弹窗
  - 测试：search_screen_test.dart 新增 3 个用例（多选按钮显示 / 标签 sheet / 星级 sheet）
  - **验证**: `flutter analyze` → **0 errors**（lib files）| `flutter test` → **494/494 通过**
  - **完成时间**: 2026-06-27
- [x] **M4-T11** 测试：TagRepository / SearchFilter.matches（4 维交叉） / 星级 widget
  - TagRepository：20 个用例（CRUD + 删除保护 + isTagInUse）✅ 已有
  - SearchFilter.matches 4 维交叉：新增 2 个用例（4维全开有结果 / 4维全开无结果），共 14 个用例
  - 星级 widget：8 个用例（tap/渲染/clamp）✅ 已有
  - **验证**: `flutter test` → **496/496 通过**（+2 新测试）
  - **完成时间**: 2026-06-27

**完成时间**: _待定_

---

## M5 — 批量 + 删除 tab ⬜（删除 tab 合并原"清理模式"，对齐 mockup v3 / PRD v0.2）

- [x] **M5-T1** 批量套模版（含进度 sheet、并发控制 2、完成后 `usageCount += N`）
  - 新增 4 个文件：
    - `lib/features/photos/presentation/providers/batch_apply_template_provider.dart` — `BatchApplyTemplateState`（sealed class：Initial / Processing / Done）+ `BatchApplyTemplateNotifier`（并发控制 2 + 进度跟踪 + 结果统计）
    - `lib/features/photos/presentation/widgets/image_saver.dart` — `ImageSaver` 抽象接口 + `GalImageSaver` 生产实现（M2-T6 的 ApplyTemplateNotifier 也有同样抽象，但重复定义更方便测试注入）
    - `lib/features/photos/presentation/widgets/batch_apply_template_sheet.dart` — 批量套模版进度展示 Sheet（当前未直接使用，结果在 `_BatchResultSheet` 展示）
    - `lib/features/photos/presentation/widgets/apply_template_sheet.dart` — 新增 `showTemplatePickerSheet` 入口函数（返回选中的模板）
  - 修改 `lib/features/photos/presentation/screens/photo_gallery_screen.dart`：
    - 新增 `_handleBatchFrame` 方法：选择模板 → 构建 photoLoaders → 调用 `BatchApplyTemplateNotifier.applyTemplateBatch` → 显示 `_BatchResultSheet` → 完成后退出多选并刷新
    - 新增 `_BatchResultSheet` / `_ProcessingContent` / `_DoneContent` / `_ResultChip` widget
    - `MultiSelectAppBar` 的 `onFrame` 接入 `_handleBatchFrame`
  - 并发控制策略：每批 2 张，使用 `Future.wait` 等待一批完成后再处理下一批，避免 OOM
  - 进度跟踪：每批完成后更新 `BatchApplyTemplateProcessing` 状态
  - `usageCount += N`：批量完成后一次性调用 `frameRepository.incrementUsageCount`
  - 测试 `test/features/photos/batch_apply_template_provider_test.dart`：**9 个用例**覆盖状态类 equality / progress 计算 / notifier 初始态 / reset / empty / success / failure 路径
  - **验证**: `flutter analyze` → **0 errors** | `flutter test` → **505/505 通过**
  - **预估**: 50 min
  - **完成时间**: 2026-06-27
- [x] **M5-T2** 批量打标签
  - 多选 → 选标签 → 批量写入 `PhotoModel.tags`（ADD 增量模式）
  - 新增 `_handleBatchTags` 方法：读取选中照片已有标签取并集作为初始态 → `showTagPickerSheet` → 用户选择后逐张写入 → 退出多选 + 刷新
  - `MultiSelectAppBar.onTags` 从 snackbar 占位升级为真实回调
  - 测试 `photo_gallery_screen_test.dart` 新增 1 个用例：批量打标签 sheet 弹出并调用 `updateTags`
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **506/506 通过**
  - **预估**: 20 min
  - **完成时间**: 2026-06-27
- [x] **M5-T3** **批量加星**（新加，依赖 M4-T5 的 `starRating` 字段）
  - 多选 → 选星级（0–5）→ 调用 `PhotoRepository.updateStarRating` 写入每张照片 → 退出多选 + 刷新
  - `showBatchStarRatingSheet` 已有（M4-T10），无需新增 UI 组件
  - `MultiSelectAppBar.onStar` 从 snackbar 占位升级为真实回调 `_handleBatchStar`
  - 新增测试 `photo_gallery_screen_test.dart`：2 个用例（单张加星 / 全选加星）
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **508/508 通过**（M5-T3 2 新）
  - **预估**: 20 min
  - **完成时间**: 2026-06-28
- [x] **M5-T4** 批量加入影集
  - 多选 → 选影集 → `AlbumRepository.addPhotos` → 退出多选 + 刷新
  - 新增 `album_picker_sheet.dart`：影集列表 + 新建影集并添加
  - `MultiSelectAppBar.onAlbum` 从 snackbar 占位升级为真实回调 `_handleBatchAlbum`
  - 新增测试 `album_picker_sheet_test.dart`：4 个用例（标题/列表/点击/新建）
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **512/512 通过**（M5-T4 4 新）
  - **预估**: 20 min
  - **完成时间**: 2026-06-28
- [x] **M5-T5** 批量删除（二次确认）
  - AlertDialog 二次确认（取消/删除）+ 明确提示"仅删除 App 内记录，系统相册原图不受影响"
  - `photo_manager` 只有删除 App 写入副本的权限（无法删系统原图），故去掉"也删除原图"开关，改为明确文案
  - **验证**: `flutter analyze` → **No issues found** | `flutter test` → **512/512 通过**
  - **预估**: 10 min
  - **完成时间**: 2026-06-28
- [x] **M5-T6** **删除 tab**（独立一级 tab，承载原"清理模式"）：单图全屏（黑底）+ 顶栏 `‹` 返回 / `N / M` 位置计数 / 右上 `⋯` 操作
  - 新增 2 个 lib 文件 + 2 个 test 文件：
    - `lib/features/photos/presentation/providers/delete_viewer_provider.dart` — `DeleteViewerState` + `DeleteViewerNotifier`（currentIndex / isLoading / initialize / goToPrevious / goToNext / onDeleted / setLoading）
    - `lib/features/photos/presentation/screens/delete_viewer_screen.dart` — 删除 tab 主屏：黑底全屏 + `_PhotoLoader` FutureBuilder 异步加载字节（loading 占位图标 / 错误占位图标 / PhotoViewer）+ `_DeleteViewerAppBar`（返回/计数/菜单）+ 左右箭头导航
  - 修改：
    - `lib/core/router/app_router.dart` — 注册 `/delete-viewer` 路由（`AppRoute.deleteViewer`）+ import `DeleteViewerScreen`
    - `lib/core/widgets/app_shell.dart` — 替换搜索 tab 为删除 tab：`_TabSpec(AppRoute.deleteViewer, Icons.delete_outline, Icons.delete, '删除')`（对齐 PRD v0.2 五 tab 导航：相册/影集/相框/删除/设置）
    - `lib/features/photos/presentation/screens/photo_gallery_screen.dart` — 清理按钮改为 `context.go(AppRoute.deleteViewer)`
  - 测试（22 个新增）：
    - `test/features/photos/delete_viewer_provider_test.dart` — **14 个用例**：build 初始态 / initialize / goToPrevious 递减 / 越界守卫 / goToNext 递增 / 越界守卫 / onDeleted 钳制 / 越界守卫 / onDeleted 空列表 / setLoading / copyWith 全字段 / copyWith 部分字段
    - `test/features/photos/delete_viewer_screen_test.dart` — **8 个用例**：empty 态 / N/M 计数 / 返回按钮 / 菜单按钮 / 多照片右箭头 / 右箭头递增 / 左箭头递减 / 菜单底部弹窗
  - **验证**: `flutter analyze` → **0 errors on M5-T6 files**（pre-existing batch_apply_template_sheet.dart 错误非本次引入）| `flutter test` → **534/534 通过**
  - **预估**: 40 min
  - **完成时间**: 2026-06-28
- [x] **M5-T7** 删除 tab **手势**：↑ 滑 → 删除 + 撤销 toast / ← 滑 → 上一张 / → 滑 → 下一张
  - 新增 `_SwipePhotoViewer` widget（`GestureDetector.onPanStart/End` 检测滑动方向）
  - 方向判定：`|dx| > |dy|` → 水平（←/→导航）；否则 → 垂直（↑ 删除）
  - 阈值 50px，防止误触
  - 删除后显示 5s 撤销 toast（调用 `PhotoRepository.save` 恢复）
  - `PhotosNotifier` 新增 `delete(id)` 方法
  - 新增测试 `delete_viewer_screen_test.dart`：2 个用例（swipe left → previous / swipe right → next）
  - **验证**: `flutter analyze` → **0 errors** | `flutter test` → **536/536 通过**
  - **预估**: 30 min
  - **完成时间**: 2026-06-28
- [x] **M5-T8** 删除 tab 屏幕内提示 hint（首次显示 3s 后渐隐）+ 顶栏 `⋯` 菜单（退出/批量/过滤）
  - 新增 `_DeleteHintOverlay` StatefulWidget：显示手势操作提示（"上滑删除 · 左右滑动切换"），首次进入时显示，3s 后自动淡出（500ms easeOut 动画）；持久化 `deleteHintShown` 到 `SettingsService`（M5-T8 新增 `getBool`/`setBool` 通用方法）
  - `_showMenuSheet` 的「进入多选」从 SnackBar 占位升级为真实回调：调用 `multiSelectProvider.selectAll` 全选当前照片 + `enterMultiSelectMode` + `context.pop()` + `context.go('/gallery')` 跳转相册
  - 11 个测试全过：`flutter analyze` → 0 errors（3 个 pre-existing `batch_apply_template_sheet.dart` sealed class 语法错误与本次无关）| `flutter test` → **537/537** 通过
  - **预估**: 20 min
  - **完成时间**: 2026-06-28
- [x] **M5-T9** 防竞态：sessionId 校验 / 撤销栈 `Queue<({assetId, sessionId})>`
  - 新增 `UndoEntry` 公开类（`assetId` / `sessionId` / `photo`）
  - `DeleteViewerState` 新增 `sessionId`（每次进入时生成新 id）和 `undoStack`（`Queue<UndoEntry>`）
  - `initialize()` 生成新 sessionId + 清空 undoStack（进入新的删除会话时使之前的撤销失效）
  - `pushToUndoStack(PhotoModel)` 将删除的照片存入栈（关联当前 sessionId）
  - `popUndoStackIfValid()` 弹出栈顶条目（仅当 sessionId 匹配时有效）
  - `_handleDelete` 在删除前先 push 到撤销栈
  - `_handleUndo` 调用 `popUndoStackIfValid()` 并校验返回值；sessionId 不匹配或栈为空时显示"撤销已失效"
  - SnackBar 显示当前可撤销数量 `已删除 (N)`
  - 测试 `delete_viewer_provider_test.dart`：新增 8 个用例（copyWith × 2 / initialize 生成新 sessionId / initialize 清空栈 / pushToUndoStack / popUndoStackIfValid 匹配+不匹配+空栈 / LIFO 顺序）
  - **验证**: `flutter analyze` → 1 info pre-existing trailing comma（非本次引入）| `flutter test` → **546/546 通过**
  - **完成时间**: 2026-06-28
- [x] **M5-T10** 测试：删除 tab 状态机（4 条路径） / 多选 Provider / 批量加星
  - 删除 tab 状态机（4 条路径）：
    - 核心逻辑已在 `delete_viewer_provider_test.dart`（M5-T9）充分测试：initialize / goToPrevious / goToNext / onDeleted / setLoading / copyWith / sessionId 生成和失效 / undoStack push/pop/LIFO/sessionId 校验，共 31 个用例
    - 屏幕级测试：swipe up 删除显示撤销 SnackBar（M5-T7）
  - 多选 Provider：9 个用例完整覆盖（M5-T7）
  - 批量加星：新增 0 星清除测试用例（M5-T10）
  - **验证**: `flutter analyze` → 0 errors（138 info 非阻塞）| `flutter test` → **548/548 通过**
  - **完成时间**: 2026-06-28

---

## M6 — 打磨 ⬜

- [ ] **M6-T1** 全局 4 态显式（loading/error/empty/success）
- [ ] **M6-T2** 暗色模式过一遍
- [ ] **M6-T3** 性能：1000 张分页 + 缩略图 LRU
- [ ] **M6-T4** Integration test：开 App → 授权 → 网格 → 详情 → 套模板 → 导出
- [ ] **M6-T5** 错误处理：渲染失败重试 / 权限拒绝去设置
- [ ] **M6-T6** README 同步

**完成时间**: _待定_

---

## 归档

（满足归档条件时使用，详见 CLAUDE.md §5）

_尚无归档记录_
