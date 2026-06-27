import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/data/repositories/frame_repository.dart';
import 'package:photo_beauty/features/frames/presentation/providers/template_editor_notifier.dart';

/// Tests for [TemplateEditorNotifier] (M2-T4).
///
/// 覆盖：
/// - build / load(null) / load(id 找到) / load(id 找不到) 4 态
/// - 每层 enabled 切换 + 参数更新
/// - copyWith / toTemplate 的过滤行为
/// - save：新建生成 uuid / 编辑保留 id + createdAt / 内置抛异常
class _MockFrameRepository extends Mock implements FrameRepository {}

class _FakeFrameTemplate extends Fake implements FrameTemplate {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFrameTemplate());
  });

  late _MockFrameRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _MockFrameRepository();
    container = ProviderContainer(
      overrides: [
        frameRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
  });

  // 工具：等一帧让 AsyncNotifier.build() resolve
  Future<void> settle() async {
    await container.read(templateEditorProvider.future);
  }

  group('TemplateEditorNotifier — build / load', () {
    test('build returns empty state with id == null', () async {
      await settle();
      final state = container.read(templateEditorProvider).value;
      expect(state, isNotNull);
      expect(state!.id, isNull);
      expect(state.isBuiltIn, isFalse);
      expect(state.name, '未命名模板');
      expect(state.blurBorderEnabled, isFalse);
      expect(state.textWatermarkEnabled, isFalse);
      expect(state.colorStripeEnabled, isFalse);
    });

    test('load(null) resets to empty state', () async {
      await settle();
      // 先制造一个有 id 的 state（用合法 source）
      when(() => repo.getById('user-1')).thenReturn(
        FrameTemplate(
          id: 'user-1',
          name: 'x',
          layers: const <FrameLayer>[],
        ),
      );
      await container.read(templateEditorProvider.notifier).load('user-1');
      expect(
        container.read(templateEditorProvider).value!.id,
        equals('user-1'),
      );

      // 再用 null 重置
      await container.read(templateEditorProvider.notifier).load(null);
      final state = container.read(templateEditorProvider).value;
      expect(state!.id, isNull);
      expect(state.isBuiltIn, isFalse);
      expect(state.name, equals('未命名模板'));
    });

    test('load(existing id) populates from template', () async {
      final source = FrameTemplate(
        id: 'user-1',
        name: '我的模板',
        isBuiltIn: false,
        usageCount: 3,
        createdAt: DateTime.utc(2026, 6, 1, 12),
        layers: <FrameLayer>[
          BlurBorderLayer(intensity: 7, edge: true),
          TextWatermarkLayer(
            text: '©2026',
            position: WatermarkPosition.topCenter,
            fontSize: 18,
            color: 0xCCFFFFFF,
          ),
        ],
      );
      when(() => repo.getById('user-1')).thenReturn(source);

      await settle();
      await container.read(templateEditorProvider.notifier).load('user-1');
      final state = container.read(templateEditorProvider).value;

      expect(state!.id, equals('user-1'));
      expect(state.name, equals('我的模板'));
      expect(state.isBuiltIn, isFalse);
      expect(state.createdAt, equals(DateTime.utc(2026, 6, 1, 12)));
      expect(state.blurBorderEnabled, isTrue);
      expect(state.blurBorder.intensity, equals(7));
      expect(state.textWatermarkEnabled, isTrue);
      expect(state.textWatermark.text, equals('©2026'));
      expect(state.textWatermark.position, equals(WatermarkPosition.topCenter));
      // ColorStripe 在 source 里没有 → disabled 但实例是默认
      expect(state.colorStripeEnabled, isFalse);
      expect(state.colorStripe.color, isA<int>());
    });

    test('load(missing id) → AsyncError with StateError', () async {
      when(() => repo.getById('missing')).thenReturn(null);

      await settle();
      await container.read(templateEditorProvider.notifier).load('missing');
      final value = container.read(templateEditorProvider);

      expect(value, isA<AsyncError<TemplateEditorState>>());
      expect(value.error, isA<StateError>());
      verify(() => repo.getById('missing')).called(1);
    });

    test('load built-in template → isBuiltIn is true in state', () async {
      when(() => repo.getById('builtin-minimal')).thenReturn(
        FrameTemplate(
          id: 'builtin-minimal',
          name: '极简',
          isBuiltIn: true,
          layers: <FrameLayer>[BlurBorderLayer(intensity: 4)],
        ),
      );

      await settle();
      await container
          .read(templateEditorProvider.notifier)
          .load('builtin-minimal');
      final state = container.read(templateEditorProvider).value;
      expect(state!.isBuiltIn, isTrue);
      expect(state.id, equals('builtin-minimal'));
    });
  });

  group('TemplateEditorNotifier — set* mutations', () {
    Future<void> ready() async {
      await settle();
    }

    test('setName updates name', () async {
      await ready();
      container.read(templateEditorProvider.notifier).setName('我的边框');
      final state = container.read(templateEditorProvider).value;
      expect(state!.name, equals('我的边框'));
    });

    test('setBlurBorderEnabled toggles enabled', () async {
      await ready();
      final notifier = container.read(templateEditorProvider.notifier);
      notifier.setBlurBorderEnabled(true);
      expect(
        container.read(templateEditorProvider).value!.blurBorderEnabled,
        isTrue,
      );
      notifier.setBlurBorderEnabled(false);
      expect(
        container.read(templateEditorProvider).value!.blurBorderEnabled,
        isFalse,
      );
    });

    test('setBlurIntensity updates intensity without changing edge', () async {
      await ready();
      final notifier = container.read(templateEditorProvider.notifier);
      notifier.setBlurIntensity(7.5);
      notifier.setBlurEdgeOnly(true);
      notifier.setBlurIntensity(3.0);
      final layer = container.read(templateEditorProvider).value!.blurBorder;
      expect(layer.intensity, equals(3.0));
      expect(layer.edge, isTrue);
    });

    test('watermark set* updates fields without losing others', () async {
      await ready();
      final notifier = container.read(templateEditorProvider.notifier);
      notifier.setWatermarkText('Hello');
      notifier.setWatermarkFontSize(20);
      notifier.setWatermarkColor(0xFF00FF00);
      notifier.setWatermarkPosition(WatermarkPosition.topLeft);

      final wm = container.read(templateEditorProvider).value!.textWatermark;
      expect(wm.text, equals('Hello'));
      expect(wm.fontSize, equals(20));
      expect(wm.color, equals(0xFF00FF00));
      expect(wm.position, equals(WatermarkPosition.topLeft));
    });

    test('stripe set* updates fields without losing others', () async {
      await ready();
      final notifier = container.read(templateEditorProvider.notifier);
      notifier.setStripeColor(0xFFFF0000);
      notifier.setStripeWidth(0.2);
      notifier.setStripeCornerRadius(8);
      notifier.setStripePosition(StripePosition.top);

      final stripe = container.read(templateEditorProvider).value!.colorStripe;
      expect(stripe.color, equals(0xFFFF0000));
      expect(stripe.width, equals(0.2));
      expect(stripe.cornerRadius, equals(8));
      expect(stripe.position, equals(StripePosition.top));
    });
  });

  group('TemplateEditorState — toTemplate', () {
    test('filters out disabled layers', () async {
      await settle();
      final notifier = container.read(templateEditorProvider.notifier);
      notifier.setName('混合');
      notifier.setBlurBorderEnabled(true);
      notifier.setTextWatermarkEnabled(true);
      notifier.setColorStripeEnabled(false); // 不写入

      final state = container.read(templateEditorProvider).value!;
      final template = state.toTemplate(finalId: 'mixed');

      expect(template.name, equals('混合'));
      expect(template.id, equals('mixed'));
      expect(template.layers, hasLength(2));
      expect(template.layers[0], isA<BlurBorderLayer>());
      expect(template.layers[1], isA<TextWatermarkLayer>());
    });

    test('all disabled → empty layers list', () async {
      await settle();
      final state = container.read(templateEditorProvider).value!;
      final template = state.toTemplate(finalId: 'empty');
      expect(template.layers, isEmpty);
    });
  });

  group('TemplateEditorNotifier — save', () {
    test('new template: generates uuid, calls repo.save with isBuiltIn=false',
        () async {
      await settle();
      when(() => repo.save(any<FrameTemplate>())).thenAnswer((_) async {});

      final notifier = container.read(templateEditorProvider.notifier);
      notifier.setName('新建的');
      notifier.setBlurBorderEnabled(true);

      final saved = await notifier.save();

      expect(saved.id, isNotEmpty, reason: 'uuid 不应为空');
      expect(saved.name, equals('新建的'));
      expect(saved.isBuiltIn, isFalse);
      expect(saved.layers, hasLength(1));
      expect(saved.layers.first, isA<BlurBorderLayer>());

      final captured = verify(
        () => repo.save(captureAny<FrameTemplate>()),
      ).captured.single as FrameTemplate;
      expect(captured.id, equals(saved.id));
      expect(captured.name, equals('新建的'));
    });

    test('edit existing: preserves id and createdAt', () async {
      final source = FrameTemplate(
        id: 'user-1',
        name: '原名',
        isBuiltIn: false,
        createdAt: DateTime.utc(2026, 6, 1, 12),
        layers: <FrameLayer>[BlurBorderLayer(intensity: 4)],
      );
      when(() => repo.getById('user-1')).thenReturn(source);
      when(() => repo.save(any<FrameTemplate>())).thenAnswer((_) async {});

      await settle();
      final notifier = container.read(templateEditorProvider.notifier);
      await notifier.load('user-1');
      notifier.setName('改后');
      notifier.setBlurIntensity(9);

      final saved = await notifier.save();
      expect(saved.id, equals('user-1'));
      expect(saved.name, equals('改后'));
      expect(saved.createdAt, equals(DateTime.utc(2026, 6, 1, 12)));
      expect(
        (saved.layers.first as BlurBorderLayer).intensity,
        equals(9),
      );
    });

    test('built-in template: save throws BuiltInTemplateException', () async {
      when(() => repo.getById('builtin-minimal')).thenReturn(
        FrameTemplate(
          id: 'builtin-minimal',
          name: '极简',
          isBuiltIn: true,
          layers: <FrameLayer>[BlurBorderLayer(intensity: 4)],
        ),
      );
      await settle();
      final notifier = container.read(templateEditorProvider.notifier);
      await notifier.load('builtin-minimal');

      await expectLater(
        notifier.save(),
        throwsA(isA<BuiltInTemplateException>()),
      );
      verifyNever(() => repo.save(any<FrameTemplate>()));
    });
  });
}
