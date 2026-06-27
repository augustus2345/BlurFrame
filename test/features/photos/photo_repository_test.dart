import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/data/repositories/photo_repository.dart';

/// Tests for [PhotoRepository] — CRUD wrapper over the photos_meta Hive box.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - `save` writes the model keyed by its `id` (so `getById(id)` works).
/// - `get` returns the cast result; returns `null` for missing keys.
/// - `getAll` returns every value cast to `PhotoModel`.
/// - `delete` removes the entry; `clear` empties the box.
///
/// Mirrors the `MockBox` + mocktail pattern from
/// `test/features/frames/frame_repository_test.dart`.
class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;
  late PhotoRepository repo;

  const sample = PhotoModel(
    id: 'asset-1',
    path: '/photos/IMG_0001.jpg',
    width: 4032,
    height: 3024,
    tags: <String>['travel'],
  );

  setUp(() {
    box = _MockBox();
    repo = PhotoRepository.fromBox(box);
  });

  group('PhotoRepository.save', () {
    test('writes model keyed by its id', () async {
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await repo.save(sample);

      verify(() => box.put('asset-1', sample)).called(1);
    });
  });

  group('PhotoRepository.get', () {
    test('returns the stored model when present', () {
      when(() => box.get('asset-1')).thenReturn(sample);

      final result = repo.get('asset-1');

      expect(result, sample);
    });

    test('returns null when the key is missing', () {
      when(() => box.get('missing')).thenReturn(null);

      expect(repo.get('missing'), isNull);
    });
  });

  group('PhotoRepository.getAll', () {
    test('returns every value in the box, cast to PhotoModel', () {
      const a = PhotoModel(id: 'a', path: '/a');
      const b = PhotoModel(id: 'b', path: '/b');
      when(() => box.values).thenReturn(<dynamic>[a, b]);

      final result = repo.getAll();

      expect(result, hasLength(2));
      expect(result[0], a);
      expect(result[1], b);
    });

    test('returns empty list when box is empty', () {
      when(() => box.values).thenReturn(<dynamic>[]);

      expect(repo.getAll(), isEmpty);
    });
  });

  group('PhotoRepository.delete', () {
    test('removes the entry by id', () async {
      when(() => box.delete(any<dynamic>())).thenAnswer((_) async {});

      await repo.delete('asset-1');

      verify(() => box.delete('asset-1')).called(1);
    });
  });

  group('PhotoRepository.clear', () {
    test('wipes the entire box', () async {
      when(() => box.clear()).thenAnswer((_) async => 0);

      await repo.clear();

      verify(() => box.clear()).called(1);
    });
  });

  group('PhotoRepository.updateStarRating', () {
    test('updates the starRating and preserves other fields', () async {
      const original = PhotoModel(
        id: 'asset-1',
        path: '/photos/IMG_0001.jpg',
        width: 4032,
        height: 3024,
        tags: <String>['travel'],
        starRating: 0,
      );
      when(() => box.get('asset-1')).thenReturn(original);
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await repo.updateStarRating('asset-1', 4);

      final captured = verify(() => box.put(captureAny<dynamic>(), captureAny<dynamic>()))
          .captured;
      final saved = captured[1] as PhotoModel;
      expect(saved.starRating, 4);
      expect(saved.id, 'asset-1');
      expect(saved.path, '/photos/IMG_0001.jpg');
      expect(saved.tags, ['travel']);
    });

    test('clamps starRating to 0-5 range', () async {
      const original = PhotoModel(id: 'asset-1', path: '/x', starRating: 0);
      when(() => box.get('asset-1')).thenReturn(original);
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await repo.updateStarRating('asset-1', 10);

      final captured = verify(() => box.put(captureAny<dynamic>(), captureAny<dynamic>()))
          .captured;
      final saved = captured[1] as PhotoModel;
      expect(saved.starRating, 5); // clamped to 5
    });

    test('clamps negative starRating to 0', () async {
      const original = PhotoModel(id: 'asset-1', path: '/x', starRating: 3);
      when(() => box.get('asset-1')).thenReturn(original);
      when(() => box.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await repo.updateStarRating('asset-1', -2);

      final captured = verify(() => box.put(captureAny<dynamic>(), captureAny<dynamic>()))
          .captured;
      final saved = captured[1] as PhotoModel;
      expect(saved.starRating, 0); // clamped to 0
    });

    test('returns early when photo does not exist', () async {
      when(() => box.get('missing')).thenReturn(null);

      await repo.updateStarRating('missing', 3);

      verifyNever(() => box.put(any<dynamic>(), any<dynamic>()));
    });
  });
}
