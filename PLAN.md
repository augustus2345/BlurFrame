# Photo Beauty — 项目计划（PLAN.md）

> 与 [PRD.md](./docs/prd/PRD.md) 配套。  
> 状态：🟡 进行中 / ✅ 已完成 / ⬜ 未开始 / 🔒 阻塞

---

## 0. 当前状态速览

- **PRD**: ✅ v0.1（[docs/prd/PRD.md](./docs/prd/PRD.md)）
- **工程骨架**: ✅ 主题 / 路由 / Shell / Hive 启动 / 设置服务已就位
- **M0**: ✅ 基础完成（测试 + 文档注释 + 依赖检查 + registerAdapters 占位 + `flutter run` 推至 M1）
- **M1**: 🟡 进行中（T1 权限引导已完成；T2-T10 占位）
- **M2–M5**: ⬜ 全部为占位 EmptyState，待实现
- **M6**: ⬜ 打磨 + Integration test

---

## 1. 里程碑总览

| ID | 名称 | 状态 | 估时 | 累计 |
| --- | --- | --- | --- | --- |
| M0 | 基础设施 | ✅ 完成 | 0.5d | 0.5d |
| M1 | 照片库 | 🟡 | 1.0d | 1.5d |
| M2 | 相框模板 | ⬜ | 2.0d | 3.5d |
| M3 | 影集 | ⬜ | 1.0d | 4.5d |
| M4 | 标签 + 搜索 | ⬜ | 1.0d | 5.5d |
| M5 | 批量 + 清理 | ⬜ | 1.0d | 6.5d |
| M6 | 打磨 | ⬜ | 1.0d | 7.5d |

> 每个里程碑结束必须：✅ 跑通主链路 / ✅ `flutter analyze` 通过 / ✅ `flutter test` 通过 / ✅ TASKS.md 已勾选。

---

## 2. 里程碑详情

### M0 — 基础设施 ✅（2026-06-22 完成）

**目标**: 跑得起来，4 tab 切换不丢状态，主题/明暗切换可用，Hive 读写正常。

**已就位**:
- `lib/main.dart` — 入口 + 锁定竖屏 + 初始化 Hive
- `lib/app.dart` — `MaterialApp.router` + 主题
- `lib/core/router/app_router.dart` — `go_router` + 5 tab ShellRoute
- `lib/core/theme/{app_theme,app_colors}.dart` — Material 3 + 暖色 accent
- `lib/core/widgets/app_shell.dart` — 底部 NavigationBar
- `lib/core/constants/app_constants.dart` — Hive box 名 + 尺寸常量
- `lib/shared/services/{hive_service,settings_service}.dart` — Hive 启动 + 主题持久化
- `lib/features/.../presentation/screens/*_screen.dart` — 5 个占位 screen

**还需补完**:
- 5 个 screen 的中文文档注释（CLAUDE.md §1.6）✅ M0-T1
- `app_shell.dart` `_indexFromLocation` 用 `startsWith` 在子路由下高亮有问题，需要 `==` 匹配或前缀参数 ✅ M0-T2
- `frame_repository.dart` 缺少 delete 时的内置模板保护（`isBuiltIn` 不可删）✅ M0-T3
- `hive_service.dart` 需要在 `registerAdapters` 里挂上 `PhotoModel` / `FrameTemplate` / `AlbumModel` / `TagModel` 的 `@HiveType` 适配器（M1 起需要）✅ M0-T4（占位 + try/catch）
- 单元测试：`SettingsService` 读写测试 ✅ M0-T5、`HiveService` box 打开测试 ✅ M0-T6
- 验证：`flutter pub get` + `dart run build_runner build` + `flutter run` 🟡 M0-T7（`pub get` / `analyze` / `test` 已过；`flutter run` 待用户交互）

**验证**:
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

---

### M1 — 照片库 🟡（2026-06-22 开始，T1 完成）

**目标**: 看到系统照片、双指缩放、长按多选、详情页 EXIF。

**任务拆解**:
1. 权限引导页（首启），复用 `SettingsService.isFirstLaunch()`
2. `photo_manager` 集成：`PhotoManager.requestPermissionExtend()` → `PhotoManager.getAssetPathList()` → `AssetEntity`
3. `PhotoRepository` 改造：增加 `loadAllFromSystem()` 返回 `Stream<List<AssetEntity>>` + 系统 + Hive 合并（带元数据）
4. `PhotoModel` 加 `@HiveType(typeId: 1)`，用 `hive_generator` 生成 `PhotoModelAdapter`
5. 网格页（3 列，`flutter_staggered_grid_view` 或 `GridView.builder`），缩略图走 `AssetEntity.thumbnailDataWithSize`
6. 详情页：`PhotoView` / `InteractiveViewer` 实现双指缩放、双击放大/还原
7. 长按 → 进入多选模式，Provider 维护 `Set<String> selectedIds`
8. EXIF 解析：用 `exif` 包读 `AssetEntity.originBytes` → `ExifData` → 提取 `Make`/`Model`/`DateTimeOriginal`/`FNumber`/`ExposureTime`/`ISOSpeedRatings`/`FocalLength`
9. 4 态显式：`loading` / `success` / `error`(权限拒绝) / `empty`(无照片)

