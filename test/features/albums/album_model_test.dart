import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:photo_beauty/features/albums/data/models/album_model.dart';

/// Roundtrip tests for [AlbumModel] ↔ Hive serialization (via the generated
/// `AlbumModelAdapter`).
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - All 6 fields survive a save/load roundtrip with byte-for-byte equality.
/// - `photoIds` is preserved as `List<String>` (Hive built-in, no custom
///   adapter needed).
/// - `createdAt` defaults to `DateTime.now()` when null, and microsecond
///   precision is preserved.
/// - `layout` defaults to `AlbumLayout.grid`.
/// - Hive typeId is `7` (matches `PLAN.md` R5 reservation).
/// - `AlbumLayout` enum has typeId 11.
///
/// Uses a real Hive box in a temp dir (not mocktail) — the adapter is exactly
/// what we want to exercise.
void main() {
  late Directory tempDir;
  late Box<AlbumModel> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('album_model_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(AlbumModelAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(AlbumLayoutAdapter());
    }
    box = await Hive.openBox<AlbumModel>('test_album_box');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AlbumModel roundtrip — all fields set', () {
    test('preserves every field exactly', () async {
      final createdAt = DateTime.fromMicrosecondsSinceEpoch(1718943600123456);
      final original = AlbumModel(
        id: 'album-1',
        name: 'Summer Trip',
        coverPhotoId: 'photo-3',
        photoIds: ['photo-1', 'photo-2', 'photo-3'],
        createdAt: createdAt,
        layout: AlbumLayout.magazine,
      );

      await box.put(original.id, original);
      final loaded = box.get('album-1');

      expect(loaded, isNotNull);
      expect(loaded, equals(original));
      expect(loaded!.id, 'album-1');
      expect(loaded.name, 'Summer Trip');
      expect(loaded.coverPhotoId, 'photo-3');
      expect(loaded.photoIds, ['photo-1', 'photo-2', 'photo-3']);
      expect(loaded.createdAt.microsecondsSinceEpoch, createdAt.microsecondsSinceEpoch);
      expect(loaded.layout, AlbumLayout.magazine);
    });
  });

  group('AlbumModel roundtrip — minimal fields', () {
    test('optional fields get correct defaults', () async {
      final before = DateTime.now().microsecondsSinceEpoch;
      final original = AlbumModel(
        id: 'album-2',
        name: 'Quick Snap',
        coverPhotoId: 'photo-0',
        photoIds: <String>[],
      );
      final after = DateTime.now().microsecondsSinceEpoch;

      await box.put(original.id, original);
      final loaded = box.get('album-2');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'album-2');
      expect(loaded.name, 'Quick Snap');
      expect(loaded.coverPhotoId, 'photo-0');
      expect(loaded.photoIds, isEmpty);
      expect(loaded.layout, AlbumLayout.grid);
      // createdAt defaulted to DateTime.now() — check it landed in the window
      expect(loaded.createdAt.microsecondsSinceEpoch, greaterThanOrEqualTo(before));
      expect(loaded.createdAt.microsecondsSinceEpoch, lessThanOrEqualTo(after));
    });
  });

  group('AlbumModel roundtrip — DateTime precision', () {
    test('microsecond precision is preserved', () async {
      final createdAt = DateTime.fromMicrosecondsSinceEpoch(1718943600123456);
      final original = AlbumModel(
        id: 'album-3',
        name: 'Precision Test',
        coverPhotoId: 'p-1',
        photoIds: ['p-1'],
        createdAt: createdAt,
      );

      await box.put(original.id, original);
      final loaded = box.get('album-3');

      expect(loaded, isNotNull);
      expect(
        loaded!.createdAt.microsecondsSinceEpoch,
        createdAt.microsecondsSinceEpoch,
      );
    });
  });

  group('AlbumModel roundtrip — list types', () {
    test('non-empty photoIds list preserves order', () async {
      final original = AlbumModel(
        id: 'album-4',
        name: 'Reordered',
        coverPhotoId: 'x',
        photoIds: ['z', 'a', 'm'],
      );

      await box.put(original.id, original);
      final loaded = box.get('album-4');

      expect(loaded!.photoIds, ['z', 'a', 'm']);
    });

    test('empty photoIds list roundtrips as empty (not null)', () async {
      final original = AlbumModel(
        id: 'album-5',
        name: 'Empty Album',
        coverPhotoId: 'x',
        photoIds: <String>[],
      );

      await box.put(original.id, original);
      final loaded = box.get('album-5');

      expect(loaded!.photoIds, isEmpty);
      expect(loaded.photoIds, isA<List<String>>());
    });
  });

  group('AlbumModel roundtrip — multiple records', () {
    test('key uniqueness — different ids store independently', () async {
      final a = AlbumModel(id: 'a', name: 'A', coverPhotoId: 'x', photoIds: ['x']);
      final b = AlbumModel(id: 'b', name: 'B', coverPhotoId: 'x', photoIds: ['x']);
      final c = AlbumModel(id: 'c', name: 'C', coverPhotoId: 'x', photoIds: ['x']);

      await box.put(a.id, a);
      await box.put(b.id, b);
      await box.put(c.id, c);

      expect(box.values, hasLength(3));
      expect(box.get('a')?.name, 'A');
      expect(box.get('b')?.name, 'B');
      expect(box.get('c')?.name, 'C');
    });
  });

  group('AlbumModel adapter', () {
    test('typeId is 7 (matches PLAN.md R5 reservation)', () {
      expect(AlbumModelAdapter().typeId, 7);
    });
  });

  group('AlbumLayout enum', () {
    test('typeId is 11', () {
      expect(AlbumLayoutAdapter().typeId, 11);
    });

    test('all 4 layout values roundtrip', () async {
      for (final layout in AlbumLayout.values) {
        final original = AlbumModel(
          id: 'layout-test-${layout.name}',
          name: 'Test',
          coverPhotoId: 'x',
          photoIds: ['x'],
          layout: layout,
        );
        await box.put(original.id, original);
        final loaded = box.get(original.id);
        expect(loaded!.layout, layout);
      }
    });
  });

  group('AlbumModel copyWith', () {
    test('copyWith preserves unchanged fields', () async {
      final original = AlbumModel(
        id: 'album-copy',
        name: 'Original',
        coverPhotoId: 'cover-1',
        photoIds: ['p-1', 'p-2'],
        layout: AlbumLayout.collage,
      );

      final copied = original.copyWith(name: 'Renamed');

      expect(copied.id, 'album-copy');
      expect(copied.name, 'Renamed');
      expect(copied.coverPhotoId, 'cover-1');
      expect(copied.photoIds, ['p-1', 'p-2']);
      expect(copied.layout, AlbumLayout.collage);
    });

    test('copyWith with photoIds creates a new list reference', () async {
      final original = AlbumModel(
        id: 'album-list-copy',
        name: 'Test',
        coverPhotoId: 'x',
        photoIds: ['p-1'],
      );

      final copied = original.copyWith(photoIds: ['p-1', 'p-2']);

      expect(original.photoIds, ['p-1']);
      expect(copied.photoIds, ['p-1', 'p-2']);
      expect(identical(original.photoIds, copied.photoIds), isFalse);
    });
  });
}