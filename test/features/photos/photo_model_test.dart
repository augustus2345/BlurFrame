import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';

/// Roundtrip tests for [PhotoModel] ↔ Hive serialization (via the generated
/// `PhotoModelAdapter`).
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - All 8 fields survive a save/load roundtrip with byte-for-byte equality.
/// - `width` / `height` / `takenAt` / `frameTemplateId` can be `null` (the
///   type is nullable for a reason — older photos / EXIF read failures).
/// - `tags` is preserved as `List<String>` (Hive built-in, no custom adapter
///   needed).
/// - `starRating` defaults to 0 (no rating); preserves 0–5 values.
/// - `DateTime` microsecond precision is preserved.
/// - Hive typeId is `1` (matches `PLAN.md` R5 reservation).
///
/// Uses a real Hive box in a temp dir (not mocktail) — the adapter is exactly
/// what we want to exercise.
void main() {
  late Directory tempDir;
  late Box<PhotoModel> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('photo_model_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PhotoModelAdapter());
    }
    box = await Hive.openBox<PhotoModel>('test_box');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PhotoModel roundtrip — all fields set', () {
    test('preserves every field exactly', () async {
      const original = PhotoModel(
        id: 'asset-1',
        path: '/storage/emulated/0/DCIM/IMG_0001.jpg',
        width: 4032,
        height: 3024,
        takenAt: null, // 微秒精度在单独测试中验证
        tags: <String>['travel', 'beach'],
        frameTemplateId: 'classic-white',
        starRating: 5,
      );

      await box.put(original.id, original);
      final loaded = box.get('asset-1');

      expect(loaded, isNotNull);
      expect(loaded, equals(original));
      expect(loaded!.id, 'asset-1');
      expect(loaded.path, '/storage/emulated/0/DCIM/IMG_0001.jpg');
      expect(loaded.width, 4032);
      expect(loaded.height, 3024);
      expect(loaded.tags, <String>['travel', 'beach']);
      expect(loaded.frameTemplateId, 'classic-white');
      expect(loaded.starRating, 5);
    });
  });

  group('PhotoModel roundtrip — minimal fields', () {
    test('nullable fields can be null; tags defaults to empty list', () async {
      const original = PhotoModel(
        id: 'asset-2',
        path: '/photos/IMG_0002.jpg',
      );

      await box.put(original.id, original);
      final loaded = box.get('asset-2');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'asset-2');
      expect(loaded.path, '/photos/IMG_0002.jpg');
      expect(loaded.width, isNull);
      expect(loaded.height, isNull);
      expect(loaded.takenAt, isNull);
      expect(loaded.tags, isEmpty);
      expect(loaded.frameTemplateId, isNull);
      expect(loaded.starRating, 0);
    });
  });

  group('PhotoModel roundtrip — DateTime precision', () {
    test('microsecond precision is preserved (Hive native DateTime support)',
        () async {
      final takenAt = DateTime.fromMicrosecondsSinceEpoch(1718943600123456);
      final original = PhotoModel(
        id: 'asset-3',
        path: '/photos/IMG_0003.jpg',
        takenAt: takenAt,
      );

      await box.put(original.id, original);
      final loaded = box.get('asset-3');

      expect(loaded, isNotNull);
      expect(
        loaded!.takenAt?.microsecondsSinceEpoch,
        takenAt.microsecondsSinceEpoch,
      );
    });
  });

  group('PhotoModel roundtrip — list types', () {
    test('non-empty tags list preserves order and contents', () async {
      const original = PhotoModel(
        id: 'asset-4',
        path: '/photos/IMG_0004.jpg',
        tags: <String>['z', 'a', 'm'],
      );

      await box.put(original.id, original);
      final loaded = box.get('asset-4');

      expect(loaded!.tags, <String>['z', 'a', 'm']);
    });

    test('empty tags list roundtrips as empty (not null)', () async {
      const original = PhotoModel(
        id: 'asset-5',
        path: '/photos/IMG_0005.jpg',
        tags: <String>[],
      );

      await box.put(original.id, original);
      final loaded = box.get('asset-5');

      expect(loaded!.tags, isEmpty);
      expect(loaded.tags, isA<List<String>>());
    });
  });

  group('PhotoModel roundtrip — multiple records', () {
    test('key uniqueness — different ids store independently', () async {
      const a = PhotoModel(id: 'a', path: '/a');
      const b = PhotoModel(id: 'b', path: '/b');
      const c = PhotoModel(id: 'c', path: '/c');

      await box.put(a.id, a);
      await box.put(b.id, b);
      await box.put(c.id, c);

      expect(box.values, hasLength(3));
      expect(box.get('a')?.path, '/a');
      expect(box.get('b')?.path, '/b');
      expect(box.get('c')?.path, '/c');
    });
  });

  group('PhotoModel adapter', () {
    test('typeId is 1 (matches PLAN.md R5 reservation)', () {
      expect(PhotoModelAdapter().typeId, 1);
    });
  });
}
