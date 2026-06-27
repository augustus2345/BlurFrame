import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/multi_select_app_bar.dart';

void main() {
  group('MultiSelectAppBar', () {
    testWidgets('显示选中数量', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MultiSelectAppBar(
              selectedCount: 5,
              totalCount: 10,
              onClose: () {},
              onSelectAll: () {},
            ),
          ),
        ),
      );

      expect(find.text('5 项已选中'), findsOneWidget);
    });

    testWidgets('全选按钮在未全选时显示"全选"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MultiSelectAppBar(
              selectedCount: 3,
              totalCount: 10,
              onClose: () {},
              onSelectAll: () {},
            ),
          ),
        ),
      );

      expect(find.text('全选'), findsOneWidget);
    });

    testWidgets('全选按钮在全选时显示"取消全选"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MultiSelectAppBar(
              selectedCount: 10,
              totalCount: 10,
              onClose: () {},
              onSelectAll: () {},
            ),
          ),
        ),
      );

      expect(find.text('取消全选'), findsOneWidget);
    });

    testWidgets('点击关闭按钮调用 onClose', (tester) async {
      bool closeCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MultiSelectAppBar(
              selectedCount: 5,
              totalCount: 10,
              onClose: () => closeCalled = true,
              onSelectAll: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closeCalled, isTrue);
    });

    testWidgets('点击全选按钮调用 onSelectAll', (tester) async {
      bool selectAllCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MultiSelectAppBar(
              selectedCount: 5,
              totalCount: 10,
              onClose: () {},
              onSelectAll: () => selectAllCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('全选'));
      expect(selectAllCalled, isTrue);
    });

    testWidgets('5 项批量操作按钮都存在', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MultiSelectAppBar(
              selectedCount: 5,
              totalCount: 10,
              onClose: () {},
              onSelectAll: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('multi_select_delete')), findsOneWidget);
      expect(find.byKey(const Key('multi_select_tags')), findsOneWidget);
      expect(find.byKey(const Key('multi_select_star')), findsOneWidget);
      expect(find.byKey(const Key('multi_select_album')), findsOneWidget);
      expect(find.byKey(const Key('multi_select_frame')), findsOneWidget);
    });

    testWidgets('点击未实现的操作按钮显示 SnackBar 占位提示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MultiSelectAppBar(
              selectedCount: 5,
              totalCount: 10,
              onClose: () {},
              onSelectAll: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('multi_select_tags')));
      await tester.pump();

      expect(find.text('标签功能即将推出'), findsOneWidget);
    });
  });
}