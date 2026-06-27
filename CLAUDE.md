# CLAUDE.md - Claude Code 工作规范

## 1 核心原则

你是 Claude Code，在本仓库内协助完成开发任务。首要目标是按计划稳定推进，保持改动可验证。

1. **文件驱动** — 决策写进 PLAN.md / TASKS.md，不依赖聊天记忆
2. **单任务聚焦** — 一次只做一件事，做完再下一件
3. **测试先行** — 先写测试定义预期，再写实现代码，保证结果的正确性
4. **功能解耦** — 每个模块独立可测，不耦合无关逻辑；单文件 ≤500 行，单函数 ≤50 行
5. **逐步验证** — 每次改动立即可运行、可检查，不攒大变更
6. **注释完善** — 文件、函数、核心逻辑必须有中文文档注释，符合 Dart doc comment 规范
7. **文档同步** — 代码改完，立刻更新 TASKS.md（勾选任务、记录完成时间）和 PLAN.md（里程碑进度）
8. **最小改动** — 只改当前任务相关的文件和代码，不做额外重构
9. **类型安全** — 避免 dynamic、as 强转、!非空断言，优先使用类型安全写法

---

## 2 Flutter 应用开发原则

### 2.1 核心原则
1. 优先保证结构清晰，不要过度设计。
2. 按职责拆分，不按页面外观拆分。
3. 保持单向数据流：UI 触发动作，controller 更新 state，UI 根据 state 渲染。
4. UI 和业务逻辑分离，widget 不承载复杂业务逻辑。
5. 优先简单、直接、稳定的方案。

### 2.2 分层职责
6. Screen/Page 负责页面组装、路由参数、读取 provider、分发回调。
7. Widget 负责展示和局部交互，尽量保持纯。
8. Provider/Notifier 负责状态和业务逻辑。
9. Repository 负责数据获取和持久化，不负责业务流程编排。
10. Model 表示业务数据，State 表示界面运行状态。Model 不依赖 State，State 可以包含 Model。

### 2.3 状态管理
11. Provider 按功能域拆分，不按组件个数拆分，也不按页面外观拆分。
12. 状态只在一个 widget 树内使用且不需要跨组件共享时，用局部 state；否则用 provider。
13. 一份真实状态只能有一个单一来源，避免多处维护同一状态。
14. 状态变更入口要集中，只能通过明确的方法修改状态。
15. 复杂流程提取为纯 Dart 类编排（可测试、可复用），Provider 负责连接编排层和 UI。

### 2.4 Widget 设计
16. 页面负责组装，组件负责展示。
17. 不要做万能组件，避免大量 if 和模式开关。参数超过 10 个说明职责太广，应该拆分。
18. build 方法只描述 UI，不做请求、不改状态、不启动副作用。
19. 子组件只读取自己关心的状态，避免整页无意义刷新。

### 2.5 可靠性
20. 异步操作必须防竞态：启动时记录标识（token/sessionId），回调时校验标识是否仍有效，过期则丢弃。
21. 谁创建谁销毁。资源的生命周期必须和它的所有者绑定，不能由外部隐式管理。
22. 副作用（网络请求、文件 IO、平台调用）通过接口或回调注入，不在业务逻辑类中直接调用。
23. 每个异步调用点都要考虑失败情况。沉默吞掉异常是 bug，应该明确处理或向上传播。
24. 错误、加载、空状态必须显式设计，不要只写成功态。

### 2.6 可维护性
25. 命名优先于技巧，名称必须直接表达职责。
26. 目录结构优先按 feature 组织，再在 feature 内部分层。
27. 先允许少量重复，确认模式稳定后再抽象。过早抽象比重复更有害。
28. 优先测试状态流转和业务逻辑，不要只测 UI 表面。


## 3 启动流程（每个会话强制执行）

开始任何工作前，必须按顺序完成以下 4 步：

