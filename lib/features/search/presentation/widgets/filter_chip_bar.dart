import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../albums/data/models/album_model.dart';
import '../../../albums/presentation/providers/album_list_provider.dart';
import '../../../tags/data/models/tag_model.dart';
import '../../../tags/presentation/providers/tag_list_provider.dart';
import '../../data/models/search_filter.dart';
import 'date_range_picker_sheet.dart';
import 'star_rating_filter_sheet.dart';

/// 过滤条件 chip 行.
///
/// 展示当前已激活的过滤条件 chip，点击后弹出对应选择 sheet.
/// 包含：标签 / 星级 / 日期 / 影集 / 模版状态 5 个维度.
class FilterChipBar extends ConsumerWidget {
  const FilterChipBar({
    required this.filter,
    required this.onFilterChanged,
    super.key,
  });

  final SearchFilter filter;
  final void Function(SearchFilter newFilter) onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasActiveFilters = !filter.isEmpty;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                // 标签 chip
                _FilterChip(
                  label: _tagsLabel(filter),
                  isActive: filter.tagIds.isNotEmpty,
                  onTap: () => _showTagSheet(context, ref, filter, onFilterChanged),
                ),

                // 星级 chip
                _FilterChip(
                  label: _starLabel(filter),
                  isActive: filter.minStarRating != null,
                  onTap: () => _showStarSheet(context, filter, onFilterChanged),
                ),

                // 日期 chip
                _FilterChip(
                  label: _dateLabel(filter),
                  isActive: filter.dateFrom != null || filter.dateTo != null,
                  onTap: () => _showDateSheet(context, filter, onFilterChanged),
                ),

                // 影集 chip
                _FilterChip(
                  label: filter.albumId != null ? '已选影集' : '影集',
                  isActive: filter.albumId != null,
                  onTap: () => _showAlbumSheet(context, filter, onFilterChanged),
                ),

                // 模版状态 chip
                _FilterChip(
                  label: _framedLabel(filter),
                  isActive: filter.framedState != FramedState.all,
                  onTap: () => _showFramedSheet(context, filter, onFilterChanged),
                ),
              ],
            ),
          ),

          // 清除全部
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: '清除全部过滤',
              onPressed: () => onFilterChanged(const SearchFilter()),
            ),
        ],
      ),
    );
  }

  String _tagsLabel(SearchFilter filter) {
    if (filter.tagIds.isEmpty) return '标签';
    final mode = filter.tagMatchMode == TagMatchMode.any ? '任一' : '全部';
    return '标签($mode)';
  }

  String _starLabel(SearchFilter filter) {
    if (filter.minStarRating == null) return '星级';
    final op = filter.starRatingMode == StarRatingMatchMode.greaterOrEqual ? '≥' : '=';
    return '星级($op${filter.minStarRating})';
  }

  String _dateLabel(SearchFilter filter) {
    if (filter.dateFrom == null && filter.dateTo == null) return '日期';
    if (filter.dateFrom != null && filter.dateTo != null) {
      return '${_fmt(filter.dateFrom!)}~${_fmt(filter.dateTo!)}';
    }
    if (filter.dateFrom != null) return '从${_fmt(filter.dateFrom!)}';
    return '至${_fmt(filter.dateTo!)}';
  }

  String _framedLabel(SearchFilter filter) {
    switch (filter.framedState) {
      case FramedState.all:
        return '模版';
      case FramedState.framed:
        return '已套模版';
      case FramedState.unframed:
        return '未套模版';
    }
  }

  String _fmt(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }

  Future<void> _showTagSheet(
    BuildContext context,
    WidgetRef ref,
    SearchFilter filter,
    void Function(SearchFilter) onChanged,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TagFilterSheet(
        selectedTagIds: filter.tagIds,
        matchMode: filter.tagMatchMode,
        onConfirm: (tagIds, mode) {
          onChanged(filter.copyWith(tagIds: tagIds, tagMatchMode: mode));
        },
      ),
    );
  }

  Future<void> _showStarSheet(
    BuildContext context,
    SearchFilter filter,
    void Function(SearchFilter) onChanged,
  ) async {
    await showStarRatingFilterSheet(
      context: context,
      initialMinStarRating: filter.minStarRating,
      initialMode: filter.starRatingMode,
      onConfirm: (minStar, mode) {
        if (minStar == null) {
          onChanged(filter.copyWith(clearMinStarRating: true));
        } else {
          onChanged(filter.copyWith(minStarRating: minStar, starRatingMode: mode));
        }
      },
    );
  }

  Future<void> _showDateSheet(
    BuildContext context,
    SearchFilter filter,
    void Function(SearchFilter) onChanged,
  ) async {
    await showDateRangeFilterSheet(
      context: context,
      initialFrom: filter.dateFrom,
      initialTo: filter.dateTo,
      onConfirm: (from, to) {
        onChanged(filter.copyWith(
          dateFrom: from,
          clearDateFrom: from == null,
          dateTo: to,
          clearDateTo: to == null,
        ));
      },
    );
  }

  Future<void> _showAlbumSheet(
    BuildContext context,
    SearchFilter filter,
    void Function(SearchFilter) onChanged,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _AlbumFilterSheet(
        selectedAlbumId: filter.albumId,
        onConfirm: (albumId) {
          onChanged(albumId == null
              ? filter.copyWith(clearAlbumId: true)
              : filter.copyWith(albumId: albumId));
        },
      ),
    );
  }

  Future<void> _showFramedSheet(
    BuildContext context,
    SearchFilter filter,
    void Function(SearchFilter) onChanged,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _FramedFilterSheet(
        selectedState: filter.framedState,
        onConfirm: (state) => onChanged(filter.copyWith(framedState: state)),
      ),
    );
  }
}

