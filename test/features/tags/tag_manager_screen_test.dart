import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photo_beauty/features/tags/data/models/tag_model.dart';
import 'package:photo_beauty/features/tags/data/repositories/tag_repository.dart';
import 'package:photo_beauty/features/tags/presentation/providers/tag_list_provider.dart';
import 'package:photo_beauty/features/tags/presentation/screens/tag_manager_screen.dart';

void main() {
  group('TagManagerScreen', () {
    final testTags = [
      TagModel(id: 'tag_001', name: '风景', colorValue: 0xFF66BB6A),
      TagModel(id: 'tag_002', name: '人物', colorValue: 0xFF42A5F5),
      TagModel(id: 'tag_003', name: '美食', colorValue: 0xFFFF7043),
    ];

    testWidgets('loading 态显示 CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagListProvider.overrideWith(() => _LoadingTagListNotifier()),
          ],
          child: MaterialApp(home: TagManagerScreen()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty 态显示 EmptyState', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagListProvider.overrideWith(() => _EmptyTagListNotifier()),
          ],
          child: MaterialApp(home: TagManagerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('还没有标签'), findsOneWidget);
      expect(find.text('点击右下角 + 创建标签，给照片打上分类标记'), findsOneWidget);
    });

    testWidgets('success 态显示标签列表', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagListProvider.overrideWith(() => _SuccessTagListNotifier(testTags)),
            tagRepositoryProvider.overrideWithValue(_MockTagRepo()),
          ],
          child: MaterialApp(home: TagManagerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('风景'), findsOneWidget);
      expect(find.text('人物'), findsOneWidget);
      expect(find.text('美食'), findsOneWidget);
    });

    testWidgets('error 态显示错误视图和重试按钮', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagListProvider.overrideWith(() => _ErrorTagListNotifier()),
          ],
          child: MaterialApp(home: TagManagerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('FAB 存在并能打开新建 sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagListProvider.overrideWith(() => _EmptyTagListNotifier()),
            tagRepositoryProvider.overrideWithValue(_MockTagRepo()),
          ],
          child: MaterialApp(home: TagManagerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // FAB 存在
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // CreateTagSheet 出现
      expect(find.text('新建标签'), findsWidgets);
      expect(find.text('标签名称'), findsOneWidget);
      expect(find.text('颜色'), findsOneWidget);
    });

    testWidgets('新建 sheet 输入名称后可创建', (tester) async {
      final created = <TagModel>[];
      final mockRepo = _MockTagRepo();
      mockRepo.createdTags = created;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagListProvider.overrideWith(() => _EmptyTagListNotifier()),
            tagRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CreateTagSheet(),
                  ).then((v) {}),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 输入名称
      await tester.enterText(find.byType(TextField), '新标签');
      await tester.pumpAndSettle();

      // 点击创建按钮
      await tester.tap(find.widgetWithText(FilledButton, '创建'));
      await tester.pumpAndSettle();

      expect(created.length, 1);
      expect(created.first.name, '新标签');
    });

    testWidgets('appBar 标题为"标签"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagListProvider.overrideWith(() => _EmptyTagListNotifier()),
            tagRepositoryProvider.overrideWithValue(_MockTagRepo()),
          ],
          child: MaterialApp(home: TagManagerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('标签'), findsOneWidget);
    });
  });
}

// --- Test notifier helpers ---

class _LoadingTagListNotifier extends TagListNotifier {
  @override
  Future<List<TagModel>> build() => Completer<List<TagModel>>().future;
  @override
  Future<void> refresh() async {}
}

class _EmptyTagListNotifier extends TagListNotifier {
  @override
  Future<List<TagModel>> build() async => [];
  @override
  Future<void> refresh() async {}
}

class _SuccessTagListNotifier extends TagListNotifier {
  _SuccessTagListNotifier(this._tags);
  final List<TagModel> _tags;

  @override
  Future<List<TagModel>> build() async => _tags;
  @override
  Future<void> refresh() async {}
}

class _ErrorTagListNotifier extends TagListNotifier {
  @override
  Future<List<TagModel>> build() async => throw Exception('test error');
  @override
  Future<void> refresh() async {}
}

/// 模拟 TagRepository：isTagInUse 全返回 false，创建操作记录到 createdTags。
class _MockTagRepo implements TagRepository {
  List<TagModel> createdTags = [];

  @override
  List<TagModel> getAll() => [];

  @override
  TagModel? getById(String id) => null;

  @override
  Future<TagModel> create({required String name, int colorValue = 0xFF808080}) async {
    final tag = TagModel(id: 'new_tag', name: name, colorValue: colorValue);
    createdTags.add(tag);
    return tag;
  }

  @override
  Future<void> rename(String id, String newName) async {}

  @override
  Future<void> setColor(String id, int newColorValue) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  bool isTagInUse(String tagId) => false;
}