import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/data/repositories/frame_repository.dart';

/// Tests for [FrameRepository.builtInTemplates] and
/// [FrameRepository.ensureBuiltInsSeeded].
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - [builtInTemplates] always returns exactly 2 templates with stable ids.
/// - [ensureBuiltInsSeeded] is idempotent: calling it twice does not
///   overwrite already-seeded built-ins (built-in usageCount is preserved).
/// - Missing built-ins are written; existing ones are left untouched.
class _FakeFrameTemplate extends Fake implements FrameTemplate {}

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;
  late FrameRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeFrameTemplate());
    registerFallbackValue(''); // for containsKey(any()) fallback
  });

  setUp(() {
    box = _MockBox();
    repo = FrameRepository.fromBox(box);
  });

  // ── builtInTemplates() ────────────────────────────────────────────

  group('builtInTemplates()', () {
    test('returns exactly 2 templates', () {
      final templates = builtInTemplates();
      expect(templates, hasLength(2));
    });

    test('builtin-minimal has correct structure', () {
      final templates = builtInTemplates();
      final minimal = templates.firstWhere((t) => t.id == 'builtin-minimal');

      expect(minimal.name, equals('极简'));
      expect(minimal.isBuiltIn, isTrue);
      expect(minimal.usageCount, equals(0));
      expect(minimal.layers, hasLength(1));
      expect(minimal.layers[0], isA<BlurBorderLayer>());

      final blur = minimal.layers[0] as BlurBorderLayer;
      expect(blur.intensity, equals(4));
      expect(blur.edge, isTrue);
    });

    test('builtin-magazine has correct 3-layer structure', () {
      final templates = builtInTemplates();
      final magazine =
          templates.firstWhere((t) => t.id == 'builtin-magazine');

      expect(magazine.name, equals('杂志'));
      expect(magazine.isBuiltIn, isTrue);
      expect(magazine.usageCount, equals(0));
      expect(magazine.layers, hasLength(3));

      // z-order: bottom EXIF placeholder → top brand → blur border (painted first)
      final bottomExif = magazine.layers[0] as TextWatermarkLayer;
      expect(bottomExif.text, equals('YYYY-MM-DD'));
      expect(bottomExif.position, equals(WatermarkPosition.bottomCenter));
      expect(bottomExif.fontSize, equals(12));
      expect(bottomExif.color, equals(0xCCFFFFFF));

      final topBrand = magazine.layers[1] as TextWatermarkLayer;
      expect(topBrand.text, equals('Photo'));
      expect(topBrand.position, equals(WatermarkPosition.topCenter));
      expect(topBrand.fontSize, equals(16));
      expect(topBrand.color, equals(0xFFFFFFFF));

      final blur = magazine.layers[2] as BlurBorderLayer;
      expect(blur.intensity, equals(6));
      expect(blur.edge, isTrue);
    });

    test('both templates have unique stable ids', () {
      final templates = builtInTemplates();
      final ids = templates.map((t) => t.id).toSet();
      expect(ids, hasLength(2));
    });
  });

  // ── ensureBuiltInsSeeded() ─────────────────────────────────────────

  group('ensureBuiltInsSeeded()', () {
    test('writes both templates when box is empty', () async {
      when(() => box.containsKey(any<String>())).thenReturn(false);
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await repo.ensureBuiltInsSeeded();

      verify(() => box.put('builtin-minimal', any<FrameTemplate>())).called(1);
      verify(() => box.put('builtin-magazine', any<FrameTemplate>())).called(1);
    });

    test('skips writing when built-in already exists', () async {
      // builtin-minimal exists; builtin-magazine missing
      when(() => box.containsKey('builtin-minimal')).thenReturn(true);
      when(() => box.containsKey('builtin-magazine')).thenReturn(false);
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await repo.ensureBuiltInsSeeded();

      // Should only write magazine, not minimal
      verifyNever(
          () => box.put('builtin-minimal', any<FrameTemplate>()));
      verify(() => box.put('builtin-magazine', any<FrameTemplate>())).called(1);
    });

    test('idempotent: calling twice does not overwrite existing built-ins',
        () async {
      when(() => box.containsKey(any<String>())).thenReturn(true);
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await repo.ensureBuiltInsSeeded();
      await repo.ensureBuiltInsSeeded();

      // Neither should be written
      verifyNever(
          () => box.put('builtin-minimal', any<FrameTemplate>()));
      verifyNever(
          () => box.put('builtin-magazine', any<FrameTemplate>()));
    });
  });
}