1. 读取 PLAN.md — 了解项目当前阶段和整体规划
2. 读取 TASKS.md — 了解待办任务列表和优先级
3. 输出要执行的任务 — 明确说明接下来做哪一个任务（一次只做一个）
4. 等待用户确认 — 用户同意后再开始修改代码

---

## 4 收尾流程（每次完成任务强制执行）

完成当前任务后，必须按顺序完成以下 7 步：

### 步骤 1: 检查测试完整性
确认以下测试是否已覆盖：
- **Unit Test**: 纯逻辑测试（模型、服务、辅助类），不涉及 UI
- **Widget Test**: 组件级 UI 测试
- **Integration Test**: 端到端（E2E）测试，验证完整用户流程

### 步骤 2: 删除死代码
检查是否存在未使用的代码（包括测试中的），有则删除。

### 步骤 3: 检查注释和文档
确保新增/修改的代码有清晰的中文注释。

### 步骤 4: 运行验证命令
```bash
flutter analyze
flutter test
flutter test integration_test -d macos
```

### 步骤 5: 更新 TASKS.md
```markdown
# 必须完成：
1. 勾选已完成任务（- [x]）
2. 在任务下添加完成记录：

  **完成时间**: 2026-01-31
```

### 步骤 6: 更新 PLAN.md（如有需要）
如果本次任务导致里程碑进度变化，必须更新 PLAN.md 中对应里程碑的状态。

### 步骤 7: 输出完成摘要
```markdown
**实现的任务**: [任务标题]
**修改的文件** (X 个):
- path/to/file.dart (+50 -10)
**对应的测试**:
- path/to/test_file.dart
**下一步建议**:
- 告诉用户如何验证结果
- 下一个任务是什么
```

---

## 5 TASKS.md 归档规则

满足以下任一条件时，必须执行归档：
1. **里程碑完成** — PLAN.md 中某个 Milestone 全部完成
2. **文件过大** — TASKS.md 超过 200 行
3. **任务过多** — 已完成任务超过 30 条
4. **手动触发** — 用户明确要求归档

归档步骤：
1. 创建归档文件：`docs/tasks-archive/milestone-X-completed.md`
2. 将已完成任务移入归档文件
3. 清理 TASKS.md，仅保留未完成任务
4. 在 TASKS.md 顶部添加归档链接
5. 更新 PLAN.md 里程碑状态

---

## 6 编码规范

### 6.1 Dart / Flutter 约定
- 使用 `flutter_lints` 静态分析，配置见 `analysis_options.yaml`
- 格式化：`dart format .`
- 国际化：`flutter_localizations` + ARB 文件（`lib/l10n/`），模板文件为 `app_en.arb`，当前支持 en / zh

### 6.2 测试约定
- 框架：`flutter_test` + `mocktail`
- 文件命名：`*_test.dart`，放在 `test/` 对应子目录下
- 每个新功能或 bug 修复必须包含对应测试

### 6.3 Riverpod 代码生成
- Provider 使用 `riverpod_generator` 代码生成，文件包含 `part 'xxx.g.dart';`
- 修改 Provider 后运行：`dart run build_runner build`

---

## 7 踩坑记录（Pitfalls）

> 记录本项目踩过的坑，方便下次遇到同样症状时快速对照。
> 格式：**症状 → 根因 → 修法 → 适用**。
> 维护原则：发现新坑就加一条；修法被新方案替代时打 ❌ 并附替代方案。

### 7.1 Hive `registerAdapter` 跨测试文件不可重入
- **症状**: 测试套件跑两个文件时，第二个文件的 `initForTest` 抛 `HiveError: Adapter for typeId 1 is already registered`，连带 `_completeInit` 中断 → `Hive.box(name)` 报 box 未开
- **根因**: Hive 全局注册表 `Hive._typeAdapters` 在测试间共享；`Hive.close()` + `resetForTest()` **只清 box 和 `_initialized` 标志，不清适配器**
- **修法**: `HiveService.registerAdapters()` 改为幂等，**每个 adapter 注册前加 `isAdapterRegistered(N)` 守卫**
  ```dart
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(PhotoModelAdapter());
  }
  ```
