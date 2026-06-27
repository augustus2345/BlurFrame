import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/tag_pills.dart';

void main() {
  PhotoModel makePhoto({List<String> tags = const []}) => PhotoModel(
        id: 'photo_001',
        path: '/test/photo_001.jpg',
        tags: tags,
      );

  group('TagPills', () {
    testWidgets('tags 为空时显示"暂无标签"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagPills(photo: makePhoto()),
          ),
        ),
      );

      expect(find.text('暂无标签'), findsOneWidget);
    });

    testWidgets('有标签时显示 Chip pills', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagPills(photo: makePhoto(tags: ['风景', '旅行'])),
          ),
        ),
      );

      expect(find.text('风景'), findsOneWidget);
      expect(find.text('旅行'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
    });

    testWidgets('显示标签标题', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagPills(photo: makePhoto(tags: ['测试'])),
          ),
        ),
      );

      expect(find.text('标签'), findsOneWidget);
      expect(find.byIcon(Icons.local_offer_outlined), findsOneWidget);
    });

    testWidgets('标签可横向滚动（超过一行时）', (tester) async {
      // 创建很多标签
      final tags = List.generate(10, (i) => '标签$i');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: TagPills(photo: makePhoto(tags: tags)),
            ),
          ),
        ),
      );

      // 应该有 SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}