/// 单个过滤 chip.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => onTap(),
        selectedColor: theme.colorScheme.primaryContainer,
        checkmarkColor: theme.colorScheme.onPrimaryContainer,
        side: BorderSide(
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
      ),
    );
  }
}

/// 标签过滤 Sheet（内置于 FilterChipBar 文件避免小部件拆分过多）.
class _TagFilterSheet extends ConsumerStatefulWidget {
  const _TagFilterSheet({
    required this.selectedTagIds,
    required this.matchMode,
    required this.onConfirm,
  });

  final List<String> selectedTagIds;
  final TagMatchMode matchMode;
  final void Function(List<String> tagIds, TagMatchMode mode) onConfirm;

  @override
  ConsumerState<_TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends ConsumerState<_TagFilterSheet> {
  late List<String> _selectedTagIds;
  late TagMatchMode _matchMode;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = List.from(widget.selectedTagIds);
    _matchMode = widget.matchMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tagListProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncTags = ref.watch(tagListProvider);
    final allTags = asyncTags.valueOrNull ?? <TagModel>[];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('标签过滤', style: theme.textTheme.titleLarge),
                TextButton(
                  onPressed: () {
                    widget.onConfirm(_selectedTagIds, _matchMode);
                    Navigator.of(context).pop();
                  },
                  child: const Text('完成'),
                ),
              ],
            ),
          ),

          // 匹配模式
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TagMatchMode>(
              segments: const [
                ButtonSegment(value: TagMatchMode.any, label: Text('任一匹配(OR)')),
                ButtonSegment(value: TagMatchMode.all, label: Text('全部匹配(AND)')),
              ],
              selected: {_matchMode},
              onSelectionChanged: (val) {
                setState(() => _matchMode = val.first);
              },
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: asyncTags.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text('加载失败', style: TextStyle(color: theme.colorScheme.error))),
              data: (_) {
                if (allTags.isEmpty) {
                  return Center(
                    child: Text('暂无标签', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  );
                }
                return ListView.builder(
                  itemCount: allTags.length,
                  itemBuilder: (context, index) {
                    final tag = allTags[index];
                    final isSelected = _selectedTagIds.contains(tag.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedTagIds.add(tag.id);
                          } else {
                            _selectedTagIds.remove(tag.id);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Color(tag.colorValue),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(tag.name),
                        ],
                      ),
                      activeColor: theme.colorScheme.primary,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 影集过滤 Sheet.
class _AlbumFilterSheet extends ConsumerWidget {
  const _AlbumFilterSheet({
    required this.selectedAlbumId,
    required this.onConfirm,
  });

  final String? selectedAlbumId;
  final void Function(String? albumId) onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncAlbums = ref.watch(albumListProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('全部影集'),
            trailing: selectedAlbumId == null
                ? Icon(Icons.check, color: theme.colorScheme.primary)
                : null,
            onTap: () {
              onConfirm(null);
              Navigator.of(context).pop();
            },
          ),
          asyncAlbums.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('加载失败', style: TextStyle(color: theme.colorScheme.error)),
            ),
            data: (albums) {
              if (albums.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('暂无影集', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: albums.map((album) {
                  final isSelected = selectedAlbumId == album.id;
                  return ListTile(
                    title: Text(album.name),
                    subtitle: Text('${album.photoIds.length} 张照片'),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      onConfirm(album.id);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// 模版状态过滤 Sheet.
class _FramedFilterSheet extends StatelessWidget {
  const _FramedFilterSheet({
    required this.selectedState,
    required this.onConfirm,
  });

  final FramedState selectedState;
  final void Function(FramedState state) onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          ...FramedState.values.map((state) {
            final isSelected = selectedState == state;
            return ListTile(
              title: Text(_stateLabel(state)),
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                onConfirm(state);
                Navigator.of(context).pop();
              },
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  String _stateLabel(FramedState state) {
    switch (state) {
      case FramedState.all:
        return '全部';
      case FramedState.framed:
        return '已套模版';
      case FramedState.unframed:
        return '未套模版';
    }
  }
}