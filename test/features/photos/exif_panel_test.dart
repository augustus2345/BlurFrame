import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blurframe/features/photos/data/datasources/exif_datasource.dart';
import 'package:blurframe/features/photos/presentation/widgets/exif_panel.dart';

void main() {
  group('ExifPanel', () {
    testWidgets('exif.isEmpty 时不渲染任何内容', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: ExifSummary.empty),
          ),
        ),
      );

      // ExifPanel 应该在 isEmpty 时返回 SizedBox.shrink()
      expect(find.byType(ExifPanel), findsOneWidget);
      // 不应该有图标（所有行都不显示）
      expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
    });

    testWidgets('有相机信息时显示相机行', (tester) async {
      const exif = ExifSummary(make: 'Canon', model: 'EOS R5');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: exif),
          ),
        ),
      );

      expect(find.text('Canon EOS R5'), findsOneWidget);
      expect(find.text('相机'), findsOneWidget);
    });

    testWidgets('有拍摄时间时显示时间行', (tester) async {
      final exif = ExifSummary(
        dateTimeOriginal: DateTime(2024, 6, 15, 10, 30),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: exif),
          ),
        ),
      );

      expect(find.text('2024/06/15 10:30'), findsOneWidget);
      expect(find.text('拍摄时间'), findsOneWidget);
    });

    testWidgets('格式化曝光时间为分数形式', (tester) async {
      final exif = ExifSummary(exposureTime: 0.005); // 1/200
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: exif),
          ),
        ),
      );

      expect(find.text('1/200 s'), findsOneWidget);
    });

    testWidgets('格式化光圈值', (tester) async {
      final exif = ExifSummary(fNumber: 1.8);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: exif),
          ),
        ),
      );

      expect(find.text('f/1.8'), findsOneWidget);
    });

    testWidgets('格式化 ISO', (tester) async {
      final exif = ExifSummary(iso: 400);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: exif),
          ),
        ),
      );

      expect(find.text('ISO 400'), findsOneWidget);
    });

    testWidgets('格式化焦距', (tester) async {
      final exif = ExifSummary(focalLength: 50.0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: exif),
          ),
        ),
      );

      expect(find.text('50 mm'), findsOneWidget);
    });

    testWidgets('曝光时间 >= 1s 时显示小数形式', (tester) async {
      final exif = ExifSummary(exposureTime: 1.0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: exif),
          ),
        ),
      );

      expect(find.text('1.0s'), findsOneWidget);
    });

    testWidgets('缺少字段显示 — 占位符', (tester) async {
      final exif = ExifSummary(make: 'Canon'); // 只有 make
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExifPanel(exif: exif),
          ),
        ),
      );

      expect(find.text('Canon'), findsOneWidget);
      // 其他字段应该显示 —
      expect(find.text('—'), findsWidgets);
    });
  });
}