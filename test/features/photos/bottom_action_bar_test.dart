import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/bottom_action_bar.dart';

/// Tests for [BottomActionBar] — the 5-icon footer on the photo detail page.
void main() {
  Widget buildSubject({
    String? photoId = 'photo_001',
    Future<void> Function(String)? onDelete,
    VoidCallback? onApplyTemplate,
    VoidCallback? onTags,
    VoidCallback? onStar,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BottomActionBar(
          photoId: photoId,
          onDelete: onDelete ?? (_) async {},
          onApplyTemplate: onApplyTemplate,
          onTags: onTags,
          onStar: onStar,
        ),
      ),
    );
  }

  group('BottomActionBar', () {
    testWidgets('renders all 5 action buttons in order', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byKey(const Key('photo_detail_action_delete')), findsOneWidget);
      expect(find.byKey(const Key('photo_detail_action_tags')), findsOneWidget);
      expect(find.byKey(const Key('photo_detail_action_star')), findsOneWidget);
      expect(find.byKey(const Key('photo_detail_action_album')), findsOneWidget);
      expect(find.byKey(const Key('photo_detail_action_frame')), findsOneWidget);
    });

    testWidgets(
      'delete flow: tap → confirm dialog → confirm → onDelete called',
      (tester) async {
        var calledWith = '';
        await tester.pumpWidget(
          buildSubject(onDelete: (id) async => calledWith = id),
        );

        await tester.tap(find.byKey(const Key('photo_detail_action_delete')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('photo_detail_delete_dialog')), findsOneWidget);
        await tester.tap(find.byKey(const Key('photo_detail_delete_confirm')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('photo_detail_delete_dialog')), findsNothing);
        expect(calledWith, 'photo_001');
      },
    );

    testWidgets(
      'delete flow: tap delete → confirm dialog → cancel → onDelete NOT called',
      (tester) async {
        var called = false;
        await tester.pumpWidget(
          buildSubject(onDelete: (_) async => called = true),
        );

        await tester.tap(find.byKey(const Key('photo_detail_action_delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('photo_detail_delete_cancel')));
        await tester.pumpAndSettle();

        expect(called, isFalse);
      },
    );

    testWidgets(
      'frame button calls onApplyTemplate when provided and photoId is set',
      (tester) async {
        var called = false;
        await tester.pumpWidget(
          buildSubject(onApplyTemplate: () => called = true),
        );

        await tester.tap(find.byKey(const Key('photo_detail_action_frame')));
        await tester.pump();

        expect(called, isTrue);
      },
    );

    testWidgets(
      'frame button does NOT crash when onApplyTemplate is null',
      (tester) async {
        // photoId is set but onApplyTemplate is null — button is disabled,
        // so tap should do nothing (no exception).
        await tester.pumpWidget(buildSubject(onApplyTemplate: null));

        final frameBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_frame')),
        );
        expect(frameBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'tag button is disabled when onTags is null',
      (tester) async {
        await tester.pumpWidget(buildSubject(onTags: null));

        final tagsBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_tags')),
        );
        expect(tagsBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'star button calls onStar when provided and photoId is set',
      (tester) async {
        var called = false;
        await tester.pumpWidget(
          buildSubject(onStar: () => called = true),
        );

        await tester.tap(find.byKey(const Key('photo_detail_action_star')));
        await tester.pump();

        expect(called, isTrue);
      },
    );

    testWidgets(
      'star button is disabled when onStar is null',
      (tester) async {
        await tester.pumpWidget(buildSubject(onStar: null));

        final starBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_star')),
        );
        expect(starBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'album button is disabled placeholder',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        final albumBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_album')),
        );
        expect(albumBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'when photoId is null, all actionable buttons are disabled',
      (tester) async {
        await tester.pumpWidget(buildSubject(photoId: null));

        final deleteBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_delete')),
        );
        final frameBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_frame')),
        );
        final starBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_star')),
        );

        expect(deleteBtn.onPressed, isNull);
        expect(frameBtn.onPressed, isNull);
        expect(starBtn.onPressed, isNull);
      },
    );
  });
}