- **适用**: 所有 `registerAdapters` 路径；任何会跨测试 / 热重载复用的初始化点都该幂等

### 7.2 mocktail `Box.clear()` 返回类型不匹配
- **症状**: `when(() => box.clear()).thenAnswer((_) async {})` 报 `body_might_complete_normally`（期望 `Future<int>`，拿到 `Future<void>`）
- **根因**: `Box.clear()` 返回 `Future<int>`（被删条数），不是 `Future<void>`。同样 `Box.compact()`
- **修法**: `thenAnswer((_) async => 0)`
- **适用**: 所有返回 `Future<int>` 的 `Box` 方法；写新 mock 时先查 Hive 源码确认返回类型

### 7.3 Dart flow analysis 与 `late` + `setUp`
- **症状**: 顶层声明 `late int callCount;`，`setUp` 里赋值 → 报 `non-nullable local variable 'callCount' must be assigned before it can be used`
- **根因**: Dart 静态分析保守地认为 `setUp` 可能抛，导致编译器认为变量可能未被赋值（即使人眼看 `setUp` 总会跑）
- **修法（任一）**:
  1. **inline 初值**：声明时给初值（去掉 `late`），`setUp` 里再覆盖
  2. **包对象**：`class _Scratch { int callCount = 0; }` 创建一次实例，Dart 看到字段有初值就满意
- **适用**: 测试夹具里多个 mutable scratch 状态变量时优先选方案 2

### 7.4 `ConsumerStatefulWidget.initState` 不能直接调 `ref.read` 触发的异步
- **症状**: `initState` 里 `ref.read(notifier).asyncMethod()` 后续断言不通过 / Riverpod 报 `tried to use ref during build`
- **根因**: 初始化阶段 widget 树未完成，async 副作用调度时机不稳；Riverpod 2.x 拒绝在 build 阶段被外部 mutate
- **修法**: 推后到 `addPostFrameCallback`，并加 `mounted` 守卫：
  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    ref.read(notifier.notifier).refresh();
  });
  ```
- **适用**: 需要在 widget mount 后立刻触发的 async 副作用（读权限、读网络、读 Hive、订阅流）

### 7.10 `exif` 3.3.0 没有类型化 getter，tag 名是字符串 key
- **症状**: 按 `ExifData.ifd0.make` / `ExifIfdData.dateTimeOriginal` 写代码编译失败 → `The getter 'ifd0' isn't defined for type 'ExifData'`
- **根因**: `exif: ^3.3.0` 的 API 是**平铺 map**，不是类型化对象：
  - `readExifFromBytes(List<int> bytes) → Future<Map<String, IfdTag>>`（返回 `Future<Map>`，不是 `ExifData` 实例）
  - map 的 key 是 `"<IFD> <TagName>"` 字符串（`'Image Make'` / `'EXIF DateTimeOriginal'` 等）
  - 每个 `IfdTag.values` 是 `IfdValues` 子类：`IfdInts` / `IfdRatios`（含 `Ratio(num, den)`）/ `IfdBytes` / `IfdNone`
  - `DateTimeOriginal` 是 **19 字节 ASCII** `"YYYY:MM:DD HH:MM:SS\0"`，**不是** `DateTime`
- **修法**:
  1. 用 `readExifFromBytes(bytes)` 拿到 `Map<String, IfdTag>`
  2. 按字符串 key 取字段：`tags['Image Make']` / `tags['EXIF DateTimeOriginal']`
  3. 用 `is IfdRatios` / `is IfdInts` / `is IfdBytes` 做类型守卫
  4. DateTimeOriginal：`String.fromCharCodes(bytes.sublist(0, 19))` + `DateFormat('yyyy:MM:dd HH:mm:ss').tryParse(...)`
  5. **`IfdNone` 陷阱**：`IfdNone.firstAsInt() == 0`（不是抛错），必须用 `is IfdInts && v.ints.isNotEmpty` 守卫，否则缺失 ISO 会被读成 0
