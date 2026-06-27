import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/data/repositories/frame_repository.dart';
import 'package:photo_beauty/features/frames/presentation/providers/frame_template_list_provider.dart';
import 'package:photo_beauty/features/frames/presentation/screens/frame_template_list_screen.dart';

/// Widget tests for [FrameTemplateListScreen] (M2-T3).
///
/// 覆盖：
/// - 4 态（loading / error / empty / success）
/// - 内置模板 badge（"自带"）vs 用户模板 badge（"使用 N 次"）
/// - 长按卡片 → 底部 ActionSheet
/// - 内置模板：删除项灰显且不可点
/// - 用户模板：复制为我的 → 列表新增 + 提示 snackbar
/// - 用户模板：删除 → 二次确认 → 列表减少 + 提示 snackbar
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

  /// 默认有 2 个内置模板，方便 success 分支测试
  List<FrameTemplate> builtInOnly() {
    return builtInTemplates();
  }

  Widget buildScreen({
    List<FrameTemplate> Function()? getAllOverride,
    Object? getAllError,
    AsyncNotifierProvider<FrameTemplateListNotifier, List<FrameTemplate>>?
        buildOverride,
  }) {
    if (getAllError != null) {
      when(() => repo.getAll()).thenThrow(getAllError);
    } else if (getAllOverride != null) {
      when(() => repo.getAll()).thenReturn(getAllOverride());
    }

    final overrides = <Override>[
      frameRepositoryProvider.overrideWithValue(repo),
    ];
    if (buildOverride != null) {
      overrides.add(buildOverride.overrideWith(_LoadingListNotifier.new));
    }
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: FrameTemplateListScreen()),
    );
  }

  // ── 4 态 ────────────────────────────────────────────────
  group('FrameTemplateListScreen — 4 态', () {
    testWidgets('loading: shows spinner before getAll resolves',
        (tester) async {
      await tester
          .pumpWidget(buildScreen(buildOverride: frameTemplateListProvider));
      await tester.pump();

      expect(
        find.byKey(const Key('frame_template_list_loading_indicator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('frame_template_grid')), findsNothing);
    });

    testWidgets('error: shows error state + retry button', (tester) async {
      await tester.pumpWidget(
        buildScreen(getAllError: StateError('boom')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('frame_template_list_error_state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('frame_template_list_retry_button')),
        findsOneWidget,
      );
    });

    testWidgets('error + retry: rebuilds list successfully', (tester) async {
      var callIndex = 0;
      when(() => repo.getAll()).thenAnswer((_) {
        callIndex++;
        if (callIndex == 1) throw StateError('first call fails');
        return builtInOnly();
      });

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('frame_template_list_error_state')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('frame_template_list_retry_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('frame_template_list_error_state')),
        findsNothing,
      );
      expect(find.byKey(const Key('frame_template_grid')), findsOneWidget);
      verify(() => repo.getAll()).called(2);
    });

    testWidgets('empty: shows empty state (no templates at all)',
        (tester) async {
      when(() => repo.getAll()).thenReturn(const <FrameTemplate>[]);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('frame_template_list_empty_state')),
        findsOneWidget,
      );
    });

    testWidgets(
      'success: 2-column grid renders each template card with built-in badge',
      (tester) async {
        await tester.pumpWidget(buildScreen(getAllOverride: builtInOnly));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('frame_template_grid')), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey<String>('frame_template_card_builtin-minimal'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey<String>('frame_template_card_builtin-magazine'),
          ),
          findsOneWidget,
        );
        // 两个内置 → 两个"自带"badge
        expect(
          find.byKey(
            const Key('frame_template_card_built_in_badge'),
          ),
          findsNWidgets(2),
        );
        // "极简" / "杂志" 名称显示
        expect(find.text('极简'), findsOneWidget);
        expect(find.text('杂志'), findsOneWidget);
      },
    );

    testWidgets('user template: shows usage-count badge', (tester) async {
      final user = FrameTemplate(
        id: 'user-1',
        name: '我的边框',
        usageCount: 7,
        layers: const <FrameLayer>[],
      );
      await tester.pumpWidget(
        buildScreen(getAllOverride: () => <FrameTemplate>[user]),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('frame_template_card_usage_badge')),
        findsOneWidget,
      );
      expect(find.text('使用 7 次'), findsOneWidget);
    });
  });

  // ── 长按菜单 ─────────────────────────────────────────────
  group('FrameTemplateListScreen — 长按 ActionSheet', () {
    testWidgets('long press built-in card: delete is disabled', (tester) async {
      await tester.pumpWidget(buildScreen(getAllOverride: builtInOnly));
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(
          const ValueKey<String>('frame_template_card_builtin-minimal'),
        ),
      );
      await tester.pumpAndSettle();

      // 三个菜单项都在
      expect(find.text('复制为我的模板'), findsOneWidget);
      expect(
        find.text('编辑'),
        findsNothing,
        reason: '内置模板不显示编辑项',
      );
      expect(find.text('删除'), findsOneWidget);
      // 内置模板删除项不可点 → enabled=false（找不到 confirm 按钮）
      await tester.tap(find.text('删除'));
      await tester.pump();
      expect(
        find.byKey(const Key('frame_template_delete_dialog')),
        findsNothing,
        reason: '内置模板 tap 删除不应弹二次确认',
      );
    });

    testWidgets(
      'long press built-in card → "复制为我的模板" → 调 repo.duplicate + snackbar',
      (tester) async {
        // 首次 getAll 返回内置；duplicate 后再 getAll 返回内置 + 副本
        var callIndex = 0;
        when(() => repo.getAll()).thenAnswer((_) {
          callIndex++;
          if (callIndex == 1) return builtInOnly();
          // 第二次 refresh（duplicate 后）— 模拟写入新条目
          return <FrameTemplate>[
            ...builtInOnly(),
            FrameTemplate(
              id: 'builtin-minimal-copy-1',
              name: '极简',
              usageCount: 0,
              layers: const <FrameLayer>[],
            ),
          ];
        });
        when(() => repo.duplicate(any<String>())).thenAnswer(
          (invocation) async => FrameTemplate(
            id: invocation.positionalArguments[0] as String,
            name: '极简',
            usageCount: 0,
            layers: const <FrameLayer>[],
          ),
        );

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        await tester.longPress(
          find.byKey(
            const ValueKey<String>('frame_template_card_builtin-minimal'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('复制为我的模板'));
        await tester.pumpAndSettle();

        verify(() => repo.duplicate('builtin-minimal')).called(1);
        expect(
          find.byKey(const Key('frame_template_duplicate_snackbar')),
          findsOneWidget,
        );
        // 副本卡片出现
        expect(
          find.byKey(
            const ValueKey<String>(
              'frame_template_card_builtin-minimal-copy-1',
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('long press user card: delete shows confirm dialog',
        (tester) async {
      final user = FrameTemplate(
        id: 'user-1',
        name: '我的',
        usageCount: 0,
        layers: const <FrameLayer>[],
      );
      await tester.pumpWidget(
        buildScreen(getAllOverride: () => <FrameTemplate>[user]),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('frame_template_card_user-1')),
      );
      await tester.pumpAndSettle();

      // 用户模板菜单：复制 + 编辑 + 删除
      expect(find.text('复制为我的模板'), findsOneWidget);
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 二次确认对话框
      expect(
        find.byKey(const Key('frame_template_delete_dialog')),
        findsOneWidget,
      );
    });

    testWidgets(
      'user template: confirm delete → repo.delete + snackbar + list shrinks',
      (tester) async {
        final user = FrameTemplate(
          id: 'user-1',
          name: '我的',
          usageCount: 0,
          layers: const <FrameLayer>[],
        );
        var callIndex = 0;
        when(() => repo.getAll()).thenAnswer((_) {
          callIndex++;
          if (callIndex == 1) return <FrameTemplate>[user];
          return const <FrameTemplate>[];
        });
        when(() => repo.delete(any<String>())).thenAnswer((_) async {});

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        await tester.longPress(
          find.byKey(const ValueKey<String>('frame_template_card_user-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('frame_template_delete_confirm_button')),
        );
        await tester.pumpAndSettle();

        verify(() => repo.delete('user-1')).called(1);
        expect(
          find.byKey(const Key('frame_template_delete_snackbar')),
          findsOneWidget,
        );
        // 删除后 list 空 → 第二次 refresh 返回 []，卡片消失
        expect(
          find.byKey(const ValueKey<String>('frame_template_card_user-1')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('frame_template_list_empty_state')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
        'user template: BuiltInTemplateException from delete shows snackbar',
        (tester) async {
      // 不应触发：内置模板菜单已禁删。模拟防御性抛错（不应该发生，但测一下 UI 处理）。
      final user = FrameTemplate(
        id: 'user-1',
        name: '我的',
        usageCount: 0,
        layers: const <FrameLayer>[],
      );
      when(() => repo.getAll()).thenReturn(<FrameTemplate>[user]);
      when(() => repo.delete(any<String>())).thenThrow(
        const BuiltInTemplateException('user-1'),
      );

      await tester.pumpWidget(
        buildScreen(getAllOverride: () => <FrameTemplate>[user]),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('frame_template_card_user-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('frame_template_delete_confirm_button')),
      );
      await tester.pumpAndSettle();

      // snackbar 显示兜底提示（防御性）
      expect(find.textContaining('内置模板'), findsOneWidget);
    });
  });
}

/// Test-only [FrameTemplateListNotifier] whose `build()` never resolves —
/// keeps state at `AsyncLoading` so the widget can be tested for the
/// loading branch deterministically (CLAUDE.md §7.12).
class _LoadingListNotifier extends FrameTemplateListNotifier {
  @override
  Future<List<FrameTemplate>> build() =>
      Completer<List<FrameTemplate>>().future;

  @override
  Future<void> refresh() async {
    // no-op: prevents initState post-frame from clobbering AsyncLoading
  }
}
