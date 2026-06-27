import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/albums/data/models/album_model.dart';
import 'package:photo_beauty/features/albums/data/repositories/album_repository.dart';

/// Tests for [AlbumRepository] full CRUD.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - [AlbumRepository.create] generates uuid id, auto-sets coverPhotoId
/// - [AlbumRepository.addPhotos] auto-sets cover if empty, appends to end
/// - [AlbumRepository.removePhotos] auto-updates cover if removed photo was cover
/// - [AlbumRepository.reorderPhotos] replaces full list, updates cover if needed
/// - [AlbumRepository.setCover] no-op if cover not in photoIds
/// - All mutations no-op on missing id (safe to call without pre-check)
/// - [AlbumRepository.getAll] returns list sorted by createdAt desc

class _FakeAlbumModel extends Fake implements AlbumModel {}

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;
  late AlbumRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeAlbumModel());
    registerFallbackValue(<String>[]);
    registerFallbackValue(AlbumLayout.grid);
  });

  AlbumModel makeAlbum({
    String id = 'album-1',
    String name = '我的影集',
    String coverPhotoId = 'photo-a',
    List<String> photoIds = const ['photo-a', 'photo-b'],
    AlbumLayout layout = AlbumLayout.grid,
    DateTime? createdAt,
  }) =>
      AlbumModel(
        id: id,
        name: name,
        coverPhotoId: coverPhotoId,
        photoIds: photoIds,
        layout: layout,
        createdAt: createdAt ?? DateTime.utc(2026, 6, 1),
      );

  setUp(() {
    box = _MockBox();
    repo = AlbumRepository.fromBox(box);
  });

  // ── getAll() ────────────────────────────────────────────────
  group('AlbumRepository.getAll', () {
    test('returns empty list when box is empty', () {
      when(() => box.values).thenReturn(const Iterable.empty());
      expect(repo.getAll(), isEmpty);
    });

    test('returns albums sorted by createdAt desc', () {
      final albumA = makeAlbum(id: 'a', createdAt: DateTime.utc(2026, 6, 1));
      final albumB = makeAlbum(id: 'b', createdAt: DateTime.utc(2026, 6, 3));
      final albumC = makeAlbum(id: 'c', createdAt: DateTime.utc(2026, 6, 2));
      when(() => box.values).thenReturn([albumA, albumB, albumC]);

      final result = repo.getAll();

      expect(result.map((a) => a.id), equals(['b', 'c', 'a']));
    });
  });

  // ── getById() ───────────────────────────────────────────────
  group('AlbumRepository.getById', () {
    test('returns album when present', () {
      final album = makeAlbum();
      when(() => box.get('album-1')).thenReturn(album);
      expect(repo.getById('album-1'), album);
    });

    test('returns null when missing', () {
      when(() => box.get('missing')).thenReturn(null);
      expect(repo.getById('missing'), isNull);
    });
  });

  // ── create() ────────────────────────────────────────────────
  group('AlbumRepository.create', () {
    test('writes album with generated uuid and returns it', () async {
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      final album = await repo.create(name: '新影集');

      expect(album.id, isNotEmpty);
      expect(album.name, equals('新影集'));
      expect(album.layout, equals(AlbumLayout.grid));
      expect(album.photoIds, isEmpty);
      expect(album.coverPhotoId, isEmpty);

      verify(() => box.put(album.id, any<AlbumModel>())).called(1);
    });

    test('uses first photo as coverPhotoId when photoIds provided', () async {
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      final album = await repo.create(
        name: '有照片的影集',
        photoIds: ['photo-x', 'photo-y'],
      );

      expect(album.coverPhotoId, equals('photo-x'));
    });

    test('uses explicit coverPhotoId when provided', () async {
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      final album = await repo.create(
        name: '影集',
        photoIds: ['photo-x', 'photo-y'],
        coverPhotoId: 'photo-y',
      );

      expect(album.coverPhotoId, equals('photo-y'));
    });

    test('sets correct initial layout', () async {
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      final album = await repo.create(
        name: '杂志风',
        layout: AlbumLayout.magazine,
      );

      expect(album.layout, equals(AlbumLayout.magazine));
    });
  });

  // ── rename() ────────────────────────────────────────────────
  group('AlbumRepository.rename', () {
    test('updates name and writes back', () async {
      final original = makeAlbum(name: '旧名称');
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.rename('album-1', '新名称');

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.name, equals('新名称'));
    });

    test('is no-op when album does not exist', () async {
      when(() => box.get('missing')).thenReturn(null);

      await repo.rename('missing', '任何名称');

      verifyNever(() => box.put(any<String>(), any<AlbumModel>()));
    });
  });

  // ── addPhotos() ─────────────────────────────────────────────
  group('AlbumRepository.addPhotos', () {
    test('appends photos to existing list', () async {
      final original = makeAlbum(photoIds: ['a', 'b']);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.addPhotos('album-1', ['c', 'd']);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.photoIds, equals(['a', 'b', 'c', 'd']));
    });

    test('auto-sets coverPhotoId if album has no cover', () async {
      final original = AlbumModel(
        id: 'album-1',
        name: '空封面影集',
        coverPhotoId: '',
        photoIds: [],
        layout: AlbumLayout.grid,
      );
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.addPhotos('album-1', ['first-photo']);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.coverPhotoId, equals('first-photo'));
    });

    test('does not change coverPhotoId if album already has one', () async {
      final original = makeAlbum(coverPhotoId: 'photo-a', photoIds: ['photo-a']);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.addPhotos('album-1', ['photo-b']);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.coverPhotoId, equals('photo-a'));
    });

    test('is no-op when album does not exist', () async {
      when(() => box.get('missing')).thenReturn(null);

      await repo.addPhotos('missing', ['photo-x']);

      verifyNever(() => box.put(any<String>(), any<AlbumModel>()));
    });
  });

  // ── removePhotos() ──────────────────────────────────────────
  group('AlbumRepository.removePhotos', () {
    test('removes photos from list', () async {
      final original = makeAlbum(photoIds: ['a', 'b', 'c']);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.removePhotos('album-1', ['b']);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.photoIds, equals(['a', 'c']));
    });

    test('auto-updates cover if removed photo was cover', () async {
      final original = makeAlbum(coverPhotoId: 'photo-a', photoIds: ['photo-a', 'photo-b']);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.removePhotos('album-1', ['photo-a']);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.coverPhotoId, equals('photo-b'));
    });

    test('clears coverPhotoId if all photos removed', () async {
      final original = makeAlbum(coverPhotoId: 'photo-a', photoIds: ['photo-a']);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.removePhotos('album-1', ['photo-a']);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.coverPhotoId, isEmpty);
    });

    test('is no-op when album does not exist', () async {
      when(() => box.get('missing')).thenReturn(null);

      await repo.removePhotos('missing', ['photo-x']);

      verifyNever(() => box.put(any<String>(), any<AlbumModel>()));
    });
  });

  // ── reorderPhotos() ─────────────────────────────────────────
  group('AlbumRepository.reorderPhotos', () {
    test('replaces photo list with new order', () async {
      final original = makeAlbum(photoIds: ['a', 'b', 'c']);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.reorderPhotos('album-1', ['c', 'a', 'b']);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.photoIds, equals(['c', 'a', 'b']));
    });

    test('clears cover if coverPhotoId not in new list', () async {
      final original = makeAlbum(coverPhotoId: 'a', photoIds: ['a', 'b']);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.reorderPhotos('album-1', ['b', 'c']);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.coverPhotoId, isEmpty);
    });

    test('is no-op when album does not exist', () async {
      when(() => box.get('missing')).thenReturn(null);

      await repo.reorderPhotos('missing', ['a', 'b']);

      verifyNever(() => box.put(any<String>(), any<AlbumModel>()));
    });
  });

  // ── setCover() ──────────────────────────────────────────────
  group('AlbumRepository.setCover', () {
    test('updates coverPhotoId when photo exists in album', () async {
      final original = makeAlbum(photoIds: ['a', 'b', 'c']);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.setCover('album-1', 'c');

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.coverPhotoId, equals('c'));
    });

    test('is no-op when album does not exist', () async {
      when(() => box.get('missing')).thenReturn(null);

      await repo.setCover('missing', 'photo-x');

      verifyNever(() => box.put(any<String>(), any<AlbumModel>()));
    });

    test('is no-op when new cover is not in photoIds', () async {
      final original = makeAlbum(photoIds: ['a', 'b']);
      when(() => box.get('album-1')).thenReturn(original);

      await repo.setCover('album-1', 'not-in-album');

      verifyNever(() => box.put(any<String>(), any<AlbumModel>()));
    });
  });

  // ── setLayout() ─────────────────────────────────────────────
  group('AlbumRepository.setLayout', () {
    test('updates layout and writes back', () async {
      final original = makeAlbum(layout: AlbumLayout.grid);
      when(() => box.get('album-1')).thenReturn(original);
      when(() => box.put(any<String>(), any<AlbumModel>()))
          .thenAnswer((_) async {});

      await repo.setLayout('album-1', AlbumLayout.polaroid);

      final captured = verify(
        () => box.put('album-1', captureAny<AlbumModel>()),
      ).captured.single as AlbumModel;
      expect(captured.layout, equals(AlbumLayout.polaroid));
    });

    test('is no-op when album does not exist', () async {
      when(() => box.get('missing')).thenReturn(null);

      await repo.setLayout('missing', AlbumLayout.collage);

      verifyNever(() => box.put(any<String>(), any<AlbumModel>()));
    });
  });

  // ── delete() ────────────────────────────────────────────────
  group('AlbumRepository.delete', () {
    test('calls box.delete with correct id', () async {
      when(() => box.delete(any<dynamic>())).thenAnswer((_) async {});

      await repo.delete('album-1');

      verify(() => box.delete('album-1')).called(1);
    });

    test('is no-op when id does not exist', () async {
      when(() => box.delete(any<dynamic>())).thenAnswer((_) async {});

      await repo.delete('missing');

      verify(() => box.delete('missing')).called(1);
    });
  });
}