import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/photos/data/datasources/photo_manager_datasource.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/data/repositories/photo_repository.dart';

/// Tests for [PhotoRepository.loadAllFromSystem] — the merge between
/// system photos (`PhotoManagerDatasource`) and local Hive state.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - Empty system → empty result, no Hive writes.
/// - System photo not in Hive → saved with default `tags = []` and
///   `frameTemplateId = null`.
/// - System photo matches Hive entry → `tags` and `frameTemplateId` from Hive
///   are preserved; system overrides `path` / `width` / `height` /
///   `takenAt` (system is source of truth for these).
/// - System `path` / `width` / `height` / `takenAt` being `null` falls back
///   to existing Hive values (so user-edited data isn't overwritten by
///   degraded system metadata).
/// - System `path` being `null` with no existing Hive entry → empty string
///   (the `PhotoModel.path` field is non-nullable; empty string is the
///   "unknown" sentinel the UI can detect).
class _MockBox extends Mock implements Box<dynamic> {}

class _MockDatasource extends Mock implements PhotoManagerDatasource {}

void main() {
  late _MockBox box;
  late _MockDatasource datasource;
  late PhotoRepository repo;

  final takenAt = DateTime.fromMillisecondsSinceEpoch(1718943600 * 1000);
  final oldTakenAt = DateTime.fromMillisecondsSinceEpoch(1600000000 * 1000);

  setUp(() {
    box = _MockBox();
    datasource = _MockDatasource();
    repo = PhotoRepository.fromBox(box, datasource: datasource);

    // put 总是成功
    when(() => box.put(any<dynamic>(), any<dynamic>()))
        .thenAnswer((_) async {});
  });

  Future<List<PhotoModel>> runLoad(List<SystemPhoto> system) {
    when(() => datasource.fetchAll()).thenAnswer((_) async => system);
    return repo.loadAllFromSystem();
  }

  group('PhotoRepository.loadAllFromSystem — empty cases', () {
    test('empty system + empty Hive → empty result, no saves', () async {
      when(() => box.values).thenReturn(<dynamic>[]);

      final result = await runLoad(const <SystemPhoto>[]);

      expect(result, isEmpty);
      verifyNever(() => box.put(any<dynamic>(), any<dynamic>()));
    });
  });

  group('PhotoRepository.loadAllFromSystem — new photos', () {
    test('system photo not in Hive → saved with default user fields',
        () async {
      when(() => box.get('a')).thenReturn(null);

      final result = await runLoad(<SystemPhoto>[
        SystemPhoto(
          id: 'a',
          path: '/DCIM/IMG_0001.jpg',
          width: 4032,
          height: 3024,
          takenAt: takenAt,
        ),
      ]);

      expect(result, hasLength(1));
      final saved = result.first;
      expect(saved.id, 'a');
      expect(saved.path, '/DCIM/IMG_0001.jpg');
      expect(saved.width, 4032);
      expect(saved.height, 3024);
      expect(saved.takenAt, takenAt);
      // 新建：user 字段是默认值
      expect(saved.tags, isEmpty);
      expect(saved.frameTemplateId, isNull);
      // 持久化
      verify(() => box.put('a', saved)).called(1);
    });
  });

  group('PhotoRepository.loadAllFromSystem — merge with existing Hive', () {
    test('preserves tags and frameTemplateId; system overrides path/width/height/takenAt',
        () async {
      // 旧 Hive 记录：width/height 0（旧系统扫到的占位），takenAt 是老值，
      // 用户已加 2 个 tag + 套了 classic-white 模板
      final existing = PhotoModel(
        id: 'a',
        path: '/old',
        width: 0,
        height: 0,
        takenAt: oldTakenAt,
        tags: const <String>['travel', 'beach'],
        frameTemplateId: 'classic-white',
      );
      when(() => box.get('a')).thenReturn(existing);

      final result = await runLoad(<SystemPhoto>[
        SystemPhoto(
          id: 'a',
          path: '/DCIM/IMG_0001.jpg',
          width: 4032,
          height: 3024,
          takenAt: takenAt,
        ),
      ]);

      expect(result, hasLength(1));
      final merged = result.first;
      // 系统覆盖：
      expect(merged.path, '/DCIM/IMG_0001.jpg');
      expect(merged.width, 4032);
      expect(merged.height, 3024);
      expect(merged.takenAt, takenAt);
      // Hive 保留：
      expect(merged.tags, <String>['travel', 'beach']);
      expect(merged.frameTemplateId, 'classic-white');
      verify(() => box.put('a', merged)).called(1);
    });

    test('mixed: one existing + one new in same scan', () async {
      const existing = PhotoModel(
        id: 'a',
        path: '/old-a',
        tags: <String>['keep'],
        frameTemplateId: 'soft-edge',
      );
      when(() => box.get('a')).thenReturn(existing);
      when(() => box.get('b')).thenReturn(null);

      final result = await runLoad(<SystemPhoto>[
        const SystemPhoto(id: 'a', path: '/new-a', width: 100, height: 200),
        const SystemPhoto(id: 'b', path: '/new-b', width: 300, height: 400),
      ]);

      expect(result, hasLength(2));
      final a = result.firstWhere((p) => p.id == 'a');
      final b = result.firstWhere((p) => p.id == 'b');
      // a：合并
      expect(a.path, '/new-a');
      expect(a.width, 100);
      expect(a.tags, <String>['keep']);
      expect(a.frameTemplateId, 'soft-edge');
      // b：新建
      expect(b.path, '/new-b');
      expect(b.width, 300);
      expect(b.tags, isEmpty);
      expect(b.frameTemplateId, isNull);
      verify(() => box.put('a', a)).called(1);
      verify(() => box.put('b', b)).called(1);
    });
  });

  group('PhotoRepository.loadAllFromSystem — degraded system metadata', () {
    test('null system path + existing in Hive → uses Hive path', () async {
      const existing = PhotoModel(id: 'a', path: '/old');
      when(() => box.get('a')).thenReturn(existing);

      final result = await runLoad(<SystemPhoto>[
        const SystemPhoto(id: 'a', path: null, width: 100, height: 200),
      ]);

      expect(result.first.path, '/old');
    });

    test('null system path + no existing → empty string sentinel', () async {
      when(() => box.get('a')).thenReturn(null);

      final result = await runLoad(<SystemPhoto>[
        const SystemPhoto(id: 'a', path: null, width: 100, height: 200),
      ]);

      // PhotoModel.path 是非空 String；null 路径 + 无历史 = ''
      expect(result.first.path, '');
    });

    test('null system takenAt + existing takenAt → uses Hive value',
        () async {
      final existing = PhotoModel(
        id: 'a',
        path: '/old',
        takenAt: oldTakenAt,
      );
      when(() => box.get('a')).thenReturn(existing);

      final result = await runLoad(<SystemPhoto>[
        const SystemPhoto(id: 'a', path: '/new', takenAt: null),
      ]);

      expect(result.first.takenAt, oldTakenAt);
    });

    test('null system width/height + existing width/height → uses Hive values',
        () async {
      const existing = PhotoModel(
        id: 'a',
        path: '/old',
        width: 800,
        height: 600,
      );
      when(() => box.get('a')).thenReturn(existing);

      final result = await runLoad(<SystemPhoto>[
        const SystemPhoto(id: 'a', path: '/new', width: null, height: null),
      ]);

      expect(result.first.width, 800);
      expect(result.first.height, 600);
    });
  });
}