- **适用**: 任何 `exif` 3.x 集成；写之前先看本地的 `~/.pub-cache/hosted/pub.dev/exif-3.3.0/lib/src/exif_types.dart` 确认类型结构

### 7.5 Riverpod `Notifier.build()` 必须是同步
- **症状**: 想在 `Notifier.build()` 里 `await repo.current()` 编译失败
- **根因**: `Notifier<T>.build()` 签名是 `T build()`，同步；想用 `await` 必须升 `AsyncNotifier`，且 `AsyncNotifier` 仍不能在 `build` 内 await（`build` 是同步的初始化钩子，真正的 await 走 `future` / `AsyncValue.guard`）
- **修法**: `build()` 返回**默认值**（`null` / 占位 enum），异步初始化在外部触发 `refresh` / 第一次 `notifier.method()` 时拉
- **适用**: 所有 Riverpod 2.x `Notifier` / `AsyncNotifier`；同理 `build()` 内不应做 IO

### 7.6 `Completer` 测试的 mock 完整性（中间态断言）
- **症状**: 测试用 `Completer<PermissionState>` 控制 `request` 时机，中间态断言通过，但 `completer.complete()` 后最终断言失败，提示 `type 'Null' is not a subtype of type 'Future<void>'`
- **根因**: 通过自定义闭包绕过 `result` 路径时，await 之后还会触发的副作用（`markFirstLaunchDone` → `box.put`）**仍会跑**，但 mock 没设
- **修法**: 写带 `Completer` 的测试时，先在脑里走一遍"completer 完成后还会触发什么副作用"，提前 mock；不要只 mock 中间态涉及的函数
- **适用**: 所有"中间态断言 + 最终态断言"的两段式测试

### 7.7 `PhotoModel` 等 Hive model 的 HiveField 编号不可重用
- **症状**: 给已有 model 加新字段时，用了旧编号 → 旧 box 数据反序列化时新字段全 `null`、旧字段被覆盖
- **根因**: Hive 用 `fieldId → value` map 持久化，重用编号会让旧值被当成新字段读
- **修法**:
  1. 新字段**只能往下编**（0,1,2,... 顺序追加）
  2. 删字段时**保留编号空位**，注释标注 `// removed: 字段名，曾经是 XXX`
  3. HiveField 编号变更属于**破坏性 schema 变更**，需要走 `Box.deleteFromDisk` + 数据迁移
- **适用**: 所有 `@HiveType` 模型的字段演化管理

### 7.8 `photo_manager` 的 `getPermissionState` 必须传 `requestOption`
- **症状**: `PhotoManager.getPermissionState` 不传参数编译失败 / 传 `null` 报 `NoSuchMethodError`
- **根因**: 3.x 起 `getPermissionState({required PermissionRequestOption requestOption})` 把 `requestOption` 标成 `required`
- **修法**: 显式传默认值 `PhotoManager.getPermissionState(requestOption: const PermissionRequestOption())`
- **适用**: photo_manager 3.x 的所有权限相关 API；查 changelog 后再升级

### 7.9 `DateTime` 没有 const 构造 → 别往 `const List` 里塞
- **症状**: `final dt = DateTime.utc(2024, 6, 20);` 后写 `const <SystemPhoto>[SystemPhoto(takenAt: dt)]` 报 `non_constant_list_element` / `invalid_constant`
- **根因**: `DateTime` 的 `utc` / 本地构造都不是 const 构造（运行时计算 unix 时间戳），整条 const 推导失败
- **修法**:
  1. 去掉外层 `const`：`<SystemPhoto>[SystemPhoto(takenAt: dt)]`（最常见）
  2. 列表内用字面量的话，给内层加 `const SystemPhoto(...)`，外层允许非 const
  3. 永远别尝试 `const DateTime(...)` — 编译期根本算不出来
