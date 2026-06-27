import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/data/repositories/frame_repository.dart';

/// Tests for [FrameRepository]'s built-in template protection.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - [FrameRepository.delete] throws [BuiltInTemplateException] when the
///   target template is marked `isBuiltIn`; the box is left untouched.
/// - [FrameRepository.save] throws [BuiltInTemplateException] when the
///   target id is already taken by a built-in template (no overwriting).
/// - User templates (`isBuiltIn == false`) can be saved, updated, deleted.
class _FakeFrameTemplate extends Fake implements FrameTemplate {}

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;
  late FrameRepository repo;

  setUpAll(() {
    // mocktail `any<String>()` 在 when/verify 里需要 fallback；
    // 与 frame_repository_builtin_test.dart 对齐。
    registerFallbackValue(_FakeFrameTemplate());
    registerFallbackValue('');
  });

  final builtIn = FrameTemplate(
    id: 'classic-white',
    name: 'Classic White',
    layers: const [],
    isBuiltIn: true,
  );
  final userFrame = FrameTemplate(
    id: 'user-1',
    name: 'My Frame',
    layers: const [],
  );

  setUp(() {
    box = _MockBox();
    repo = FrameRepository.fromBox(box);
  });

  group('FrameRepository built-in protection', () {
    test('delete throws when target is a built-in template', () async {
      when(() => box.get('classic-white')).thenReturn(builtIn);

      await expectLater(
        () => repo.delete('classic-white'),
        throwsA(isA<BuiltInTemplateException>()),
      );
      verifyNever(() => box.delete(any<dynamic>()));
    });

    test('delete succeeds for a user template', () async {
      when(() => box.get('user-1')).thenReturn(userFrame);
      when(() => box.delete(any<dynamic>())).thenAnswer((_) async {});

      await repo.delete('user-1');
      verify(() => box.delete('user-1')).called(1);
    });

    test('delete succeeds when the id does not exist (no-op)', () async {
      when(() => box.get('missing')).thenReturn(null);
      when(() => box.delete(any<dynamic>())).thenAnswer((_) async {});

      await repo.delete('missing');
      verify(() => box.delete('missing')).called(1);
    });

    test('save throws when overwriting a built-in template', () async {
      when(() => box.get('classic-white')).thenReturn(builtIn);

      await expectLater(
        () => repo.save(builtIn),
        throwsA(isA<BuiltInTemplateException>()),
      );
      verifyNever(() => box.put(any<dynamic>(), any<dynamic>()));
    });

    test('save succeeds for a new user template', () async {
      when(() => box.get('user-1')).thenReturn(null);
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await repo.save(userFrame);
      verify(() => box.put('user-1', userFrame)).called(1);
    });

    test('save succeeds when updating an existing user template', () async {
      when(() => box.get('user-1')).thenReturn(userFrame);
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      final updated = FrameTemplate(
        id: 'user-1',
        name: 'Renamed',
        layers: <FrameLayer>[],
      );
      await repo.save(updated);
      verify(() => box.put('user-1', updated)).called(1);
    });
  });

  group('FrameRepository.getById', () {
    test('returns the template when present', () {
      when(() => box.get('classic-white')).thenReturn(builtIn);
      expect(repo.getById('classic-white'), builtIn);
    });

    test('returns null when missing', () {
      when(() => box.get('missing')).thenReturn(null);
      expect(repo.getById('missing'), isNull);
    });
  });

  // ── duplicate() ────────────────────────────────────────────
  //
  // M2-T3 引入：长按 → "复制为我的模板" → FrameRepository.duplicate。
  // 契约：
  // - 源 id 存在 → 写入新 id `${source}-copy-1`，isBuiltIn=false，usageCount=0
  // - 已存在 `-copy-1` 时递增到 `-copy-2`，依此类推
  // - 源 id 缺失 → 抛 StateError，不写入任何东西
  // - 复制内置模板也 OK（isBuiltIn 强制改 false，让用户能编辑副本）
  group('FrameRepository.duplicate', () {
    test('throws StateError when source id does not exist', () async {
      when(() => box.get('missing')).thenReturn(null);

      await expectLater(
        () => repo.duplicate('missing'),
        throwsA(isA<StateError>()),
      );
      verifyNever(() => box.put(any<dynamic>(), any<dynamic>()));
    });

    test('writes a fresh copy with -copy-1 suffix when target id is free',
        () async {
      when(() => box.get('builtin-magazine')).thenReturn(
        FrameTemplate(
          id: 'builtin-magazine',
          name: '杂志',
          isBuiltIn: true,
          usageCount: 9,
          layers: const <FrameLayer>[],
        ),
      );
      when(() => box.containsKey(any<String>())).thenReturn(false);
      when(() => box.put(any<String>(), any<FrameTemplate>()))
          .thenAnswer((_) async {});

      final copy = await repo.duplicate('builtin-magazine');

      expect(copy.id, equals('builtin-magazine-copy-1'));
      expect(copy.name, equals('杂志'));
      expect(
        copy.isBuiltIn,
        isFalse,
        reason: '副本必须 isBuiltIn=false，用户才能编辑',
      );
      expect(
        copy.usageCount,
        equals(0),
        reason: '副本是全新模板，usageCount 从 0 开始',
      );
      expect(copy.layers, isEmpty);

      // 入参校验
      final captured = verify(
        () => box.put('builtin-magazine-copy-1', captureAny<FrameTemplate>()),
      ).captured.single as FrameTemplate;
      expect(captured.isBuiltIn, isFalse);
      expect(captured.usageCount, equals(0));
    });

    test('递增 suffix 直到 -copy-N 空闲', () async {
      when(() => box.get('user-1')).thenReturn(userFrame);
      when(() => box.containsKey('user-1-copy-1')).thenReturn(true);
      when(() => box.containsKey('user-1-copy-2')).thenReturn(true);
      when(() => box.containsKey('user-1-copy-3')).thenReturn(false);
      when(() => box.put(any<String>(), any<FrameTemplate>()))
          .thenAnswer((_) async {});

      final copy = await repo.duplicate('user-1');

      expect(copy.id, equals('user-1-copy-3'));
      verify(() => box.put('user-1-copy-3', any<FrameTemplate>())).called(1);
    });

    test('preserves source layers / name / createdAt on the copy', () async {
      final source = FrameTemplate(
        id: 'src',
        name: '我的模板',
        isBuiltIn: false,
        usageCount: 5,
        createdAt: DateTime.utc(2026, 6, 1, 12),
        layers: <FrameLayer>[
          BlurBorderLayer(intensity: 8, edge: true),
          TextWatermarkLayer(
            text: '©',
            position: WatermarkPosition.bottomRight,
          ),
        ],
      );
      when(() => box.get('src')).thenReturn(source);
      when(() => box.containsKey(any<String>())).thenReturn(false);
      when(() => box.put(any<String>(), any<FrameTemplate>()))
          .thenAnswer((_) async {});

      final copy = await repo.duplicate('src');

      expect(copy.name, equals('我的模板'));
      expect(copy.createdAt, equals(DateTime.utc(2026, 6, 1, 12)));
      expect(copy.layers, hasLength(2));
      expect(copy.layers[0], isA<BlurBorderLayer>());
      expect(copy.layers[1], isA<TextWatermarkLayer>());
    });
  });
}
