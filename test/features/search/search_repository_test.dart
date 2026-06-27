import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/search/data/models/search_filter.dart';
import 'package:photo_beauty/features/search/data/repositories/search_repository.dart';

void main() {
  late SearchRepository repo;
  late List<PhotoModel> photos;

  setUp(() {
    repo = SearchRepository();
    photos = [
      _makePhoto(id: 'p1', tags: ['t1'], starRating: 3, takenAt: DateTime(2024, 3, 15), frameTemplateId: 'f1'),
      _makePhoto(id: 'p2', tags: ['t1', 't2'], starRating: 5, takenAt: DateTime(2024, 5, 20), frameTemplateId: null),
      _makePhoto(id: 'p3', tags: ['t2'], starRating: 1, takenAt: DateTime(2024, 1, 1), frameTemplateId: 'f2'),
      _makePhoto(id: 'p4', tags: ['t3'], starRating: 0, takenAt: DateTime(2023, 12, 31), frameTemplateId: null),
      _makePhoto(id: 'p5', tags: ['t1', 't3'], starRating: 4, takenAt: DateTime(2024, 7, 1), frameTemplateId: 'f1'),
    ];
  });

  group('SearchRepository.matches', () {
    test('空 filter 返回所有照片', () {
      final result = repo.matches(const SearchFilter(), photos);
      expect(result.length, 5);
    });

    test('标签 OR 匹配 — 任一标签', () {
      final result = repo.matches(
        const SearchFilter(tagIds: ['t1'], tagMatchMode: TagMatchMode.any),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p1', 'p2', 'p5'});
    });

    test('标签 AND 匹配 — 全部标签', () {
      final result = repo.matches(
        const SearchFilter(tagIds: ['t1', 't3'], tagMatchMode: TagMatchMode.all),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p5'});
    });

    test('星级 >= 匹配', () {
      final result = repo.matches(
        const SearchFilter(
          minStarRating: 4,
          starRatingMode: StarRatingMatchMode.greaterOrEqual,
        ),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p2', 'p5'});
    });

    test('星级 = 精确匹配', () {
      final result = repo.matches(
        const SearchFilter(
          minStarRating: 3,
          starRatingMode: StarRatingMatchMode.exact,
        ),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p1'});
    });

    test('日期范围过滤', () {
      final result = repo.matches(
        SearchFilter(
          dateFrom: DateTime(2024, 3, 1),
          dateTo: DateTime(2024, 6, 30),
        ),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p1', 'p2'});
    });

    test('日期 from only', () {
      final result = repo.matches(
        SearchFilter(dateFrom: DateTime(2024, 6, 1)),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p5'});
    });

    test('日期 to only', () {
      final result = repo.matches(
        SearchFilter(dateTo: DateTime(2024, 1, 31)),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p3', 'p4'});
    });

    test('framed 过滤 — 已套模版', () {
      final result = repo.matches(
        const SearchFilter(framedState: FramedState.framed),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p1', 'p3', 'p5'});
    });

    test('framed 过滤 — 未套模版', () {
      final result = repo.matches(
        const SearchFilter(framedState: FramedState.unframed),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p2', 'p4'});
    });

    test('多维度交叉过滤', () {
      final result = repo.matches(
        const SearchFilter(
          tagIds: ['t1'],
          tagMatchMode: TagMatchMode.any,
          minStarRating: 3,
          starRatingMode: StarRatingMatchMode.greaterOrEqual,
        ),
        photos,
      );
      expect(result.map((p) => p.id).toSet(), {'p1', 'p2', 'p5'});
    });

    test('4 维交叉过滤 — 标签+星级+日期+模版状态', () {
      // 标签:t1 + 星级≥3 + 日期2024年 + 已套模版
      final result = repo.matches(
        SearchFilter(
          tagIds: const ['t1'],
          tagMatchMode: TagMatchMode.any,
          minStarRating: 3,
          starRatingMode: StarRatingMatchMode.greaterOrEqual,
          dateFrom: DateTime(2024, 1, 1),
          dateTo: DateTime(2024, 12, 31),
          framedState: FramedState.framed,
        ),
        photos,
      );
      // p1: t1, star=3, date=2024-03-15, framed=f1 ✓
      // p2: t1, star=5, date=2024-05-20, framed=null ✗
      // p5: t1, star=4, date=2024-07-01, framed=f1 ✓
      expect(result.map((p) => p.id).toSet(), {'p1', 'p5'});
    });

    test('4 维交叉过滤 — 无匹配结果', () {
      // 标签:t2 + 星级≥4 + 已套模版（但t2的p3只有1星且日期2024-01-01）
      final result = repo.matches(
        const SearchFilter(
          tagIds: ['t2'],
          tagMatchMode: TagMatchMode.any,
          minStarRating: 4,
          starRatingMode: StarRatingMatchMode.greaterOrEqual,
          framedState: FramedState.framed,
        ),
        photos,
      );
      // p2: t2, star=5, framed=null ✗
      // p3: t2, star=1, framed=f2 ✗
      expect(result.length, 0);
    });

    test('无结果返回空列表', () {
      final result = repo.matches(
        const SearchFilter(minStarRating: 5, starRatingMode: StarRatingMatchMode.exact),
        photos,
      );
      expect(result.length, 1);
      expect(result.first.id, 'p2');
    });
  });
}

PhotoModel _makePhoto({
  required String id,
  required List<String> tags,
  required int starRating,
  required DateTime takenAt,
  String? frameTemplateId,
}) {
  return PhotoModel(
    id: id,
    path: '/test/$id.jpg',
    width: 100,
    height: 100,
    takenAt: takenAt,
    tags: tags,
    frameTemplateId: frameTemplateId,
    starRating: starRating,
  );
}