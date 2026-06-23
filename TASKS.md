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
- [ ] **M1-T5** 3 列网格 + 缩略图懒加载
- [ ] **M1-T6** 详情页：双指缩放、双击放大、左右滑切换
- [ ] **M1-T7** 长按多选模式 + Provider 维护 `Set<String> selectedIds`
- [ ] **M1-T8** 详情页底部 EXIF 展示（拍摄时间、机型、镜头、ISO 等）
- [ ] **M1-T9** 4 态显式：loading / success / error / empty
- [ ] **M1-T10** 测试：PhotoRepository / ExifDatasource / PhotoGrid widget

**完成时间**: _待定_

---

## M2 — 相框模板 ⬜

- [ ] **M2-T1** `FrameTemplate` / `FrameLayer` / 4 种 layer / `WatermarkPosition` 加 `@HiveType` (typeId 2–6)
- [ ] **M2-T2** 内置 3 套模板：Classic White / Camera Watermark / Soft Edge
- [ ] **M2-T3** `FrameRenderer` 渲染器（`compute` 隔离，输入 bytes + template → bytes）
- [ ] **M2-T4** 模板编辑器：图层列表 + 预览 + 属性面板 + 添加图层
- [ ] **M2-T5** 导出：详情页"套此相框" → 进度 → `gal.saveImage()` → 提示
- [ ] **M2-T6** 测试：FrameRenderer 4 种 layer 各自合成逻辑

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

## M4 — 标签 + 搜索 ⬜

- [ ] **M4-T1** `Tag` model `@HiveType(typeId: 8)`
- [ ] **M4-T2** `TagRepository` 完整 CRUD + 删除保护
- [ ] **M4-T3** 标签管理页
- [ ] **M4-T4** Lightroom 风格选择器（已选 + 全部 + 搜索）
- [ ] **M4-T5** `SearchFilter` model（纯 dart）
- [ ] **M4-T6** 搜索页：过滤条件 chip 行 + 结果网格
- [ ] **M4-T7** 4 维过滤：标签(AND/OR) / 日期 / 影集 / 相框状态
- [ ] **M4-T8** 搜索结果批量操作
- [ ] **M4-T9** 测试：TagRepository / SearchFilter.matches

**完成时间**: _待定_

---

## M5 — 批量 + 清理 ⬜

- [ ] **M5-T1** 批量套相框（含进度 sheet、并发控制）
- [ ] **M5-T2** 批量打标签
- [ ] **M5-T3** 批量删除（二次确认）
- [ ] **M5-T4** 清理模式 `/cleanup`：单图全屏 + 进度
- [ ] **M5-T5** 上滑删除 + 撤销 snackbar
- [ ] **M5-T6** 下滑/双击跳过
- [ ] **M5-T7** 防竞态：sessionId 校验
- [ ] **M5-T8** 测试：清理状态机 / 多选 Provider

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
