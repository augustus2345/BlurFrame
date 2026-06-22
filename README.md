# Photo Beauty

一个本地优先的照片管理 app — 设置相框、组合影集、Lightroom 式打标签，全部数据存在本机。

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 相框 | 内置模板 + 自定义图层（边框 / 文字水印 / 边缘模糊 / EXIF 角标） |
| 影集 | 多选照片组合成册，支持多种版式 |
| 批量相框 | 多选照片一次性套用同一模板 |
| 标签 | Lightroom 式标签，搜索过滤 |
| 批量删除 | 多选操作 |
| 清理 | 上滑单张删除，整理相册 |

## 🧱 技术栈

- **Flutter** 3.19+ / Dart 3.3+
- **状态管理** [flutter_riverpod](https://riverpod.dev/)
- **路由** [go_router](https://pub.dev/packages/go_router)
- **持久化** [Hive](https://pub.dev/packages/hive) — 结构化数据（影集、标签、相框模板、设置）
- **图片** `photo_manager`（系统相册）+ `image`（合成/水印）+ `exif`（元数据）
- **UI** Material 3 + Google Fonts (Inter)

## 🗂 目录结构

```
lib/
├── main.dart                    # 入口：初始化 Hive、锁定竖屏、挂载 Provider
├── app.dart                     # MaterialApp + 主题 + 路由
│
├── core/                        # 跨 feature 的公共设施
│   ├── theme/                   # AppColors / AppTheme (light + dark)
│   ├── router/                  # GoRouter 配置 + AppRoute 名称
│   ├── constants/               # 尺寸、Hive box 名称
│   ├── utils/                   # 扩展函数
│   └── widgets/                 # AppShell (底部导航外壳)
│
├── shared/                      # 横跨多个 feature 的服务 / 模型
│   ├── services/
│   │   ├── hive_service.dart    # Hive 启动、Box 访问
│   │   └── settings_service.dart# 设置读写
│   └── widgets/
│       ├── app_scaffold.dart    # 通用 Scaffold
│       └── empty_state.dart     # 空状态占位
│
└── features/                    # 按 feature 分模块，每个模块内部 data/presentation 分层
    ├── photos/                  # 相册主屏、清理
    │   ├── data/
    │   │   ├── models/photo_model.dart
    │   │   └── repositories/photo_repository.dart
    │   └── presentation/
    │       ├── providers/photo_provider.dart
    │       └── screens/photo_gallery_screen.dart
    │
    ├── albums/                  # 影集
    ├── frames/                  # 相框模板 (内置 + 用户自定义)
    ├── tags/                    # Lightroom 标签
    ├── search/                  # 搜索过滤
    └── settings/                # 主题、清空数据等
```

每个 feature 内部遵循：

```
feature/
├── data/
│   ├── models/        # Hive @HiveType (或纯 dart 模型)
│   ├── datasources/   # photo_manager / image / exif 等外部能力
│   └── repositories/  # 仓储层 + Riverpod provider
└── presentation/
    ├── providers/     # UI 状态 (StateNotifier / AsyncNotifier)
    ├── screens/       # 页面
    └── widgets/       # 该 feature 私有组件
```

## 🚀 跑起来

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 生成 Hive 适配器
flutter run
```

## 🛣 路由总览

| 路径 | 屏幕 |
|------|------|
| `/gallery`  | 相册（多选 / 批量操作） |
| `/albums`   | 影集列表 |
| `/frames`   | 相框模板 |
| `/search`   | 搜索 / 过滤 |
| `/settings` | 设置 |
| `/frames/editor` | 相框模板编辑器（独立 push） |
| `/photo/:id` / `/albums/:id` | 详情页（占位） |

## 📝 设计要点

1. **照片字节留在磁盘**：Hive 只存元数据（tags、相框模板引用、用户备注）。不复制原图。
2. **相框是分层合成**：`FrameTemplate = List<FrameLayer>`，渲染器按顺序合成，便于以后扩展更多图层。
3. **Riverpod 全局状态**：当前选中的相框模板、多选照片集合、过滤条件等都放 provider 里，避免 prop drilling。
4. **底部导航保留状态**：使用 `ShellRoute`，切 tab 不丢页内状态。
5. **Material 3 + 中性色 + 暖色 accent**：突出照片本身，UI 退到背景。
