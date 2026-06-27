import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:photo_beauty/features/tags/data/models/tag_model.dart';

/// Roundtrip tests for [TagModel] ↔ Hive serialization (via the generated
/// `TagModelAdapter`).
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - All 4 fields survive a save/load roundtrip with byte-for-byte equality.
/// - `createdAt` defaults to `DateTime.now()` when not provided.
/// - Hive typeId is `8` (matches `PLAN.md` R5 reservation).
///
/// Uses a real Hive box in a temp dir (not mocktail) — the adapter is exactly
/// what we want to exercise.
void main() {
  late Directory tempDir;
  late Box<TagModel> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tag_model_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(TagModelAdapter());
    }
    box = await Hive.openBox<TagModel>('test_tags_box');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TagModel roundtrip — all fields set', () {
    test('preserves every field exactly', () async {
      final createdAt = DateTime.fromMicrosecondsSinceEpoch(1718943600123456);
      final original = TagModel(
        id: 'tag-1',
        name: 'Travel',
        colorValue: 0xFF2196F3,
        createdAt: createdAt,
      );

      await box.put(original.id, original);
      final loaded = box.get('tag-1');

      expect(loaded, isNotNull);
      expect(loaded, equals(original));
      expect(loaded!.id, 'tag-1');
      expect(loaded.name, 'Travel');
      expect(loaded.colorValue, 0xFF2196F3);
      expect(loaded.createdAt.microsecondsSinceEpoch,
          createdAt.microsecondsSinceEpoch);
    });
  });

  group('TagModel roundtrip — minimal fields', () {
    test('nullable createdAt defaults to DateTime.now()', () async {
      final before = DateTime.now();
      final original = TagModel(
        id: 'tag-2',
        name: 'Beach',
        colorValue: 0xFFFF9800,
      );
      final after = DateTime.now();

      await box.put(original.id, original);
      final loaded = box.get('tag-2');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'tag-2');
      expect(loaded.name, 'Beach');
      expect(loaded.colorValue, 0xFFFF9800);
      expect(loaded.createdAt.isAfter(before) ||
          loaded.createdAt.isAtSameMomentAs(before), isTrue);
      expect(loaded.createdAt.isBefore(after) ||
          loaded.createdAt.isAtSameMomentAs(after), isTrue);
    });
  });

  group('TagModel roundtrip — colorValue formats', () {
    test('opaque color (0xFFRRGGBB) is preserved', () async {
      final original = TagModel(
        id: 'tag-3',
        name: 'Red',
        colorValue: 0xFFF44336,
      );

      await box.put(original.id, original);
      final loaded = box.get('tag-3');

      expect(loaded!.colorValue, 0xFFF44336);
    });

    test('transparent color (0xAARRGGBB) is preserved', () async {
      final original = TagModel(
        id: 'tag-4',
        name: 'SemiBlue',
        colorValue: 0x80FFFFFF,
      );

      await box.put(original.id, original);
      final loaded = box.get('tag-4');

      expect(loaded!.colorValue, 0x80FFFFFF);
    });
  });

  group('TagModel roundtrip — multiple records', () {
    test('different ids store independently', () async {
      final a = TagModel(id: 'a', name: 'Alpha', colorValue: 0xFF000000);
      final b = TagModel(id: 'b', name: 'Beta', colorValue: 0xFFFFFFFF);
      final c = TagModel(id: 'c', name: 'Gamma', colorValue: 0xFF00FF00);

      await box.put(a.id, a);
      await box.put(b.id, b);
      await box.put(c.id, c);

      expect(box.values, hasLength(3));
      expect(box.get('a')?.name, 'Alpha');
      expect(box.get('b')?.name, 'Beta');
      expect(box.get('c')?.name, 'Gamma');
    });
  });

  group('TagModel copyWith', () {
    test('copyWith overrides specified fields', () {
      final original = TagModel(
        id: 'tag-5',
        name: 'Original',
        colorValue: 0xFF000000,
      );
      final copied = original.copyWith(name: 'Renamed', colorValue: 0xFFFF0000);

      expect(copied.id, 'tag-5');
      expect(copied.name, 'Renamed');
      expect(copied.colorValue, 0xFFFF0000);
      expect(original.name, 'Original');
      expect(original.colorValue, 0xFF000000);
    });
  });

  group('TagModel adapter', () {
    test('typeId is 8 (matches PLAN.md R5 reservation)', () {
      expect(TagModelAdapter().typeId, 8);
    });
  });
}
