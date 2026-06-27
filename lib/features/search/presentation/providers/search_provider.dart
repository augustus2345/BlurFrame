import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../photos/data/models/photo_model.dart';
import '../../data/models/search_filter.dart';
import '../../data/repositories/search_repository.dart';
import '../../../photos/presentation/providers/photos_provider.dart';

/// SearchRepository provider.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository();
});

/// 当前搜索过滤器状态。
final searchFilterProvider = StateProvider<SearchFilter>((ref) {
  return const SearchFilter();
});

/// 搜索结果（派生自 filter + photos）。
final searchResultsProvider = Provider<AsyncValue<List<PhotoModel>>>((ref) {
  final filter = ref.watch(searchFilterProvider);
  final asyncPhotos = ref.watch(photosProvider);
  final searchRepo = ref.read(searchRepositoryProvider);

  return asyncPhotos.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (photos) {
      final filtered = searchRepo.matches(filter, photos);
      return AsyncValue.data(filtered);
    },
  );
});