import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/data/repositories/frame_repository.dart';
import 'package:photo_beauty/features/photos/presentation/providers/batch_apply_template_provider.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/image_saver.dart';

class MockImageSaver extends Mock implements ImageSaver {}

class MockFrameRepository extends Mock implements FrameRepository {}

void main() {
  late MockImageSaver mockSaver;
  late MockFrameRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(_fakeTemplate());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockSaver = MockImageSaver();
    mockRepo = MockFrameRepository();

    when(() => mockSaver.save(any(), name: any(named: 'name')))
        .thenAnswer((_) async {});
    when(() => mockRepo.incrementUsageCount(any()))
        .thenAnswer((_) async {});
  });

  group('BatchApplyTemplateState', () {
    test('BatchApplyTemplateInitial is equal to itself', () {
      const state1 = BatchApplyTemplateInitial();
      const state2 = BatchApplyTemplateInitial();
      expect(state1, equals(state2));
    });

    test('BatchApplyTemplateProcessing has correct progress', () {
      const state = BatchApplyTemplateProcessing(
        current: 3,
        total: 10,
        templateName: 'Test',
        successCount: 2,
        failureCount: 1,
      );
      expect(state.progress, equals(0.3));
    });

    test('BatchApplyTemplateProcessing with zero total has zero progress', () {
      const state = BatchApplyTemplateProcessing(
        current: 0,
        total: 0,
        templateName: 'Test',
      );
      expect(state.progress, equals(0));
    });

    test('BatchApplyTemplateDone has correct values', () {
      const state = BatchApplyTemplateDone(
        successCount: 5,
        failureCount: 2,
        templateName: 'Magazine',
      );
      expect(state.successCount, 5);
      expect(state.failureCount, 2);
      expect(state.templateName, 'Magazine');
    });
  });

  group('BatchApplyTemplateNotifier', () {
    test('initial state is BatchApplyTemplateInitial', () {
      final notifier = BatchApplyTemplateNotifier(imageSaver: mockSaver);
      expect(notifier.state, isA<BatchApplyTemplateInitial>());
    });

    test('reset() returns to initial state', () {
      final notifier = BatchApplyTemplateNotifier(imageSaver: mockSaver);
      notifier.state = const BatchApplyTemplateProcessing(
        current: 5,
        total: 10,
        templateName: 'Test',
      );
      notifier.reset();
      expect(notifier.state, isA<BatchApplyTemplateInitial>());
    });

    test('applyTemplateBatch with empty photoLoaders does nothing', () async {
      final notifier = BatchApplyTemplateNotifier(imageSaver: mockSaver);
      await notifier.applyTemplateBatch(
        template: _fakeTemplate(),
        photoLoaders: {},
        frameRepository: mockRepo,
      );
      expect(notifier.state, isA<BatchApplyTemplateInitial>());
    });

    test('applyTemplateBatch success path updates state correctly', () async {
      final notifier = BatchApplyTemplateNotifier(imageSaver: mockSaver);

      final photoLoaders = <String, Future<Uint8List?> Function()>{
        'photo1': () async => Uint8List.fromList([1, 2, 3]),
        'photo2': () async => Uint8List.fromList([4, 5, 6]),
      };

      await notifier.applyTemplateBatch(
        template: _fakeTemplate(),
        photoLoaders: photoLoaders,
        frameRepository: mockRepo,
      );

      // Should complete with done state (even if individual renders fail,
      // the batch completes)
      expect(notifier.state, isA<BatchApplyTemplateDone>());
    });

    test('applyTemplateBatch null bytes counts as failure', () async {
      final notifier = BatchApplyTemplateNotifier(imageSaver: mockSaver);

      final photoLoaders = <String, Future<Uint8List?> Function()>{
        'photo1': () async => null, // Simulates load failure
      };

      await notifier.applyTemplateBatch(
        template: _fakeTemplate(),
        photoLoaders: photoLoaders,
        frameRepository: mockRepo,
      );

      final doneState = notifier.state as BatchApplyTemplateDone;
      expect(doneState.successCount, 0);
      expect(doneState.failureCount, 1);
    });
  });
}

FrameTemplate _fakeTemplate() {
  return FrameTemplate(
    id: 'test-template',
    name: 'Test Template',
    layers: const [],
    isBuiltIn: false,
    usageCount: 0,
    createdAt: DateTime(2024, 1, 1),
  );
}