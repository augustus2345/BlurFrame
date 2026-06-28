# Photo Beauty

一个本地优先的照片管理 app — 设置相框、组合影集、Lightroom 式打标签，全部数据存在本机。

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 相册 | 系统照片网格、缩略图懒加载、详情页 EXIF 展示 |
| 相框 | 2 套内置模板 + 自定义编辑器（模糊边框 / 文字水印 / 颜色条 3 层） |
| 影集 | 多选照片组合成册，支持 1/2/3/4 宫格版式、拖拽重排、换封面 |
| 标签 | Lightroom 式标签管理、搜索过滤 |
| 星级 | 0–5 星评级，支持 ≥N / =N 搜索 |
| 批量操作 | 批量套模版 / 打标签 / 加星 / 加影集 / 删除 |
| 删除 tab | 单图全屏、上滑删除（带 5s 撤销）、左右滑切换 |
| 搜索 | 5 维过滤（标签 AND/OR / 星级 / 日期 / 影集 / 模版状态） |

## 🧱 技术栈

- **Flutter** 3.19+ / Dart 3.3+
- **状态管理** [flutter_riverpod](https://riverpod.dev/)（`AsyncNotifier` / `Notifier` 模式）
- **路由** [go_router](https://pub.dev/packages/go_router)（`ShellRoute` 保留 tab 状态）
- **持久化** [Hive](https://pub.dev/packages/hive) — 结构化数据（照片、影集、标签、相框模板、设置）
- **图片** `photo_manager`（系统相册）+ `image`（合成/水印）+ `exif`（元数据解析）
- **导出** `gal`（保存到系统相册）
- **UI** Material 3 + 暖色 accent，暗色模式完整支持

## 🗂 目录结构

```
lib/
├── main.dart                        # 入口：初始化 Hive、锁定竖屏、挂载 Provider
├── app.dart                         # MaterialApp + 主题 + 路由
│
├── core/                            # 跨 feature 的公共设施
│   ├── constants/                   # Hive box 名称、尺寸常量
│   ├── router/                      # GoRouter 配置 + AppRoute 名称常量
│   ├── theme/                       # AppColors / AppTheme (light + dark)
│   ├── utils/                       # 扩展函数、LRU 缓存
│   └── widgets/                     # AppShell (底部 5 tab 导航外壳)
│
├── shared/                          # 横跨多个 feature 的服务
│   └── services/
│       ├── hive_service.dart       # Hive 启动、Box 访问、适配器注册
│       └── settings_service.dart    # 设置读写（主题、首启标志等）
│
└── features/                       # 按 feature 分模块，data/presentation 分层
    ├── photos/                      # 相册主屏、详情、批量、删除
    │   ├── data/
    │   │   ├── models/              # PhotoModel (Hive)
    │   │   ├── datasources/         # PhotoManagerDatasource / ExifDatasource
    │   │   └── repositories/        # PhotoRepository
    │   └── presentation/
    │       ├── providers/           # PhotosNotifier / MultiSelectProvider 等
    │       ├── screens/             # PhotoGalleryScreen / PhotoDetailScreen 等
    │       └── widgets/             # PhotoGridItem / StarRating / BottomActionBar 等
    │
    ├── albums/                       # 影集列表、详情、创建
    │   ├── data/
    │   │   ├── models/              # AlbumModel (Hive) / AlbumLayout 枚举
    │   │   └── repositories/        # AlbumRepository
    │   └── presentation/
    │       ├── providers/           # AlbumListNotifier / AlbumDetailNotifier
    │       ├── screens/             # AlbumListScreen / AlbumDetailScreen 等
    │       └── widgets/             # AlbumGridItem / CoverPickerSheet 等
    │
    ├── frames/                       # 相框模板列表、编辑器、渲染器
    │   ├── data/
    │   │   ├── models/              # FrameTemplate / BlurBorderLayer / TextWatermarkLayer / ColorStripeLayer (Hive)
    │   │   └── repositories/        # FrameRepository
    │   └── presentation/
    │       ├── providers/           # FrameTemplateListNotifier / TemplateEditorNotifier
    │       ├── screens/             # FrameTemplateListScreen / FrameTemplateEditorScreen
    │       └── widgets/             # FramePreview / LayerSwitchGroup 等
    │
    ├── tags/                         # 标签管理、Lightroom 风格选择器
    │   ├── data/
    │   │   ├── models/              # TagModel (Hive)
    │   │   └── repositories/        # TagRepository
    │   └── presentation/
    │       ├── providers/           # TagListNotifier / TagDetailNotifier
    │       ├── screens/             # TagManagerScreen / TagDetailScreen
    │       └── widgets/             # TagListItem / TagPickerSheet
    │
    ├── search/                       # 搜索二级页（push，入口在相册 tab 搜索按钮）
    │   ├── data/
    │   │   └── repositories/        # SearchRepository / SearchFilter
    │   └── presentation/
    │       ├── providers/           # SearchFilterProvider / SearchResultsProvider
    │       ├── screens/             # SearchScreen
    │       └── widgets/             # FilterChipBar / StarRatingFilterSheet 等
    │
    └── settings/                    # 主题、清空数据
```

每个 feature 内部遵循：

```
feature/
├── data/
│   ├── models/        # Hive @HiveType 模型（或纯 dart 值对象）
│   ├── datasources/   # photo_manager / image / exif 等外部能力封装
│   └── repositories/  # 仓储层 + Riverpod provider 导出
└── presentation/
    ├── providers/     # UI 状态 (AsyncNotifier / Notifier)
    ├── screens/       # 页面（Screen）
    └── widgets/       # 该 feature 私有组件（Widget）
```

## 🚀 跑起来

```bash
# 安装依赖
flutter pub get

# 生成 Hive 适配器（首次运行或 model 变更后）
dart run build_runner build --delete-conflicting-outputs

# 运行 app（需要 Android/iOS 真机或模拟器）
flutter run

# 运行单元测试 + widget 测试
flutter test

# 运行集成测试（需要真机）
flutter test integration_test -d macos
```

### 平台要求

- **iOS**: `photo_manager` 需要相册权限（首次启动引导授权）
- **Android**: 同上，需要存储权限
- macOS 测试支持有限（照片权限需手动授权）

## 🛣 路由总览

| 路径 | 屏幕 | 备注 |
|------|------|------|
| `/gallery` | 相册（多选 / 批量操作） | 底部 tab 1 |
| `/albums` | 影集列表 | 底部 tab 2 |
| `/frames` | 相框模板 | 底部 tab 3 |
| `/delete-viewer` | 删除 tab（单图全屏 + 手势） | 底部 tab 4 |
| `/settings` | 设置 | 底部 tab 5 |
| `/search` | 搜索 / 过滤 | push（在相册 tab 内） |
| `/frames/editor` | 相框模板编辑器 | push（沉浸式） |
| `/frames/editor?templateId=xxx` | 编辑已有模板 | 同上 |
| `/photo/:id` | 照片详情页 | push（沉浸式） |
| `/albums/:id` | 影集详情页 | push（沉浸式） |
| `/albums/create` | 新建影集 | push |
| `/tags` | 标签管理 | push（沉浸式） |
| `/tags/:id` | 标签详情 | push（沉浸式） |

## 📝 设计要点

### 架构决策

1. **照片字节留在磁盘**：Hive 只存元数据（tags、starRating、相框模板引用）。不复制原图到 app 沙盒。

2. **相框是分层合成**：`FrameTemplate = List<FrameLayer>`（`BlurBorderLayer` / `TextWatermarkLayer` / `ColorStripeLayer`），渲染器按 z-order 顺序合成。扩展新图层只需新增 `FrameLayer` 子类 + 合成函数。

3. **4 态显式**：`AsyncValue.when(loading, error, empty, data)` 覆盖所有异步加载点，loading 用 `pump()` 而非 `pumpAndSettle()` 避免 spinner 动画导致测试超时。

4. **防竞态**：每个异步流程分配 `sessionId` / `UndoEntry`，UI 回调时校验标识是否仍有效，过期则丢弃。

5. **Batch 任务并发控制**：批量套模版每批 2 张（`Future.wait`），避免 1000+ 照片时 OOM。

6. **缩略图 LRU 缓存**：基于 `LinkedHashMap` 的 `LruCache<K, V>`（maxSize=100，约 2–5MB），同一 assetId 后续直接从缓存返回。

7. **分页加载**：系统相册流式分页（每页 60 张），`loadAllFromSystem()` 边取边合并，不在内存堆积。

### Hive TypeId 规划

| typeId | 类型 |
|--------|------|
| 1 | PhotoModel |
| 2 | FrameTemplate |
| 4 | BlurBorderLayer |
| 5 | TextWatermarkLayer |
| 6 | ColorStripeLayer |
| 7 | AlbumModel |
| 8 | TagModel |
| 9 | WatermarkPosition |
| 10 | StripePosition |
| 11 | AlbumLayout |

## 🧪 测试

```bash
# 所有测试
flutter test

# 带 coverage
flutter test --coverage

# 集成测试（需真机）
flutter test integration_test -d macos
flutter test integration_test -d android
```

### 测试踩坑记录（见 `CLAUDE.md §7`）

- **Hive 适配器幂等**：`isAdapterRegistered(N)` 守卫防止跨测试文件重注册
- **mocktail `Box.clear()` 返回**：`Future<int>` 不是 `Future<void>`，用 `thenAnswer((_) async => 0)`
- **`pumpAndSettle` + 永动 widget**：loading 态测试用 `pump()` 单帧推进
- **`image` 4.x `gaussianBlur` in-place**：需要 `source.clone()` 保留原图
- **EXIF tag 名是字符串 key**：`exif` 3.3.0 API 是 `Map<String, IfdTag>` 而非类型化 getter
