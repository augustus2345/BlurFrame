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
- [ ] **M1-T7** 长按多选模式 + `MultiSelectProvider` 维护 `Set<String> selectedIds`（与 5 项批量操作联动）
- [ ] **M1-T8** 详情页完整结构：顶部大图 + EXIF 字段表（**相机/镜头/ISO/快门/拍摄时间**，基于 `ExifDatasource.parse`）+ 标签 pills + 底部"**分享 / 应用模版**"双按钮
- [ ] **M1-T9** 4 态显式：loading / success / error / empty（`AsyncValue.when` + `EmptyState`，M1-T5 已覆盖 gallery 4 态；M1-T6 详情页复用同一套）
- [ ] **M1-T10** 测试：`PhotoRepository` / `ExifDatasource` / `PhotoGrid` widget 三个核心文件覆盖完整

**完成时间**: 2026-06-23

---

## M2 — 模版 ⬜（独立 tab，对齐 mockup v3 / PRD v0.2）

- [ ] **M2-T1** `FrameTemplate` / 3 种 `FrameLayer`（`BlurBorderLayer` / `TextWatermarkLayer` / `ColorStripeLayer`）/ `WatermarkPosition` 加 `@HiveType`（typeId 2–5；含 `usageCount` 写回 Hive 字段）
- [ ] **M2-T2** `FrameRepository.builtInTemplates()` 注入 **2 套**内置模版：**极简**（窄边模糊边框）/ **杂志**（顶部品牌 + 底部 EXIF 水印 + 模糊边框 3 层叠加）
- [ ] **M2-T3** 模版 tab 列表页（独立 tab `/frames`，不是 push）：2 列网格 + `editor-frame` 预览 + "自带"标记 / "使用 N 次"统计 + 长按复制/删除（内置不可删）
- [ ] **M2-T4** 模版编辑器 `/frames/editor`（push）：顶部预览 + 中部 3 层分组（每层 switch + 参数：模糊 intensity / 水印 text + EXIF / 颜色选择）+ 底部"保存模板"按钮
- [ ] **M2-T5** `FrameRenderer` 渲染器（`compute` 隔离，输入 bytes + template → bytes，3 种 layer 按 z-order 合成）
- [ ] **M2-T6** 导出：详情页"应用模版" → 进度 → `gal.saveImage()` → 提示成功 → 模版 `usageCount += N`
- [ ] **M2-T7** 测试：FrameRenderer 3 种 layer 各自合成 / `usageCount` 持久化往返 / 编辑器添加/删除图层 widget

**完成时间**: _待定_

---

## M3 — 影集 ⬜

- [ ] **M3-T1** `Album` model `@HiveType(typeId: 7)`
- [ ] **M3-T2** `AlbumRepository` 完整 CRUD
- [ ] **M3-T3** 影集列表页（2 列，封面缩略图）
- [ ] **M3-T4** 新建影集 sheet（名称 + 选照片 + 版式）
- [ ] **M3-T5** 详情页：版式 `autoLayout` + 手动 1/2/3/4 宫格
- [ ] **M3-T6** 拖拽重排（`ReorderableListView` 持久化）
- [ ] **M3-T7** 换封面
- [ ] **M3-T8** 测试：AlbumRepository

**完成时间**: _待定_

---

## M4 — 标签 + 搜索 ⬜（搜索降级为相册 tab 内 push 二级页，对齐 mockup v3 / PRD v0.2）

- [ ] **M4-T1** `Tag` model `@HiveType(typeId: 8)`
- [ ] **M4-T2** `TagRepository` 完整 CRUD + 删除保护
- [ ] **M4-T3** 标签管理页
- [ ] **M4-T4** Lightroom 风格选择器（已选 + 全部 + 搜索）
- [ ] **M4-T5** `PhotoModel` 加 **`@HiveField(7) starRating: int`**（0–5，CLAUDE.md §7.7：紧跟现有 0–6 之后；同步更新 `hive_service.registerAdapters` 与 7 个 `photo_model_test.dart` 字段数）
- [ ] **M4-T6** 照片详情页"加星"交互：5 颗可点星标 → 写回 `PhotoModel.starRating`
- [ ] **M4-T7** `SearchFilter` model（纯 dart，含 `tagIds` / **`minStarRating`** / `dateRange` / `albumId` / `framedState`）
- [ ] **M4-T8** 搜索二级页 `/search`（push，**入口在相册 tab 顶部搜索栏**）：过滤条件 chip 行 + 结果网格
- [ ] **M4-T9** 5 维过滤：标签(AND/OR) / **星级(≥N/=N)** / 日期 / 影集 / 模版状态
- [ ] **M4-T10** 搜索结果批量操作（打标签 / 加星 / 删除）
- [ ] **M4-T11** 测试：TagRepository / SearchFilter.matches（4 维交叉） / 星级 widget

**完成时间**: _待定_

---

## M5 — 批量 + 删除 tab ⬜（删除 tab 合并原"清理模式"，对齐 mockup v3 / PRD v0.2）

- [ ] **M5-T1** 批量套模版（含进度 sheet、并发控制 2、完成后 `usageCount += N`）
- [ ] **M5-T2** 批量打标签
- [ ] **M5-T3** **批量加星**（新加，依赖 M4-T5 的 `starRating` 字段）
- [ ] **M5-T4** 批量加入影集
- [ ] **M5-T5** 批量删除（二次确认）
- [ ] **M5-T6** **删除 tab**（独立一级 tab，承载原"清理模式"）：单图全屏（黑底）+ 顶栏 `‹` 返回 / `N / M` 位置计数 / 右上 `⋯` 操作
- [ ] **M5-T7** 删除 tab **手势**：↑ 滑 → 删除 + 撤销 toast / ← 滑 → 上一张 / → 滑 → 下一张
- [ ] **M5-T8** 删除 tab 屏幕内提示 hint（首次显示 3s 后渐隐）+ 顶栏 `⋯` 菜单（退出/批量/过滤）
- [ ] **M5-T9** 防竞态：sessionId 校验 / 撤销栈 `Queue<({assetId, sessionId})>`
- [ ] **M5-T10** 测试：删除 tab 状态机（4 条路径） / 多选 Provider / 批量加星

**完成时间**: _待定_

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