**新增文件**:
- `lib/features/photos/data/datasources/photo_manager_datasource.dart`
- `lib/features/photos/data/datasources/exif_datasource.dart`
- `lib/features/photos/presentation/widgets/photo_grid_item.dart`
- `lib/features/photos/presentation/widgets/photo_multi_select_app_bar.dart`
- `lib/features/photos/presentation/screens/photo_detail_screen.dart`
- `lib/features/photos/presentation/screens/permission_request_screen.dart`
- `test/features/photos/...` 单元测试 + widget 测试

---

### M2 — 相框模板 ⬜

**目标**: 3 套内置模板、模板列表、模板编辑器、渲染器、导出。

**任务拆解**:
1. `FrameTemplate` / `FrameLayer` 加 `@HiveType`（typeId 2–6：模板 + 4 种 layer + position 枚举）
2. `FrameRepository.builtInTemplates()` 注入 3 套：
   - **Classic White** — `BorderLayer` 12px 白色 + 8px 圆角
   - **Camera Watermark** — `WatermarkLayer` 底部右侧"📷 {Make} {Model} · {DateTimeOriginal}"
   - **Soft Edge** — `BlurLayer` intensity 8，仅边缘
3. `FrameRenderer`：
   - 输入：`Uint8List sourceBytes` + `FrameTemplate`
   - 用 `image` 包 `decodeImage` → `drawImage` / `fillRect` / `drawString` 合成
   - EXIF 角标需要先读 EXIF 拿字段再合成
   - 走 `compute()` 隔离
   - 输出：`Uint8List jpegBytes`
4. 模板编辑器 `/frames/editor`：
   - 左侧图层列表（拖拽重排）
   - 中间预览（实时套用样图）
   - 右侧属性面板（颜色/字体/位置/偏移/缩放）
   - 底部"+ 添加图层"按钮
5. 导出流程：照片详情页"套此相框" → 进度条 → `gal.saveImage()` 到系统相册 → 提示成功
6. 测试：
   - `FrameRenderer.render` 输入固定 fixture → 输出字节长度 / 尺寸稳定
   - 4 种 layer 各自的合成逻辑单测
   - widget：编辑器添加图层 → 列表出现

**新增文件**:
- `lib/features/frames/data/datasources/frame_renderer.dart`（`compute` 函数）
- `lib/features/frames/presentation/widgets/layer_editor_panel.dart`
- `lib/features/frames/presentation/widgets/frame_preview_canvas.dart`
- `lib/features/frames/presentation/widgets/layer_draggable_list.dart`
- `test/features/frames/frame_renderer_test.dart`

---

### M3 — 影集 ⬜

**目标**: 影集列表、详情、多版式、封面、拖拽重排。

**任务拆解**:
1. `Album` model：`@HiveType(typeId: 7)`，字段 `id` / `name` / `coverAssetId` / `photoIds` / `layout` / `createdAt` / `updatedAt`
2. `AlbumRepository`：`create` / `rename` / `addPhotos` / `removePhotos` / `reorderPhotos` / `setCover` / `setLayout` / `delete`
3. 影集列表页：2 列网格，封面 = `coverAssetId` 套默认相框后的缩略图
4. 新建影集：底部 sheet → 输名称 + 选照片 + 选版式
5. 详情页：版式 `autoLayout(N)` 自动选；手动可选 `1/2/3/4` 宫格
6. 拖拽重排：`ReorderableListView` 持久化到 `photoIds`
7. 换封面：详情页右上"换封面" → 选一张
8. 4 态：loading / success / error / empty（"还没有影集，长按照片创建"）

**新增文件**:
- `lib/features/albums/data/models/album_model.dart`（替换 placeholder）
- `lib/features/albums/data/repositories/album_repository.dart`（替换 placeholder）
- `lib/features/albums/presentation/screens/album_detail_screen.dart`
- `lib/features/albums/presentation/screens/album_create_screen.dart`
- `lib/features/albums/presentation/widgets/album_layout_grid.dart`
- `test/features/albums/album_repository_test.dart`

---

### M4 — 标签 + 搜索 ⬜

**目标**: Lightroom 式打标签、4 维过滤、搜索结果再操作。

**任务拆解**:
1. `Tag` model：`@HiveType(typeId: 8)`，字段 `id` / `name` / `color`（ARGB int）/ `createdAt`
2. `TagRepository`：`create` / `rename` / `setColor` / `delete`（被引用时禁止裸删，先解绑）
3. 标签管理页：所有标签列表（chip 样式），点击进详情（修改/删除）
4. Lightroom 风格选择器：照片详情页"添加标签" → 弹出底部 sheet，左侧是"已选标签"色块，右侧是"所有标签"列表，搜索框快速过滤
5. `SearchFilter` model：纯 dart（不存 Hive），`tagIds` / `dateRange` / `albumId` / `framedState`
6. 搜索页：顶部过滤条件 chip 行（点开弹选择 sheet），下方结果网格
7. 4 维过滤：标签（多选 + AND/OR）/ 日期（预设 + 自定义）/ 影集（单选）/ 相框状态（all/framed/unframed）
8. 搜索结果支持多选 → 批量打标签 / 批量删除
9. 4 态：loading / success / error / empty（"没有匹配的照片"）

