import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/search/data/models/search_filter.dart';

void main() {
  group('SearchFilter', () {
    test('默认构造所有维度为空', () {
      const filter = SearchFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.query, isEmpty);
      expect(filter.tagIds, isEmpty);
      expect(filter.tagMatchMode, TagMatchMode.any);
      expect(filter.minStarRating, isNull);
      expect(filter.starRatingMode, StarRatingMatchMode.greaterOrEqual);
      expect(filter.dateFrom, isNull);
      expect(filter.dateTo, isNull);
      expect(filter.albumId, isNull);
      expect(filter.framedState, FramedState.all);
    });

    test('copyWith 保留未变更字段', () {
      final filter = SearchFilter(
        query: 'sunset',
        tagIds: ['tag1', 'tag2'],
        tagMatchMode: TagMatchMode.all,
        minStarRating: 3,
        starRatingMode: StarRatingMatchMode.exact,
        dateFrom: DateTime(2024, 1, 1),
        dateTo: DateTime(2024, 12, 31),
        albumId: 'album-1',
        framedState: FramedState.framed,
      );

      final modified = filter.copyWith(query: 'beach');
      expect(modified.query, 'beach');
      expect(modified.tagIds, ['tag1', 'tag2']);
      expect(modified.tagMatchMode, TagMatchMode.all);
      expect(modified.minStarRating, 3);
      expect(modified.dateFrom, DateTime(2024, 1, 1));
      expect(modified.albumId, 'album-1');
      expect(modified.framedState, FramedState.framed);
    });

    test('copyWith clearMinStarRating 清除星级', () {
      const filter = SearchFilter(minStarRating: 4);
      final modified = filter.copyWith(clearMinStarRating: true);
      expect(modified.minStarRating, isNull);
    });

    test('copyWith clearDateFrom 清除起始日期', () {
      final filter = SearchFilter(dateFrom: DateTime(2024, 6, 1));
      final modified = filter.copyWith(clearDateFrom: true);
      expect(modified.dateFrom, isNull);
    });

    test('copyWith clearDateTo 清除结束日期', () {
      final filter = SearchFilter(dateTo: DateTime(2024, 12, 31));
      final modified = filter.copyWith(clearDateTo: true);
      expect(modified.dateTo, isNull);
    });

    test('copyWith clearAlbumId 清除影集', () {
      const filter = SearchFilter(albumId: 'album-99');
      final modified = filter.copyWith(clearAlbumId: true);
      expect(modified.albumId, isNull);
    });

    test('isEmpty 正确识别非空 filter', () {
      expect(const SearchFilter(query: 'x').isEmpty, isFalse);
      expect(const SearchFilter(tagIds: ['t1']).isEmpty, isFalse);
      expect(const SearchFilter(minStarRating: 1).isEmpty, isFalse);
      // DateTime 没有 const 构造，不能用 const
      expect(SearchFilter(dateFrom: DateTime(2024, 1, 1)).isEmpty, isFalse);
      expect(const SearchFilter(albumId: 'a1').isEmpty, isFalse);
      expect(const SearchFilter(framedState: FramedState.framed).isEmpty, isFalse);
    });

    test('equality 相同字段值时相等', () {
      final f1 = SearchFilter(
        query: 'sunset',
        tagIds: ['t1', 't2'],
        tagMatchMode: TagMatchMode.all,
        minStarRating: 3,
        starRatingMode: StarRatingMatchMode.exact,
        dateFrom: DateTime(2024, 1, 1),
        dateTo: DateTime(2024, 12, 31),
        albumId: 'album-1',
        framedState: FramedState.framed,
      );
      final f2 = SearchFilter(
        query: 'sunset',
        tagIds: ['t1', 't2'],
        tagMatchMode: TagMatchMode.all,
        minStarRating: 3,
        starRatingMode: StarRatingMatchMode.exact,
        dateFrom: DateTime(2024, 1, 1),
        dateTo: DateTime(2024, 12, 31),
        albumId: 'album-1',
        framedState: FramedState.framed,
      );
      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
    });

    test('equality 不同字段值时不等', () {
      const f1 = SearchFilter(minStarRating: 3);
      const f2 = SearchFilter(minStarRating: 4);
      expect(f1, isNot(equals(f2)));
    });

    test('tagIds 顺序敏感', () {
      const f1 = SearchFilter(tagIds: ['t1', 't2']);
      const f2 = SearchFilter(tagIds: ['t2', 't1']);
      expect(f1, isNot(equals(f2)));
    });
  });

  group('TagMatchMode', () {
    test('any 和 all 两个枚举值', () {
      expect(TagMatchMode.values, containsAll([TagMatchMode.any, TagMatchMode.all]));
    });
  });

  group('StarRatingMatchMode', () {
    test('greaterOrEqual 和 exact 两个枚举值', () {
      expect(
        StarRatingMatchMode.values,
        containsAll([StarRatingMatchMode.greaterOrEqual, StarRatingMatchMode.exact]),
      );
    });
  });

  group('FramedState', () {
    test('all、framed、unframed 三个枚举值', () {
      expect(
        FramedState.values,
        containsAll([FramedState.all, FramedState.framed, FramedState.unframed]),
      );
    });
  });
}