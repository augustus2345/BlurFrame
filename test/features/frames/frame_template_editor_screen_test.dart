import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/data/repositories/frame_repository.dart';
import 'package:photo_beauty/features/frames/presentation/providers/template_editor_notifier.dart';
import 'package:photo_beauty/features/frames/presentation/screens/frame_template_editor_screen.dart';

/// Widget tests for [FrameTemplateEditorScreen] (M2-T4).
///
/// 覆盖：
/// - 4 态：loading（load 永不 resolve）/ 找不到 template / 新建空模板 / 已有模板
/// - 实时预览：开关某层 → FramePreview rebuild（layers 列表变化）
/// - 编辑 → 保存 → 调 repo.save + snackbar + pop
/// - 必填校验：name 空 → snackbar "请输入模板名"
/// - 内置模板：保存按钮 disabled
class _MockFrameRepository extends Mock implements FrameRepository {}

class _FakeFrameTemplate extends Fake implements FrameTemplate {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFrameTemplate());
  });

  late _MockFrameRepository repo;

  setUp(() {
    repo = _MockFrameRepository();
    when(() => repo.getAll()).thenReturn(const <FrameTemplate>[]);
  });

  /// 测试 loading 态时，通过 override 一个 `load` 永不 resolve 的 notifier
  /// 保留 AsyncLoading（getById 是同步的，没法用 Completer 截断）。
  Widget buildScreen({
    String? templateId,
    AsyncNotifierProvider<TemplateEditorNotifier, TemplateEditorState>?
        overrideProvider,
  }) {
    final overrides = <Override>[
      frameRepositoryProvider.overrideWithValue(repo),
    ];
    if (overrideProvider != null) {
      overrides.add(overrideProvider.overrideWith(_LoadingEditorNotifier.new));
    }
    // 用 GoRouter 包一层，context.pop() 才能找到 inherited。
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => FrameTemplateEditorScreen(templateId: templateId),
        ),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('FrameTemplateEditorScreen — 4 态', () {
    testWidgets('loading: shows spinner before load resolves', (tester) async {
      // 用 override 的 notifier 让 build/load 永不 resolve，保留 AsyncLoading
      await tester.pumpWidget(
        buildScreen(
          templateId: 'some-id',
          overrideProvider: templateEditorProvider,
        ),
      );
      await tester.pump(); // post-frame
      await tester.pump(); // state 切到 AsyncLoading

      expect(
        find.byKey(const Key('frame_template_editor_loading_indicator')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('frame_template_editor_body')),
        findsNothing,
      );
    });

    testWidgets('error: shows error state when template not found',
        (tester) async {
      when(() => repo.getById('missing')).thenReturn(null);
      await tester.pumpWidget(buildScreen(templateId: 'missing'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('frame_template_editor_load_error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('frame_template_editor_load_retry_button')),
        findsOneWidget,
      );
    });

    testWidgets('new template (no templateId): renders editor body immediately',
        (tester) async {
      // 加大 viewport 避免第三个 layer switch group 被裁出视口
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('frame_template_editor_body')),
        findsOneWidget,
      );
      // 3 个 layer switch group 都在
      expect(find.byKey(const Key('blur_enable_switch')), findsOneWidget);
      expect(find.byKey(const Key('watermark_enable_switch')), findsOneWidget);
      expect(find.byKey(const Key('stripe_enable_switch')), findsOneWidget);
      // AppBar title 是 "新建模板"
      expect(find.text('新建模板'), findsOneWidget);
    });

    testWidgets('edit existing: populates state and title says "编辑模板"',
        (tester) async {
      final source = FrameTemplate(
        id: 'user-1',
        name: '我的边框',
        isBuiltIn: false,
        layers: <FrameLayer>[
          BlurBorderLayer(intensity: 6, edge: true),
        ],
      );
      when(() => repo.getById('user-1')).thenReturn(source);
      await tester.pumpWidget(buildScreen(templateId: 'user-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('frame_template_editor_body')),
        findsOneWidget,
      );
      expect(find.text('编辑模板'), findsOneWidget);
      // 模版名填上
      expect(find.text('我的边框'), findsOneWidget);
      // 模糊边框被自动打开
      expect(
        find.byKey(const Key('blur_params')),
        findsOneWidget,
        reason: 'load 后 blurBorderEnabled=true → 渲染参数区',
      );
    });
  });

  group('FrameTemplateEditorScreen — 实时预览', () {
    testWidgets('toggle blur on → preview shows blur layer in test paint',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // 一开始 blur off → "已关闭" 提示
      expect(
        find.byKey(const Key('blur_disabled_hint')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('blur_enable_switch')));
      await tester.pumpAndSettle();

      // 切换后参数区出现
      expect(
        find.byKey(const Key('blur_params')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('blur_intensity_slider')),
        findsOneWidget,
      );
    });
  });

  group('FrameTemplateEditorScreen — 保存', () {
    testWidgets('save new template: calls repo.save + snackbar + pops',
        (tester) async {
      when(() => repo.save(any<FrameTemplate>())).thenAnswer((_) async {});
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // 改名字 + 打开模糊边框
      await tester.enterText(
        find.byKey(const Key('frame_template_editor_name_field')),
        '我的新模板',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('blur_enable_switch')));
      await tester.pumpAndSettle();

      // 点保存
      await tester.tap(
        find.byKey(const Key('frame_template_editor_save_button')),
      );
      await tester.pumpAndSettle();

      // 调了 repo.save
      verify(() => repo.save(any<FrameTemplate>())).called(1);
      // snackbar 显示
      expect(
        find.byKey(const Key('frame_template_editor_saved_snackbar')),
        findsOneWidget,
      );
      expect(find.text('已保存「我的新模板」'), findsOneWidget);
    });

    testWidgets('save with empty name: shows warning snackbar, no save call',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // 清空名字
      await tester.enterText(
        find.byKey(const Key('frame_template_editor_name_field')),
        '',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('frame_template_editor_save_button')),
      );
      await tester.pumpAndSettle();

      verifyNever(() => repo.save(any<FrameTemplate>()));
      expect(find.text('请输入模板名'), findsOneWidget);
    });

    testWidgets('edit existing user template: preserves id in save',
        (tester) async {
      final source = FrameTemplate(
        id: 'user-1',
        name: '原名',
        isBuiltIn: false,
        layers: const <FrameLayer>[],
      );
      when(() => repo.getById('user-1')).thenReturn(source);
      when(() => repo.save(any<FrameTemplate>())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(templateId: 'user-1'));
      await tester.pumpAndSettle();

      // 直接保存（不改名字）
      await tester.tap(
        find.byKey(const Key('frame_template_editor_save_button')),
      );
      await tester.pumpAndSettle();

      final captured = verify(
        () => repo.save(captureAny<FrameTemplate>()),
      ).captured.single as FrameTemplate;
      expect(captured.id, equals('user-1'));
      expect(captured.name, equals('原名'));
    });

    testWidgets('built-in template: save button is disabled', (tester) async {
      when(() => repo.getById('builtin-minimal')).thenReturn(
        FrameTemplate(
          id: 'builtin-minimal',
          name: '极简',
          isBuiltIn: true,
          layers: <FrameLayer>[BlurBorderLayer(intensity: 4)],
        ),
      );
      await tester.pumpWidget(buildScreen(templateId: 'builtin-minimal'));
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('frame_template_editor_save_button')),
      );
      expect(saveButton.onPressed, isNull);
      verifyNever(() => repo.save(any<FrameTemplate>()));
    });

    testWidgets('after save: list provider is refreshed', (tester) async {
      var getAllCalls = 0;
      when(() => repo.getAll()).thenAnswer((_) {
        getAllCalls++;
        return const <FrameTemplate>[];
      });
      when(() => repo.save(any<FrameTemplate>())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      // list provider 的 build() 不调 getAll（直接返回 const []）；
      // 真正的 getAll 在 refresh() 时调用。
      expect(getAllCalls, equals(0));

      await tester.tap(
        find.byKey(const Key('frame_template_editor_save_button')),
      );
      await tester.pumpAndSettle();

      // save 之后 → list refresh → 一次 getAll
      expect(getAllCalls, equals(1));
    });
  });
}

/// Test-only [TemplateEditorNotifier] whose `build()` never resolves —
/// keeps state at `AsyncLoading` so the widget can be tested for the
/// loading branch deterministically (CLAUDE.md §7.12).
class _LoadingEditorNotifier extends TemplateEditorNotifier {
  @override
  Future<TemplateEditorState> build() =>
      Completer<TemplateEditorState>().future;

  @override
  Future<void> load(String? id) async {
    // no-op: prevents initState post-frame from clobbering AsyncLoading
  }
}
