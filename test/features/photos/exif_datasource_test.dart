import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/datasources/exif_datasource.dart';
import 'package:photo_manager/photo_manager.dart';

/// Tests for [ExifSummary.fromTags] + [ExifDatasource] — the boundary between
/// the `exif` package's raw IFD data and our domain ([ExifSummary]).
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - [ExifSummary.fromTags] extracts the 7 business fields from a
///   `Map<String, IfdTag>` keyed by `"<IFD> <TagName>"` (e.g.
///   `"Image Make"`, `"EXIF DateTimeOriginal"`).
/// - Missing key → `null`. Wrong value type → `null`. Empty collection → `null`
///   (this is the critical `IfdNone.firstAsInt() == 0` trap guard).
/// - ASCII strings get trailing `\x00` stripped + trimmed.
/// - `EXIF DateTimeOriginal` is parsed as local time from `"YYYY:MM:DD HH:MM:SS"`.
/// - [ExifDatasource.parse] fails silently: any throw / null bytes → [ExifSummary.empty].
/// - DI: injected [readBytes] and [parseExif] are each invoked exactly once
///   per [ExifDatasource.parse] call, with the expected inputs.
void main() {
  // ─── helpers ──────────────────────────────────────────────────────────────

  /// Build a fake IfdTag for an ASCII string value (Make / Model).
  IfdTag asciiTag(String value, {int id = 0x010F}) => IfdTag(
        tag: id,
        tagType: 'ASCII',
        printable: value,
        values: IfdBytes(Uint8List.fromList('$value\x00'.codeUnits)),
      );

  /// Build a fake IfdTag for the EXIF DateTimeOriginal ASCII field.
  /// `ascii` should be the raw 19-byte string e.g. "2024:06:20 14:30:00".
  IfdTag dateTimeOriginalTag(String ascii) => IfdTag(
        tag: 0x9003,
        tagType: 'ASCII',
        printable: ascii,
        values: IfdBytes(Uint8List.fromList('$ascii\x00'.codeUnits)),
      );

  /// Build a fake IfdTag for a rational value (FNumber / ExposureTime /
  /// FocalLength). `num/den` becomes the single Ratio.
  IfdTag ratioTag(int num, int den, {int id = 0x829D}) => IfdTag(
        tag: id,
        tagType: 'RATIONAL',
        printable: '$num/$den',
        values: IfdRatios([Ratio(num, den)]),
      );

  /// Build a fake IfdTag for an int value (ISOSpeedRatings).
  IfdTag intTag(int value, {int id = 0x8827}) => IfdTag(
        tag: id,
        tagType: 'SHORT',
        printable: '$value',
        values: IfdInts([value]),
      );

  // ─── ExifSummary.fromTags ─────────────────────────────────────────────────

  group('ExifSummary.fromTags', () {
    test('empty tags map → empty summary', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{});

      expect(summary, ExifSummary.empty);
      expect(summary.isEmpty, isTrue);
    });

    test('Image Make present → make field set', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'Image Make': asciiTag('Canon'),
      });

      expect(summary.make, 'Canon');
      expect(summary.isEmpty, isFalse);
    });

    test('Image Make empty printable (e.g. scan garbage) → null', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'Image Make': asciiTag(''),
      });

      expect(summary.make, isNull);
    });

    test('EXIF DateTimeOriginal happy path → local DateTime', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'EXIF DateTimeOriginal': dateTimeOriginalTag('2024:06:20 14:30:00'),
      });

      expect(summary.dateTimeOriginal, DateTime(2024, 6, 20, 14, 30, 0));
    });

    test('EXIF DateTimeOriginal empty bytes → null', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'EXIF DateTimeOriginal': IfdTag(
          tag: 0x9003,
          tagType: 'ASCII',
          printable: '',
          values: IfdBytes(Uint8List(0)),
        ),
      });

      expect(summary.dateTimeOriginal, isNull);
    });

    test('EXIF DateTimeOriginal malformed string → null', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'EXIF DateTimeOriginal': dateTimeOriginalTag('not-a-date-at-all!!!'),
      });

      expect(summary.dateTimeOriginal, isNull);
    });

    test('EXIF FNumber Ratio(28,10) → 2.8', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'EXIF FNumber': ratioTag(28, 10, id: 0x829D),
      });

      expect(summary.fNumber, 2.8);
    });

    test('EXIF ExposureTime Ratio(1,200) → 0.005', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'EXIF ExposureTime': ratioTag(1, 200, id: 0x829A),
      });

      expect(summary.exposureTime, closeTo(0.005, 1e-9));
    });

    test('EXIF ISOSpeedRatings [400] → 400', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'EXIF ISOSpeedRatings': intTag(400, id: 0x8827),
      });

      expect(summary.iso, 400);
    });

    test('EXIF FocalLength Ratio(50,1) → 50.0', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'EXIF FocalLength': ratioTag(50, 1, id: 0x920A),
      });

      expect(summary.focalLength, 50.0);
    });

    test(
        'IfdNone for FNumber → null '
        '(avoids the IfdNone.firstAsInt() == 0 trap)', () {
      // If a tag is registered but with IfdNone values, ratioDouble must
      // refuse to coerce — otherwise we'd report fNumber=0 (or in the int
      // path, iso=0) for missing fields.
      final tags = <String, IfdTag>{
        'EXIF FNumber': IfdTag(
          tag: 0x829D,
          tagType: 'RATIONAL',
          printable: '',
          values: const IfdNone(),
        ),
        'EXIF ISOSpeedRatings': IfdTag(
          tag: 0x8827,
          tagType: 'SHORT',
          printable: '',
          values: const IfdNone(),
        ),
      };

      final summary = ExifSummary.fromTags(tags);

      expect(summary.fNumber, isNull);
      expect(summary.iso, isNull);
    });

    test('mixed present + absent → only present fields are set', () {
      final summary = ExifSummary.fromTags(<String, IfdTag>{
        'Image Make': asciiTag('Apple'),
        'EXIF FNumber': ratioTag(18, 10, id: 0x829D),
        // Model / DateTimeOriginal / ExposureTime / ISO / FocalLength absent
      });

      expect(summary.make, 'Apple');
      expect(summary.fNumber, 1.8);
      expect(summary.model, isNull);
      expect(summary.dateTimeOriginal, isNull);
      expect(summary.exposureTime, isNull);
      expect(summary.iso, isNull);
      expect(summary.focalLength, isNull);
    });
  });

  // ─── ExifDatasource.parseBytes ────────────────────────────────────────────

  group('ExifDatasource.parseBytes', () {
    test('injected parseExif throws → empty summary (does not rethrow)',
        () async {
      final datasource = ExifDatasource(
        parseExif: (_) async => throw StateError('corrupt jpeg'),
      );

      final summary = await datasource.parseBytes(Uint8List(0));

      expect(summary, ExifSummary.empty);
    });

    test('injected parseExif returns tags → extracted summary', () async {
      final datasource = ExifDatasource(
        parseExif: (_) async => <String, IfdTag>{
          'Image Make': asciiTag('SONY'),
          'EXIF ISOSpeedRatings': intTag(800, id: 0x8827),
        },
      );

      final summary = await datasource.parseBytes(Uint8List(0));

      expect(summary.make, 'SONY');
      expect(summary.iso, 800);
    });
  });

  // ─── ExifDatasource.parse ─────────────────────────────────────────────────

  group('ExifDatasource.parse', () {
    test('injected readBytes returns null → empty summary', () async {
      final datasource = ExifDatasource(
        readBytes: (_) async => null,
        parseExif: (_) async => <String, IfdTag>{
          // 即使 parseExif 有内容，readBytes 为 null 时也应短路
          'Image Make': asciiTag('Canon'),
        },
      );

      final summary = await datasource.parse(_stubAsset());

      expect(summary, ExifSummary.empty);
    });

    test('happy path: readBytes + parseExif both invoked correctly', () async {
      final asset = _stubAsset();
      final seenBytes = <Uint8List>[];
      AssetEntity? seenAsset;

      final datasource = ExifDatasource(
        readBytes: (a) async {
          seenAsset = a;
          return Uint8List.fromList([1, 2, 3]);
        },
        parseExif: (b) async {
          seenBytes.add(b);
          return <String, IfdTag>{
            'Image Model': asciiTag('iPhone 15 Pro'),
          };
        },
      );

      final summary = await datasource.parse(asset);

      expect(seenAsset, same(asset));
      expect(seenBytes, hasLength(1));
      expect(seenBytes.first, Uint8List.fromList([1, 2, 3]));
      expect(summary.model, 'iPhone 15 Pro');
    });

    test('readBytes throws → empty summary (does not rethrow)', () async {
      final datasource = ExifDatasource(
        readBytes: (_) async => throw StateError('permission denied'),
        parseExif: (_) async => <String, IfdTag>{
          'Image Make': asciiTag('Canon'),
        },
      );

      final summary = await datasource.parse(_stubAsset());

      expect(summary, ExifSummary.empty);
    });
  });
}

/// 构建一个最小的 [AssetEntity] 用于 [ExifDatasource.parse] 测试。
///
/// AssetEntity 有公开构造函数（见 photo_manager_datasource_test.dart）；
/// 本测试不依赖任何字段（`readBytes` 已注入，不会触碰 asset 本身），
/// 但 photo_manager 的 AssetEntity 仍要求最少字段集才能通过编译。
AssetEntity _stubAsset() => AssetEntity(
      id: 'exif-test-asset',
      typeInt: AssetType.image.index,
      width: 0,
      height: 0,
      createDateSecond: null,
      relativePath: '',
    );
