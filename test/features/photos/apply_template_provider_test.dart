import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/frames/data/models/frame_template.dart';
import 'package:photo_beauty/features/frames/data/repositories/frame_repository.dart';
import 'package:photo_beauty/features/photos/presentation/providers/apply_template_provider.dart';

class _MockFrameRepository extends Mock implements FrameRepository {}

class _MockImageSaver extends Mock implements ImageSaver {}

class _FakeFrameTemplate extends Fake implements FrameTemplate {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFrameTemplate());
    registerFallbackValue(<FrameLayer>[]);
    registerFallbackValue(Uint8List(0));
  });

  // 1×1 透明 PNG（合法图片字节，base64 解码）
  final _validPngBytes = Uint8List.fromList(
    const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00,
      0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
      0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
      0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63,
      0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
      0x82,
    ],
  );

  group('ApplyTemplateNotifier — state transitions', () {
    test('initial state is ApplyTemplateInitial', () {
      final notifier = ApplyTemplateNotifier();
      expect(notifier.state, isA<ApplyTemplateInitial>());
    });

    test('applyTemplate → Rendering → Saving → Success (happy path)',
        () async {
      final repo = _MockFrameRepository();
      final saver = _MockImageSaver();

      when(() => saver.save(any(), name: any(named: 'name')))
          .thenAnswer((_) async {});
      when(() => repo.incrementUsageCount(any())).thenAnswer((_) async {});

      final template = FrameTemplate(
        id: 'test-template',
        name: 'Test',
        layers: const [],
      );

      final notifier = ApplyTemplateNotifier(imageSaver: saver);
      await notifier.applyTemplate(
        template: template,
        fullImageLoader: () async => _validPngBytes,
        frameRepository: repo,
      );

      expect(notifier.state, isA<ApplyTemplateSuccess>());
      final success = notifier.state as ApplyTemplateSuccess;
      expect(success.templateId, equals('test-template'));
      verify(() => saver.save(any(), name: any(named: 'name'))).called(1);
      verify(() => repo.incrementUsageCount('test-template')).called(1);
    });

    test('applyTemplate → ApplyTemplateError when fullImageLoader returns null',
        () async {
      final repo = _MockFrameRepository();
      final notifier = ApplyTemplateNotifier();

      await notifier.applyTemplate(
        template: FrameTemplate(id: 't', name: 'T', layers: const []),
        fullImageLoader: () async => null,
        frameRepository: repo,
      );

      expect(notifier.state, isA<ApplyTemplateError>());
      final err = notifier.state as ApplyTemplateError;
      expect(err.msg, contains('无法读取原图'));
    });

    test('applyTemplate → ApplyTemplateError when saver.save throws',
        () async {
      final repo = _MockFrameRepository();
      final saver = _MockImageSaver();

      when(() => saver.save(any(), name: any(named: 'name')))
          .thenThrow(GalException(
        type: GalExceptionType.accessDenied,
        platformException: PlatformException(code: 'ACCESS_DENIED'),
        stackTrace: StackTrace.empty,
      ));

      final notifier = ApplyTemplateNotifier(imageSaver: saver);
      await notifier.applyTemplate(
        template: FrameTemplate(id: 't', name: 'T', layers: const []),
        fullImageLoader: () async => _validPngBytes,
        frameRepository: repo,
      );

      expect(notifier.state, isA<ApplyTemplateError>());
      final err = notifier.state as ApplyTemplateError;
      expect(err.msg, contains('保存失败'));
    });

    test('reset() returns state to ApplyTemplateInitial', () async {
      final repo = _MockFrameRepository();
      final saver = _MockImageSaver();

      when(() => saver.save(any(), name: any(named: 'name')))
          .thenAnswer((_) async {});
      when(() => repo.incrementUsageCount(any())).thenAnswer((_) async {});

      final notifier = ApplyTemplateNotifier(imageSaver: saver);
      await notifier.applyTemplate(
        template: FrameTemplate(id: 't', name: 'T', layers: const []),
        fullImageLoader: () async => _validPngBytes,
        frameRepository: repo,
      );

      expect(notifier.state, isA<ApplyTemplateSuccess>());

      notifier.reset();
      expect(notifier.state, isA<ApplyTemplateInitial>());
    });

    test('incrementUsageCount failure does not override success state',
        () async {
      final repo = _MockFrameRepository();
      final saver = _MockImageSaver();

      when(() => saver.save(any(), name: any(named: 'name')))
          .thenAnswer((_) async {});
      when(() => repo.incrementUsageCount(any()))
          .thenThrow(Exception('DB write failed'));

      final notifier = ApplyTemplateNotifier(imageSaver: saver);
      await notifier.applyTemplate(
        template: FrameTemplate(id: 't', name: 'T', layers: const []),
        fullImageLoader: () async => _validPngBytes,
        frameRepository: repo,
      );

      // usageCount 抛错不影响最终 success 状态
      expect(notifier.state, isA<ApplyTemplateSuccess>());
    });
  });
}