import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/photo_detail_content.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/photo_viewer.dart';

void main() {
  // 1×1 透明 PNG（合法图像字节，CLAUDE.md §7.13）
  final tinyPng = Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
  ),);

  PhotoModel makePhoto({
    String id = 'photo_001',
    List<String> tags = const [],
  }) =>
      PhotoModel(
        id: id,
        path: '/test/$id.jpg',
        width: 360,
        height: 360,
        takenAt: DateTime(2024, 1, 1),
        tags: tags,
      );

  Widget buildSubject({
    PhotoModel? photo,
    Uint8List? imageBytes,
    VoidCallback? onShare,
    VoidCallback? onApplyTemplate,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PhotoDetailContent(
            photo: photo ?? makePhoto(),
            imageBytes: imageBytes ?? tinyPng,
            onShare: onShare,
            onApplyTemplate: onApplyTemplate,
          ),
        ),
      ),
    );
  }

  group('PhotoDetailContent — bottom buttons', () {
    testWidgets('显示分享和应用模版按钮', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byKey(const Key('photo_detail_share_button')), findsOneWidget);
      expect(find.byKey(const Key('photo_detail_apply_template_button')), findsOneWidget);
      expect(find.text('分享'), findsOneWidget);
      expect(find.text('应用模版'), findsOneWidget);
    });

    testWidgets('点击分享按钮显示 SnackBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byKey(const Key('photo_detail_share_button')));
      await tester.pump();

      expect(find.text('分享功能即将推出'), findsOneWidget);
    });

    testWidgets('点击应用模版按钮显示 SnackBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byKey(const Key('photo_detail_apply_template_button')));
      await tester.pump();

      expect(find.text('模版功能即将推出'), findsOneWidget);
    });

    testWidgets('自定义 onShare 回调被调用', (tester) async {
      bool shareCalled = false;
      await tester.pumpWidget(buildSubject(onShare: () => shareCalled = true));
      await tester.pump();

      await tester.tap(find.byKey(const Key('photo_detail_share_button')));
      await tester.pump();

      expect(shareCalled, isTrue);
    });

    testWidgets('自定义 onApplyTemplate 回调被调用', (tester) async {
      bool templateCalled = false;
      await tester.pumpWidget(buildSubject(onApplyTemplate: () => templateCalled = true));
      await tester.pump();

      await tester.tap(find.byKey(const Key('photo_detail_apply_template_button')));
      await tester.pump();

      expect(templateCalled, isTrue);
    });
  });

  group('PhotoDetailContent — layout', () {
    testWidgets('PhotoViewer 渲染大图', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(PhotoViewer), findsOneWidget);
    });

    testWidgets('ExifPanel 在 exif 加载中显示 loading', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 应该显示加载指示器
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}