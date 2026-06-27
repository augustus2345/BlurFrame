import '../../../photos/data/models/photo_model.dart';
import '../models/search_filter.dart';

/// Repository for searching/filtering photos across 5 dimensions.
///
/// Does NOT own persistence — filters in-memory [PhotoModel] list
/// produced by [PhotosNotifier].
class SearchRepository {
  /// 返回 [filter] 过滤后的照片子集。
  ///
  /// 过滤规则：
  /// - **标签**：`tagMatchMode.any` 时匹配任一标签；`all` 时匹配所有标签。
  /// - **星级**：`starRatingMode.greaterOrEqual` 时 ≥ minStarRating；
  ///   `exact` 时 = minStarRating。
  /// - **日期**：`dateFrom` / `dateTo` 闭区间。
  /// - **影集**：按 `albumId` 匹配（由调用方预先过滤影集内的照片列表）。
  /// - **模版状态**：`framed` 要求 `frameTemplateId != null`；
  ///   `unframed` 要求 `frameTemplateId == null`。
  ///
  /// [filter] 为空（[SearchFilter.isEmpty]）时返回所有照片。
  List<PhotoModel> matches(SearchFilter filter, List<PhotoModel> photos) {
    if (filter.isEmpty) return photos;

    return photos.where((photo) {
      // 标签过滤
      if (filter.tagIds.isNotEmpty) {
        final photoTagSet = photo.tags.toSet();
        final filterTagSet = filter.tagIds.toSet();
        final matched = filter.tagMatchMode == TagMatchMode.any
            ? filterTagSet.intersection(photoTagSet).isNotEmpty
            : filterTagSet.every((t) => photoTagSet.contains(t));
        if (!matched) return false;
      }

      // 星级过滤
      if (filter.minStarRating != null) {
        final rating = photo.starRating ?? 0;
        final matched = filter.starRatingMode == StarRatingMatchMode.greaterOrEqual
            ? rating >= filter.minStarRating!
            : rating == filter.minStarRating;
        if (!matched) return false;
      }

      // 日期过滤
      if (filter.dateFrom != null || filter.dateTo != null) {
        final taken = photo.takenAt;
        if (taken == null) return false;
        if (filter.dateFrom != null && taken.isBefore(filter.dateFrom!)) {
          return false;
        }
        if (filter.dateTo != null && taken.isAfter(filter.dateTo!)) {
          return false;
        }
      }

      // 模版状态过滤
      if (filter.framedState == FramedState.framed) {
        if (photo.frameTemplateId == null) return false;
      } else if (filter.framedState == FramedState.unframed) {
        if (photo.frameTemplateId != null) return false;
      }

      return true;
    }).toList();
  }
}