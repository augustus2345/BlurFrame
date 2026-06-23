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
class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;
  late FrameRepository repo;

  const builtIn = FrameTemplate(
    id: 'classic-white',
    name: 'Classic White',
    layers: <FrameLayer>[],
    isBuiltIn: true,
  );
  const userFrame = FrameTemplate(
    id: 'user-1',
    name: 'My Frame',
    layers: <FrameLayer>[],
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

      const updated = FrameTemplate(
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
}
