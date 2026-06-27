import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/presentation/widgets/star_rating.dart';

/// Tests for [StarRating] widget — 5-tap star rating component.
void main() {
  Widget buildSubject({
    required int starRating,
    required ValueChanged<int> onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StarRating(
          starRating: starRating,
          onChanged: onChanged,
        ),
      ),
    );
  }

  group('StarRating', () {
    testWidgets('renders 5 stars', (tester) async {
      await tester.pumpWidget(buildSubject(
        starRating: 0,
        onChanged: (_) {},
      ));

      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    });

    testWidgets('displays filled stars for current rating', (tester) async {
      await tester.pumpWidget(buildSubject(
        starRating: 3,
        onChanged: (_) {},
      ));

      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('tapping star 1 sets rating to 1', (tester) async {
      var changedTo = -1;
      await tester.pumpWidget(buildSubject(
        starRating: 0,
        onChanged: (v) => changedTo = v,
      ));

      await tester.tap(find.byKey(const Key('star_1')));
      await tester.pump();

      expect(changedTo, 1);
    });

    testWidgets('tapping star 4 sets rating to 4', (tester) async {
      var changedTo = -1;
      await tester.pumpWidget(buildSubject(
        starRating: 0,
        onChanged: (v) => changedTo = v,
      ));

      await tester.tap(find.byKey(const Key('star_4')));
      await tester.pump();

      expect(changedTo, 4);
    });

    testWidgets('tapping star 5 sets rating to 5', (tester) async {
      var changedTo = -1;
      await tester.pumpWidget(buildSubject(
        starRating: 3,
        onChanged: (v) => changedTo = v,
      ));

      await tester.tap(find.byKey(const Key('star_5')));
      await tester.pump();

      expect(changedTo, 5);
    });

    testWidgets('clamps starRating to 0-5 in display', (tester) async {
      // starRating=10 should display as 5 filled stars
      await tester.pumpWidget(buildSubject(
        starRating: 10,
        onChanged: (_) {},
      ));

      expect(find.byIcon(Icons.star), findsNWidgets(5));
      expect(find.byIcon(Icons.star_border), findsNWidgets(0));
    });

    testWidgets('negative starRating displays as 0', (tester) async {
      await tester.pumpWidget(buildSubject(
        starRating: -3,
        onChanged: (_) {},
      ));

      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      expect(find.byIcon(Icons.star), findsNWidgets(0));
    });

    testWidgets('displays star label', (tester) async {
      await tester.pumpWidget(buildSubject(
        starRating: 0,
        onChanged: (_) {},
      ));

      expect(find.text('星级'), findsOneWidget);
    });
  });
}
