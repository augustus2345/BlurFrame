/// 搜索 / 过滤条件模型（纯 Dart，不存 Hive）。
///
/// 设计原则：
/// 1. **自由组合** — 每个维度都是可选的，空字段意味着"不过滤此维度"。
/// 2. **单一数据源** — `SearchFilter` 由 `searchFilterProvider`（StateProvider）集中管理，
///    UI 修改 filter 时不直接改 `PhotoModel`，而是通过 `matches(photo)` 判断是否匹配。
/// 3. **值不可变** — 所有字段 `final`，修改走 `copyWith`，确保状态变更可追踪。
///
/// ## 5 维过滤
/// - **标签** (`tagIds`)：多选，支持 AND/OR 模式（见 [TagMatchMode]）。
/// - **星级** (`minStarRating` / `starRatingMode`)：支持 ≥N 星或 =N 星两种模式。
/// - **日期** (`dateFrom` / `dateTo`)：拍摄时间范围。
/// - **影集** (`albumId`)：单选，null 表示全部影集。
/// - **模版状态** (`framedState`)：all / framed / unframed。
class SearchFilter {
  const SearchFilter({
    this.query = '',
    this.tagIds = const <String>[],
    this.tagMatchMode = TagMatchMode.any,
    this.minStarRating,
    this.starRatingMode = StarRatingMatchMode.greaterOrEqual,
    this.dateFrom,
    this.dateTo,
    this.albumId,
    this.framedState = FramedState.all,
  });

  /// 关键词搜索（预留，当前仅 PhotoModel 已有字段支持）。
  final String query;

  /// 标签 ID 列表。
  final List<String> tagIds;

  /// 标签匹配模式。
  /// - [TagMatchMode.any]：匹配任一标签（OR）。
  /// - [TagMatchMode.all]：匹配所有标签（AND）。
  final TagMatchMode tagMatchMode;

  /// 最小星级（0–5）。null 表示不过滤。
  final int? minStarRating;

  /// 星级匹配模式。
  /// - [StarRatingMatchMode.greaterOrEqual]：≥ minStarRating。
  /// - [StarRatingMatchMode.exact]：= minStarRating。
  final StarRatingMatchMode starRatingMode;

  /// 拍摄时间范围起始（含）。
  final DateTime? dateFrom;

  /// 拍摄时间范围结束（含）。
  final DateTime? dateTo;

  /// 影集 ID。null 表示全部影集。
  final String? albumId;

  /// 模版状态过滤。
  final FramedState framedState;

  /// 返回 true 表示没有任何过滤条件。
  bool get isEmpty =>
      query.isEmpty &&
      tagIds.isEmpty &&
      minStarRating == null &&
      dateFrom == null &&
      dateTo == null &&
      albumId == null &&
      framedState == FramedState.all;

  SearchFilter copyWith({
    String? query,
    List<String>? tagIds,
    TagMatchMode? tagMatchMode,
    int? minStarRating,
    bool clearMinStarRating = false,
    StarRatingMatchMode? starRatingMode,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    String? albumId,
    bool clearAlbumId = false,
    FramedState? framedState,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      tagIds: tagIds ?? this.tagIds,
      tagMatchMode: tagMatchMode ?? this.tagMatchMode,
      minStarRating: clearMinStarRating ? null : (minStarRating ?? this.minStarRating),
      starRatingMode: starRatingMode ?? this.starRatingMode,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      albumId: clearAlbumId ? null : (albumId ?? this.albumId),
      framedState: framedState ?? this.framedState,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilter &&
        other.query == query &&
        _listEquals(other.tagIds, tagIds) &&
        other.tagMatchMode == tagMatchMode &&
        other.minStarRating == minStarRating &&
        other.starRatingMode == starRatingMode &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo &&
        other.albumId == albumId &&
        other.framedState == framedState;
  }

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAll(tagIds),
        tagMatchMode,
        minStarRating,
        starRatingMode,
        dateFrom,
        dateTo,
        albumId,
        framedState,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 标签匹配模式。
enum TagMatchMode {
  /// 匹配任一标签（OR）。
  any,

  /// 匹配所有标签（AND）。
  all,
}

/// 星级匹配模式。
enum StarRatingMatchMode {
  /// ≥ 最小星级。
  greaterOrEqual,

  /// = 精确星级。
  exact,
}

/// 模版状态。
enum FramedState {
  /// 全部照片。
  all,

  /// 已套模版。
  framed,

  /// 未套模版。
  unframed,
}