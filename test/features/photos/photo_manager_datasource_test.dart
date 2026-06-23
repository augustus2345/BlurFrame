import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/datasources/photo_manager_datasource.dart';
import 'package:photo_manager/photo_manager.dart';

/// Tests for [PhotoManagerDatasource] — the boundary between the system
/// gallery (`photo_manager`) and our domain ([SystemPhoto] / [PhotoModel]).
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - `fetchAll()` delegates to the injected function (no platform-channel
///   fallback in tests).
/// - [PhotoManagerDatasource.mapAsset] extracts every field correctly.
/// - `width` / `height` of `0` (the EXIF-parse-failed sentinel) are normalized
///   to `null` — the business layer should not see `0` as a real dimension.
/// - `createDateSecond == null` is normalized to `takenAt == null` (otherwise
///   the upstream `AssetEntity.createDateTime` returns 1970 epoch).
void main() {
  group('PhotoManagerDatasource.fetchAll', () {
    test('delegates to the injected function', () async {
      var callCount = 0;
      final datasource = PhotoManagerDatasource(
        fetchAll: () async {
          callCount++;
          return const <SystemPhoto>[
            SystemPhoto(id: 'a'),
          ];
        },
      );

      final result = await datasource.fetchAll();

      expect(callCount, 1);
      expect(result, hasLength(1));
      expect(result.first.id, 'a');
    });

    test('returns empty list when the injected function returns empty',
        () async {
      final datasource = PhotoManagerDatasource(
        fetchAll: () async => const <SystemPhoto>[],
      );

      expect(await datasource.fetchAll(), isEmpty);
    });
  });

  group('PhotoManagerDatasource.mapAsset', () {
    test('extracts all fields when present', () {
      final asset = AssetEntity(
        id: 'asset-1',
        typeInt: AssetType.image.index,
        width: 4032,
        height: 3024,
        createDateSecond: 1718943600,
        relativePath: 'DCIM/IMG_0001.jpg',
      );

      final sys = PhotoManagerDatasource.mapAsset(asset);

      expect(sys.id, 'asset-1');
      expect(sys.path, 'DCIM/IMG_0001.jpg');
      expect(sys.width, 4032);
      expect(sys.height, 3024);
      expect(sys.takenAt, DateTime.fromMillisecondsSinceEpoch(1718943600 * 1000));
    });

    test('normalizes width=0 to null (EXIF parse failure sentinel)', () {
      final asset = AssetEntity(
        id: 'a',
        typeInt: AssetType.image.index,
        width: 0,
        height: 0,
      );

      final sys = PhotoManagerDatasource.mapAsset(asset);

      expect(sys.width, isNull);
      expect(sys.height, isNull);
    });

    test('normalizes null createDateSecond to null takenAt (not 1970 epoch)',
        () {
      final asset = AssetEntity(
        id: 'a',
        typeInt: AssetType.image.index,
        width: 100,
        height: 200,
        // createDateSecond 留空
      );

      final sys = PhotoManagerDatasource.mapAsset(asset);

      expect(sys.takenAt, isNull);
    });

    test('preserves null relativePath (some platforms / some assets)', () {
      final asset = AssetEntity(
        id: 'a',
        typeInt: AssetType.image.index,
        width: 100,
        height: 200,
        // relativePath 留空
      );

      final sys = PhotoManagerDatasource.mapAsset(asset);

      expect(sys.path, isNull);
    });
  });
}
