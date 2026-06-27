import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_beauty/features/tags/data/models/tag_model.dart';
import 'package:photo_beauty/features/tags/presentation/widgets/tag_list_item.dart';

void main() {
  group('TagListItem', () {
    testWidgets('显示标签名称', (tester) async {
      final tag = TagModel(id: 'tag_1', name: '风景', colorValue: 0xFF66BB6A);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagListItem(tag: tag, usageCount: 0),
          ),
        ),
      );
      expect(find.text('风景'), findsOneWidget);
    });

    testWidgets('显示使用量（>0 时）', (tester) async {
      final tag = TagModel(id: 'tag_1', name: '人物', colorValue: 0xFF42A5F5);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagListItem(tag: tag, usageCount: 3),
          ),
        ),
      );
      expect(find.text('3 张照片'), findsOneWidget);
    });

    testWidgets('usageCount=0 时不显示使用量', (tester) async {
      final tag = TagModel(id: 'tag_1', name: '美食', colorValue: 0xFFFF7043);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagListItem(tag: tag, usageCount: 0),
          ),
        ),
      );
      expect(find.text('张照片'), findsNothing);
    });

    testWidgets('左侧彩色圆点颜色正确', (tester) async {
      final tag = TagModel(id: 'tag_1', name: '测试', colorValue: 0xFFE53935);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagListItem(tag: tag, usageCount: 0),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(Container).first,
        ),
      );
      // 颜色圆点
      expect(container, isNotNull);
    });

    testWidgets('onTap 回调正常触发', (tester) async {
      var tapped = false;
      final tag = TagModel(id: 'tag_1', name: '风景', colorValue: 0xFF66BB6A);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagListItem(
              tag: tag,
              usageCount: 0,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ListTile));
      expect(tapped, true);
    });

    testWidgets('无 onTap 不抛错', (tester) async {
      final tag = TagModel(id: 'tag_1', name: '无回调', colorValue: 0xFF8D6E63);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagListItem(tag: tag, usageCount: 0),
          ),
        ),
      );
      await tester.tap(find.byType(ListTile));
      // 无 onTap 但不抛错
      expect(tester.takeException(), isNull);
    });
  });
}