- **适用**: 所有"测试夹具要复用 `DateTime.now()` / `DateTime.utc(...)` 引用"的场景；以及任何"用 `final` 变量做 const 列表元素"的写法

### 7.11 `pumpAndSettle` + 永动 widget（spinner / 动画）= 永远 timeout
- **症状**: 测试渲染 loading 态的 `CircularProgressIndicator`（或 `LinearProgressIndicator` / 任何 `AnimationController` 驱动的 widget）时，`pumpAndSettle()` 永远不返回 → 测试 timeout
- **根因**: spinner 用 `AnimationController` 持续驱动 frame 调度；`pumpAndSettle` 一直等到"没有待处理帧"，而动画永远有新帧
- **修法**: 测 loading 态用 `tester.pump()`（单帧）而不是 `pumpAndSettle()`：
  ```dart
  await tester.pumpWidget(...);
  await tester.pump(); // 只跑一帧
  expect(find.byKey(Key('loading_indicator')), findsOneWidget);
  ```
- **适用**: 任何"测试 widget 在 loading / 动画中分支"的场景；4 态（loading / error / empty / success）测试里 loading 一定要用 `pump()`

### 7.12 `AsyncNotifier` testing 加载中分支：override `refresh()` 也得改
- **症状**: widget 测试想观察 `AsyncLoading` 态，stub `repo.loadAllFromSystem()` 返回永不 resolve 的 `pending.future`，但 widget 一会儿就显示 `AsyncData([])` — 看到的不是 loading 而是 empty
- **根因**: `AsyncNotifier` 暴露的方法（如 `refresh()`）仍然会跑。`initState` post-frame 调 `refresh()` → 内部 `state = AsyncValue.loading()` → `state = await AsyncValue.guard(loadAllFromSystem)`；如果 mock repo 还是同步返回了某个值（即使你换了 stub，setUp 残留 / mocktail 链式 stub 覆盖不全），state 会被覆盖成 `AsyncData(...)`
- **修法**: 测试"loading 态"用专用 Notifier 子类 + override `build()` 和 `refresh()`：
  ```dart
  class _LoadingPhotosNotifier extends PhotosNotifier {
    @override
    Future<List<T>> build() => Completer<List<T>>().future; // 永不 resolve
    @override
    Future<void> refresh() async {} // no-op：不让 initState 把它覆盖
  }
  // ProviderScope override
  photosProvider.overrideWith(_LoadingPhotosNotifier.new)
  ```
- **适用**: 所有 4 态（loading / error / empty / success）widget 测试中的 loading 分支；同样适合 Stream / Future provider

### 7.13 `Image.memory` 测试用合法字节 — 手搓的 1×1 PNG（base64 解码）
- **症状**: widget 测试里把 `Uint8List(0)` 或 `Uint8List.fromList([1,2,3,4])` 喂给 `Image.memory` → codec 抛 `Invalid image data`，测试 fail（即使断言仍通过，error log 污染输出 + 部分场景 tap 后异常会冒到 assert）
- **根因**: `Image.memory` 调 `painting.instantiateImageCodecWithSize` 解码真实图像字节；随便字节不是合法 PNG/JPEG
- **修法**: 测试 fixture 用一个真实的 1×1 透明 PNG（base64 编码）→ `base64.decode(...)`：
  ```dart
  // 1×1 透明 PNG，base64 编码
  final tinyPng = Uint8List.fromList(base64.decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
  ));
  ```
- **适用**: 所有要测 `Image.memory` / `Image` widget 加载流程的 widget 测试；如果有 `image` 包依赖，也可以 `image.Image(width:1, height:1)` → `encodePng(...)` 生成真字节

