/// Filter criteria for the search screen. Combine freely — empty fields
/// mean "don't filter on this dimension".
class SearchFilter {
  const SearchFilter({
    this.query = '',
    this.tagIds = const <String>[],
    this.dateFrom,
    this.dateTo,
    this.camera,
  });

  final String query;
  final List<String> tagIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? camera;

  SearchFilter copyWith({
    String? query,
    List<String>? tagIds,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? camera,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      tagIds: tagIds ?? this.tagIds,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      camera: camera ?? this.camera,
    );
  }

  bool get isEmpty =>
      query.isEmpty &&
      tagIds.isEmpty &&
      dateFrom == null &&
      dateTo == null &&
      (camera == null || camera!.isEmpty);
}