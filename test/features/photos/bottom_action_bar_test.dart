import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/bottom_action_bar.dart';

/// Tests for [BottomActionBar] — the 5-icon footer on the photo detail page.
void main() {
  Widget buildSubject({
    String? photoId = 'photo_001',
    Future<void> Function(String)? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BottomActionBar(
          photoId: photoId,
          onDelete: onDelete ?? (_) async {},
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

    testWidgets('frame button shows "即将推出" SnackBar', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const Key('photo_detail_action_frame')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_detail_frame_snackbar')), findsOneWidget);
      expect(find.text('模版功能即将推出'), findsOneWidget);
    });

    testWidgets(
      'tag / star / album buttons are disabled placeholders',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        final tagsBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_tags')),
        );
        final starBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_star')),
        );
        final albumBtn = tester.widget<IconButton>(
          find.byKey(const Key('photo_detail_action_album')),
        );

        expect(tagsBtn.onPressed, isNull);
        expect(starBtn.onPressed, isNull);
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

        expect(deleteBtn.onPressed, isNull);
        expect(frameBtn.onPressed, isNull);
      },
    );
  });
}