### 7.15 `image` 4.x 的 `gaussianBlur` / `fillRect` / `drawString` 修改 src in place
- **症状**: `final blurred = img.gaussianBlur(source, radius: 30);` 然后 `final result = img.compositeImage(blurred, source, ...);` 想用 `source` 的原始像素覆盖 `blurred` 中心，但 `result` 还是 blur 后的混合值（比如白色方块中心是 (254, 212, 212) 而非纯白 (255, 255, 255)）
- **根因**: `image` 4.x 的 `gaussianBlur` (实现走 `separableConvolution`) **返回入参 src 本身**，并在原地修改 `src.data`。`fillRect` / `drawString` 也是 in-place 写。这与 Dart 命名式 immutable 风格相悖，但实测 `identical(blurred, source) == true`
- **修法**:
  1. 需要"原图 + 模糊版共存"时，先 `final sharp = source.clone();`（`Image.clone()` 是 deep copy）
  2. 再 `final blurred = img.gaussianBlur(source, radius: r);`（source 现在 = blurred）
  3. `compositeImage(blurred, sharp, ...)` 用 sharp 取原像素
- **适用**: 所有用 `image` 4.x 写合成器（`FrameRenderer`、`filter pipeline`）；特别是需要"在模糊底上盖原图局部"这种 blend 逻辑时 — 必须 clone 一份原始。**测试断言也要容忍 JPEG 压缩噪声**（quality 90 在 pure white 上的偏差是 ±1，但高对比度边界跨 8×8 DCT 块时可能跌到 ±50）

### 7.14 测试照片 fixture：`TestPhotoFixtures.photos` + `thumbnailMap`
- **场景**: 想让 widget 测试看到"真实照片"（每张不同色、确定性、可断言），又不想依赖真实平台 / 文件系统
- **做法**: `test/test_utils/test_photo_fixtures.dart`（M1-T5 加的）
  - `TestPhotoFixtures.photos(count: N)` → `List<PhotoModel>`，id 形如 `'photo_NNN'`
  - `TestPhotoFixtures.thumbnailMap(count: N)` → `Map<String, Uint8List>`，每张一张 4×4 纯色 PNG（HSV 色环等分）
  - 配套用 `image` 包生成字节（pubspec 已声明 `image: ^4.2.0`）
- **关键 API 坑（写进 §7.14 而不是代码注释，避免被人改掉）**:
  1. `img.Image.clear(color)` 直接调实例方法（不是 `img.fill(image, color: ...)`）— image 4.x 把 fill 抽到 `draw/fill.dart` 但默认不导出
  2. `img.encodePng(image)` 返回 `List<int>`，要 `Uint8List.fromList(...)` 转成 `Uint8List` 才能喂 `Image.memory`
  3. HSV→RGB 公式里 `c * (1 - ((h / 60) % 2 - 1).abs())` 的括号顺序错了颜色全黑
- **测试里用法**:
  ```dart
  setUpAll(() async {
    photos = TestPhotoFixtures.photos(count: 100);
    thumbs = await TestPhotoFixtures.thumbnailMap(count: 100);
  });

  assetThumbnailLoaderProvider.overrideWithValue(
    (String id) async => thumbs[id],
  );
  ```
- **GridView 懒加载断言技巧**: 不要 `expect(find.byType(Image), findsNWidgets(N))` —— viewport 外还没构建；改用 `find.byKey(Key('photo_grid_item_photo_042'))` 精确断言；或 `tester.drag(...)` 滚到对应位置再找
- **100 张首次渲染性能 sanity**: 用 `Stopwatch` 测首次 `pumpAndSettle` 时长，断言 `< 1000ms`；M6-T3 性能压测会再缩紧这个预算
- **适用**: 任何"相册 / 列表 / grid 涉及多 item" 的 widget 测试；M2-T3 模板渲染 / M3 影集封面 / M4 标签 chip 列表都能复用