**新增文件**:
- `lib/features/tags/data/models/tag_model.dart`（替换 placeholder）
- `lib/features/tags/data/repositories/tag_repository.dart`（替换 placeholder）
- `lib/features/tags/presentation/screens/tag_manager_screen.dart`
- `lib/features/tags/presentation/widgets/tag_picker_sheet.dart`
- `lib/features/search/data/repositories/search_repository.dart`
- `lib/features/search/presentation/widgets/filter_chip_bar.dart`
- `lib/features/search/presentation/widgets/date_range_picker_sheet.dart`
- `test/features/tags/tag_repository_test.dart`
- `test/features/search/search_filter_test.dart`

---

### M5 — 批量 + 清理 ⬜

**目标**: 批量套相框、批量打标签、批量删除、清理模式。

**任务拆解**:
1. 多选模式已经在 M1 实现
2. 批量套相框：多选 → 选模板 → `FrameRenderer` 串行/并行渲染（限制并发 2 防 OOM）→ 进度 sheet → 完成后 snackbar + 跳到系统相册新图
3. 批量打标签：多选 → 选标签 → 写入 `PhotoModel.tags`
4. 批量删除：多选 → 二次确认 sheet（带"也删除原图"开关，提示只能删 App 写入的副本）→ 调用 `PhotoManager.deleteAsset` 或本地
5. 清理模式 `/cleanup`：
   - 单张大图全屏
   - 顶部进度："已处理 N / M"
   - 上滑 → 删除 + 自动下一张（带撤销 snackbar 5s）
   - 下滑 / 双击 → 跳过
   - 暂停 / 退出按钮
6. 防竞态：每个流程分配 `sessionId`，UI 状态变更前校验
7. 撤销栈：内存 `Queue<({assetId, sessionId})>`，snackbar 触发则弹回

**新增文件**:
- `lib/features/photos/presentation/screens/cleanup_screen.dart`
- `lib/features/photos/presentation/providers/cleanup_provider.dart`
- `lib/features/photos/presentation/providers/multi_select_provider.dart`
- `lib/features/photos/presentation/widgets/batch_action_sheet.dart`
- `test/features/photos/cleanup_state_machine_test.dart`
- `test/features/photos/multi_select_provider_test.dart`

---

### M6 — 打磨 ⬜

**目标**: 4 态显式、暗色模式、性能、Integration test、README 同步。

**任务拆解**:
1. 全局 `AsyncValue.when(loading, error, data)` 包裹，补 `EmptyState` 复用
2. 暗色模式过一遍：照片卡片背景、NavigationBar、Snackbar、输入框
3. 性能：1000 张照片下分页加载（每页 60 张），缩略图缓存用 `cached_network_image` 思路自实现 LRU
4. Integration test：开 App → 授权（mock）→ 看到网格 → 进详情 → 套内置模板 → 看到导出成功 snackbar
5. 错误处理：渲染失败时给"重试"、权限被拒给"去设置"
6. README 同步：跑起来的步骤、目录结构、关键决策

**新增文件**:
- `integration_test/main_flow_test.dart`
- `test/widgets/empty_state_test.dart`
- 性能压测脚本（可选）

---

## 3. 跨里程碑约束

- **写测试再写实现**（CLAUDE.md §1.3）：每个新功能先写测试定义预期
- **单文件 ≤ 500 行**（CLAUDE.md §1.4）：超了就按职责拆
- **Provider 走代码生成**（CLAUDE.md §6.3）：用 `riverpod_generator` 标注后跑 `build_runner`
- **每次改动立即可运行**（CLAUDE.md §1.5）：不允许"攒大变更"
- **最小改动**（CLAUDE.md §1.8）：只动当前任务相关文件

---

## 4. 风险追踪

| # | 风险 | 状态 | 应对 |
| --- | --- | --- | --- |
| R1 | `photo_manager` Android 厂商适配 | M1 验证 | 适配层 try/catch |
| R2 | 大图渲染内存峰值 | M2 验证 | 三档尺寸 + compute 隔离 |
| R3 | EXIF 在合成后丢失 | M2 验证 | 合成时把 EXIF 写回 |
| R4 | 上滑手势与系统返回冲突 | M5 验证 | 显式方向判定 |
| R5 | Hive typeId 冲突 | M1+ 提前规划 | typeId 1–10 预分配 |

---

## 5. 文档维护规则

- 任务勾选在 [TASKS.md](./TASKS.md) 操作
- 里程碑状态变化在本文档 §1 / §2 操作
- PRD 变更需更新版本号 + 修订记录
- 每周回顾：检查"是否还符合 PRD"
