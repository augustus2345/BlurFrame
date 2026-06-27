import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/shared/services/hive_service.dart';

/// Tests for FrameTemplate / FrameLayer Hive serialization.
///
/// Verifies roundtrip: construct → box.put → box.get → expect equal.
void main() {
  late Directory tempDir;
  late Box<dynamic> testBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('frame_template_test');
    await HiveService.initForTest(tempDir.path);
    // Use a dedicated test box so we don't conflict with the app boxes.
    testBox = await Hive.openBox<dynamic>('frame_template_test_box');
  });

  tearDownAll(() async {
    await Hive.close();
    HiveService.resetForTest(); // void — no await
    await tempDir.delete(recursive: true);
  });

  group('FrameTemplate roundtrip', () {
    test('full fields roundtrip preserves all values', () async {
      final template = FrameTemplate(
        id: 'full-test',
        name: 'Full Test',
        layers: [
          BlurBorderLayer(intensity: 7.0, edge: true),
          TextWatermarkLayer(
            text: '©2026',
            position: WatermarkPosition.bottomRight,
            fontSize: 12,
            color: 0xCCFFFFFF,
          ),
          ColorStripeLayer(
            color: 0xFF1A1A1A,
            width: 0.15,
            cornerRadius: 4,
            position: StripePosition.top,
          ),
        ],
        isBuiltIn: false,
        usageCount: 42,
        createdAt: DateTime.utc(2026, 6, 27, 10, 30),
      );

      await testBox.put('full-test', template);
      final loaded = testBox.get('full-test') as FrameTemplate;

      expect(loaded.id, equals('full-test'));
      expect(loaded.name, equals('Full Test'));
      expect(loaded.isBuiltIn, isFalse);
      expect(loaded.usageCount, equals(42));
      expect(loaded.createdAt, equals(DateTime.utc(2026, 6, 27, 10, 30)));
      expect(loaded.layers, hasLength(3));
      expect(loaded.layers[0], isA<BlurBorderLayer>());
      expect(loaded.layers[1], isA<TextWatermarkLayer>());
      expect(loaded.layers[2], isA<ColorStripeLayer>());
    });

    test('minimal fields (defaults) roundtrip preserves id and empty layers',
        () async {
      final template = FrameTemplate(
        id: 'minimal-test',
        name: 'Minimal',
        layers: const [],
      );

      await testBox.put('minimal-test', template);
      final loaded = testBox.get('minimal-test') as FrameTemplate;

      expect(loaded.id, equals('minimal-test'));
      expect(loaded.name, equals('Minimal'));
      expect(loaded.isBuiltIn, isFalse);
      expect(loaded.usageCount, equals(0));
      expect(loaded.layers, isEmpty);
      // createdAt uses DateTime.now() — just verify it's not null
      expect(loaded.createdAt, isNotNull);
    });

    test('usageCount is mutable and persists after save', () async {
      final template = FrameTemplate(
        id: 'usage-test',
        name: 'Usage',
        layers: const [],
        usageCount: 5,
      );

      await testBox.put('usage-test', template);

      // Simulate incrementing usageCount
      final loaded = testBox.get('usage-test') as FrameTemplate;
      loaded.usageCount = 6;
      await loaded.save();

      final reloaded = testBox.get('usage-test') as FrameTemplate;
      expect(reloaded.usageCount, equals(6));
    });

    test('builtIn=true template persists', () async {
      final template = FrameTemplate(
        id: 'builtin-persist-test',
        name: 'Built-In Persist',
        layers: const [],
        isBuiltIn: true,
        usageCount: 100,
      );

      await testBox.put('builtin-persist-test', template);
      final loaded = testBox.get('builtin-persist-test') as FrameTemplate;

      expect(loaded.isBuiltIn, isTrue);
      expect(loaded.usageCount, equals(100));
    });
  });

  group('FrameLayer subclasses roundtrip', () {
    test('BlurBorderLayer roundtrip preserves intensity and edge', () async {
      final layer = BlurBorderLayer(intensity: 5.5, edge: false);
      await testBox.put('layer-blur', layer);
      final loaded = testBox.get('layer-blur') as BlurBorderLayer;

      expect(loaded.intensity, equals(5.5));
      expect(loaded.edge, isFalse);
    });

    test('TextWatermarkLayer roundtrip preserves all fields', () async {
      final layer = TextWatermarkLayer(
        text: 'Hello World',
        position: WatermarkPosition.center,
        fontSize: 18.0,
        color: 0xFFFF8800,
      );
      await testBox.put('layer-wm', layer);
      final loaded = testBox.get('layer-wm') as TextWatermarkLayer;

      expect(loaded.text, equals('Hello World'));
      expect(loaded.position, equals(WatermarkPosition.center));
      expect(loaded.fontSize, equals(18.0));
      expect(loaded.color, equals(0xFFFF8800));
    });

    test('ColorStripeLayer roundtrip preserves all fields', () async {
      final layer = ColorStripeLayer(
        color: 0xFF0000CC,
        width: 0.2,
        cornerRadius: 8,
        position: StripePosition.bottom,
      );
      await testBox.put('layer-stripe', layer);
      final loaded = testBox.get('layer-stripe') as ColorStripeLayer;

      expect(loaded.color, equals(0xFF0000CC));
      expect(loaded.width, equals(0.2));
      expect(loaded.cornerRadius, equals(8));
      expect(loaded.position, equals(StripePosition.bottom));
    });

    test('list of mixed layer types roundtrips correctly', () async {
      final template = FrameTemplate(
        id: 'mixed-layers',
        name: 'Mixed',
        layers: [
          BlurBorderLayer(intensity: 4.0),
          ColorStripeLayer(color: 0xFF000000, width: 0.1),
          TextWatermarkLayer(
            text: 'Test',
            position: WatermarkPosition.topLeft,
          ),
        ],
      );

      await testBox.put('mixed-layers', template);
      final loaded = testBox.get('mixed-layers') as FrameTemplate;

      expect(loaded.layers, hasLength(3));
      expect(loaded.layers[0], isA<BlurBorderLayer>());
      expect(loaded.layers[1], isA<ColorStripeLayer>());
      expect(loaded.layers[2], isA<TextWatermarkLayer>());
    });
  });

  group('copyWith / withIncrementedUsage', () {
    test('copyWith creates a new instance with updated fields', () {
      final original = FrameTemplate(
        id: 'orig',
        name: 'Original',
        layers: const [],
        usageCount: 3,
      );

      final copy = original.copyWith(name: 'Renamed', usageCount: 10);

      expect(copy.id, equals('orig'));
      expect(copy.name, equals('Renamed'));
      expect(copy.usageCount, equals(10));
      expect(original.usageCount, equals(3)); // original unchanged
    });

    test('withIncrementedUsage increments usageCount by 1', () {
      final original = FrameTemplate(
        id: 'inc',
        name: 'Inc',
        layers: const [],
        usageCount: 7,
      );

      final copy = original.withIncrementedUsage();

      expect(copy.usageCount, equals(8));
      expect(original.usageCount, equals(7)); // original unchanged
    });
  });
}