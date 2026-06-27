import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photo_beauty/features/tags/data/models/tag_model.dart';
import 'package:photo_beauty/features/tags/presentation/providers/tag_list_provider.dart';
import 'package:photo_beauty/features/tags/presentation/widgets/tag_picker_sheet.dart';

void main() {
  group('TagPickerSheet', () {
    final testTags = [
      TagModel(id: 'tag_001', name: '风景', colorValue: 0xFF66BB6A),
      TagModel(id: 'tag_002', name: '人物', colorValue: 0xFF42A5F5),
      TagModel(id: 'tag_003', name: '美食', colorValue: 0xFFFF7043),
    ];

    /// Builds the sheet directly (not via showTagPickerSheet) for testability.
    Widget buildSheet({
      required Set<String> initialSelectedTagIds,
      required void Function(Set<String>) onConfirm,
    }) {
      return ProviderScope(
        overrides: [
          tagListProvider.overrideWith(() => _SuccessTagListNotifier(testTags)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TagPickerSheet(
              initialSelectedTagIds: initialSelectedTagIds,
              onConfirm: onConfirm,
            ),
          ),
        ),
      );
    }

    testWidgets('renders title and done button', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('标签选择'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('shows search TextField', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('搜索标签...'), findsOneWidget);
    });

    testWidgets('selected section shows "未选择" when nothing selected', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('已选'), findsOneWidget);
      expect(find.text('未选择'), findsOneWidget);
    });

    testWidgets('selected section shows chips when tags are pre-selected', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {'tag_001', 'tag_003'},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('已选'), findsOneWidget);
      // "风景" and "美食" appear twice: once in selected chips area, once in all-tags list
      expect(find.text('风景'), findsNWidgets(2));
      expect(find.text('美食'), findsNWidgets(2));
    });

    testWidgets('all tags list renders all tags', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('风景'), findsOneWidget);
      expect(find.text('人物'), findsOneWidget);
      expect(find.text('美食'), findsOneWidget);
    });

    testWidgets('tapping a tag selects it', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      // Tap "人物" in the list
      await tester.tap(find.text('人物'));
      await tester.pumpAndSettle();

      // Now "人物" should appear in selected section
      expect(find.text('人物'), findsNWidgets(2)); // once in list (unchecked), once in selected
    });

    testWidgets('tapping a selected tag deselects it', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {'tag_002'},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      // "人物" appears in selected + list
      expect(find.text('人物'), findsNWidgets(2));

      // Tap "人物" in the list to deselect
      // The one in selected section has a remove icon, the one in list has check outline
      // We tap the one in the list (the one that's NOT in selected chips area)
      // ListTile for "人物" - find by type, find correct one
      final listTiles = find.byType(ListTile);
      // Find the ListTile with title "人物"
      final personTile = find.descendant(
        of: listTiles,
        matching: find.text('人物'),
      );
      await tester.tap(personTile);
      await tester.pumpAndSettle();

      // Now "人物" only appears once (in selected, since we deselected from selected chip)
      // Actually it should appear only once since it's now deselected
      expect(find.text('人物'), findsOneWidget);
    });

    testWidgets('tapping X on selected chip deselects', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {'tag_001'},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      // Find the close icon within the selected chip area
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsOneWidget);

      await tester.tap(closeIcons.first);
      await tester.pumpAndSettle();

      // "风景" should now only appear once (in the list, unselected)
      expect(find.text('风景'), findsOneWidget);
      expect(find.text('未选择'), findsOneWidget);
    });

    testWidgets('done button calls onConfirm with final selection', (tester) async {
      Set<String>? confirmed;
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {},
        onConfirm: (ids) => confirmed = ids,
      ));
      await tester.pumpAndSettle();

      // Select two tags
      await tester.tap(find.text('风景'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('美食'));
      await tester.pumpAndSettle();

      // Tap done
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(confirmed, {'tag_001', 'tag_003'});
    });

    testWidgets('search filters tags by name', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), '风景');
      await tester.pumpAndSettle();

      // "人物" and "美食" not in filtered list (but search field has "风景")
      expect(find.text('人物'), findsNothing);
      expect(find.text('美食'), findsNothing);
      // "风景" appears twice: search field text + filtered result
      expect(find.text('风景'), findsNWidgets(2));
    });

    testWidgets('search clear button resets filter', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), '风景');
      await tester.pumpAndSettle();
      // Search field has "风景" + filtered result = 2
      expect(find.text('风景'), findsNWidgets(2));
      expect(find.text('人物'), findsNothing);

      // Tap clear
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All tags visible again (search field cleared, so only list items)
      expect(find.text('风景'), findsOneWidget);
      expect(find.text('人物'), findsOneWidget);
      expect(find.text('美食'), findsOneWidget);
    });

    testWidgets('selected tags still shown when filtered by search', (tester) async {
      await tester.pumpWidget(buildSheet(
        initialSelectedTagIds: const {'tag_001'},
        onConfirm: (_) {},
      ));
      await tester.pumpAndSettle();

      // Search for something else
      await tester.enterText(find.byType(TextField), '人物');
      await tester.pumpAndSettle();

      // "人物" appears twice: search field text + filtered result
      expect(find.text('人物'), findsNWidgets(2));
      // "风景" appears once: selected chip (not in search field since we searched "人物")
      expect(find.text('风景'), findsOneWidget);
    });
  });

  group('showTagPickerSheet', () {
    testWidgets('opens as modal bottom sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagListProvider.overrideWith(() => _SuccessTagListNotifier([])),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showTagPickerSheet(
                    context: context,
                    selectedTagIds: const {'tag_001'},
                    onConfirm: (_) {},
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('标签选择'), findsOneWidget);
    });
  });
}

// --- Test notifier helpers ---

class _SuccessTagListNotifier extends TagListNotifier {
  _SuccessTagListNotifier(this._tags);
  final List<TagModel> _tags;

  @override
  Future<List<TagModel>> build() async => _tags;
  @override
  Future<void> refresh() async {}
}
