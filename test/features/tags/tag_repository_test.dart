import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/tags/data/models/tag_model.dart';
import 'package:photo_beauty/features/tags/data/repositories/tag_repository.dart';

/// Tests for [TagRepository] full CRUD + delete protection.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - [TagRepository.create] generates uuid id, sets createdAt = now
/// - [TagRepository.rename] updates name and writes back
/// - [TagRepository.setColor] updates colorValue and writes back
/// - [TagRepository.delete] no-op on missing id; throws [TagInUseException] when
///   the tag is referenced by any photo; succeeds when not referenced
/// - [TagRepository.isTagInUse] returns true when any photo references the tag
/// - All mutations no-op on missing id (safe to call without pre-check)

class _FakeTagModel extends Fake implements TagModel {}

class _FakePhotoModel extends Fake implements PhotoModel {}

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox tagsBox;
  late _MockBox photosBox;
  late TagRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeTagModel());
    registerFallbackValue(_FakePhotoModel());
    registerFallbackValue(<String>[]);
  });

  TagModel makeTag({
    String id = 'tag-1',
    String name = '旅行',
    int colorValue = 0xFF2196F3,
    DateTime? createdAt,
  }) =>
      TagModel(
        id: id,
        name: name,
        colorValue: colorValue,
        createdAt: createdAt ?? DateTime.utc(2026, 6, 1),
      );

  PhotoModel makePhoto({
    String id = 'photo-1',
    List<String> tags = const [],
  }) =>
      PhotoModel(
        id: id,
        path: '/photos/test.jpg',
        tags: tags,
      );

  setUp(() {
    tagsBox = _MockBox();
    photosBox = _MockBox();
    repo = TagRepository.fromBox(tagsBox, photosBox);
  });

  // ── getAll() ────────────────────────────────────────────────
  group('TagRepository.getAll', () {
    test('returns empty list when box is empty', () {
      when(() => tagsBox.values).thenReturn(const Iterable.empty());
      expect(repo.getAll(), isEmpty);
    });

    test('returns all tags', () {
      final tagA = makeTag(id: 'a', name: 'Alpha');
      final tagB = makeTag(id: 'b', name: 'Beta');
      when(() => tagsBox.values).thenReturn([tagA, tagB]);
      final result = repo.getAll();
      expect(result, hasLength(2));
      expect(result.map((t) => t.name), equals(['Alpha', 'Beta']));
    });
  });

  // ── getById() ───────────────────────────────────────────────
  group('TagRepository.getById', () {
    test('returns tag when present', () {
      final tag = makeTag();
      when(() => tagsBox.get('tag-1')).thenReturn(tag);
      expect(repo.getById('tag-1'), tag);
    });

    test('returns null when missing', () {
      when(() => tagsBox.get('missing')).thenReturn(null);
      expect(repo.getById('missing'), isNull);
    });
  });

  // ── create() ────────────────────────────────────────────────
  group('TagRepository.create', () {
    test('writes tag with generated uuid and returns it', () async {
      when(() => tagsBox.put(any<String>(), any<TagModel>()))
          .thenAnswer((_) async {});

      final tag = await repo.create(name: '新标签');

      expect(tag.id, isNotEmpty);
      expect(tag.name, equals('新标签'));
      expect(tag.colorValue, equals(0xFF808080));

      verify(() => tagsBox.put(tag.id, any<TagModel>())).called(1);
    });

    test('uses provided colorValue', () async {
      when(() => tagsBox.put(any<String>(), any<TagModel>()))
          .thenAnswer((_) async {});

      final tag = await repo.create(name: '红色标签', colorValue: 0xFFF44336);

      expect(tag.colorValue, equals(0xFFF44336));
    });

    test('generated id is unique', () async {
      when(() => tagsBox.put(any<String>(), any<TagModel>()))
          .thenAnswer((_) async {});

      final tag1 = await repo.create(name: '标签1');
      final tag2 = await repo.create(name: '标签2');

      expect(tag1.id, isNot(equals(tag2.id)));
    });
  });

  // ── rename() ────────────────────────────────────────────────
  group('TagRepository.rename', () {
    test('updates name and writes back', () async {
      final original = makeTag(name: '旧名称');
      when(() => tagsBox.get('tag-1')).thenReturn(original);
      when(() => tagsBox.put(any<String>(), any<TagModel>()))
          .thenAnswer((_) async {});

      await repo.rename('tag-1', '新名称');

      final captured = verify(
        () => tagsBox.put('tag-1', captureAny<TagModel>()),
      ).captured.single as TagModel;
      expect(captured.name, equals('新名称'));
    });

    test('is no-op when tag does not exist', () async {
      when(() => tagsBox.get('missing')).thenReturn(null);

      await repo.rename('missing', '任何名称');

      verifyNever(() => tagsBox.put(any<String>(), any<TagModel>()));
    });
  });

  // ── setColor() ─────────────────────────────────────────────
  group('TagRepository.setColor', () {
    test('updates colorValue and writes back', () async {
      final original = makeTag(colorValue: 0xFF000000);
      when(() => tagsBox.get('tag-1')).thenReturn(original);
      when(() => tagsBox.put(any<String>(), any<TagModel>()))
          .thenAnswer((_) async {});

      await repo.setColor('tag-1', 0xFFFFFFFF);

      final captured = verify(
        () => tagsBox.put('tag-1', captureAny<TagModel>()),
      ).captured.single as TagModel;
      expect(captured.colorValue, equals(0xFFFFFFFF));
    });

    test('is no-op when tag does not exist', () async {
      when(() => tagsBox.get('missing')).thenReturn(null);

      await repo.setColor('missing', 0xFF000000);

      verifyNever(() => tagsBox.put(any<String>(), any<TagModel>()));
    });
  });

  // ── delete() ────────────────────────────────────────────────
  group('TagRepository.delete', () {
    test('calls box.delete with correct id when not in use', () async {
      when(() => tagsBox.delete(any<dynamic>())).thenAnswer((_) async {});
      when(() => photosBox.toMap()).thenReturn({});

      await repo.delete('tag-1');

      verify(() => tagsBox.delete('tag-1')).called(1);
    });

    test('is no-op when id does not exist', () async {
      when(() => tagsBox.delete(any<dynamic>())).thenAnswer((_) async {});
      when(() => photosBox.toMap()).thenReturn({});

      await repo.delete('missing');

      verify(() => tagsBox.delete('missing')).called(1);
    });

    test('throws TagInUseException when tag is referenced by one photo',
        () async {
      final photo = makePhoto(id: 'photo-1', tags: ['tag-1']);
      when(() => photosBox.toMap()).thenReturn({'photo-1': photo});

      expect(
        () => repo.delete('tag-1'),
        throwsA(isA<TagInUseException>().having(
          (e) => e.tagId,
          'tagId',
          'tag-1',
        ).having(
          (e) => e.photoCount,
          'photoCount',
          1,
        )),
      );

      verifyNever(() => tagsBox.delete(any<dynamic>()));
    });

    test('throws TagInUseException with correct count when multiple photos use tag',
        () async {
      final photo1 = makePhoto(id: 'photo-1', tags: ['tag-1', 'tag-2']);
      final photo2 = makePhoto(id: 'photo-2', tags: ['tag-1']);
      when(() => photosBox.toMap()).thenReturn({'photo-1': photo1, 'photo-2': photo2});

      expect(
        () => repo.delete('tag-1'),
        throwsA(isA<TagInUseException>().having(
          (e) => e.photoCount,
          'photoCount',
          2,
        )),
      );
    });

    test('succeeds when tag is only referenced by other tags', () async {
      final photo = makePhoto(id: 'photo-1', tags: ['other-tag']);
      when(() => tagsBox.delete(any<dynamic>())).thenAnswer((_) async {});
      when(() => photosBox.toMap()).thenReturn({'photo-1': photo});

      await repo.delete('tag-1');

      verify(() => tagsBox.delete('tag-1')).called(1);
    });
  });

  // ── isTagInUse() ────────────────────────────────────────────
  group('TagRepository.isTagInUse', () {
    test('returns true when at least one photo uses the tag', () {
      final photo = makePhoto(id: 'photo-1', tags: ['tag-1']);
      when(() => photosBox.toMap()).thenReturn({'photo-1': photo});

      expect(repo.isTagInUse('tag-1'), isTrue);
    });

    test('returns false when no photo uses the tag', () {
      final photo = makePhoto(id: 'photo-1', tags: ['other-tag']);
      when(() => photosBox.toMap()).thenReturn({'photo-1': photo});

      expect(repo.isTagInUse('tag-1'), isFalse);
    });

    test('returns false when photos box is empty', () {
      when(() => photosBox.toMap()).thenReturn({});

      expect(repo.isTagInUse('tag-1'), isFalse);
    });

    test('returns false when photo has empty tags list', () {
      final photo = makePhoto(id: 'photo-1', tags: []);
      when(() => photosBox.toMap()).thenReturn({'photo-1': photo});

      expect(repo.isTagInUse('tag-1'), isFalse);
    });
  });
}
