import 'package:flutter/material.dart';

import '../../data/models/search_filter.dart';

/// 星级过滤底部弹窗.
///
/// [initialMinStarRating] — 当前已选最小星级（null 表示未选）.
/// [initialMode] — 当前匹配模式.
/// [onConfirm] — 确认回调.
Future<void> showStarRatingFilterSheet({
  required BuildContext context,
  required int? initialMinStarRating,
  required StarRatingMatchMode initialMode,
  required void Function(int? minStarRating, StarRatingMatchMode mode) onConfirm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => StarRatingFilterSheet(
      initialMinStarRating: initialMinStarRating,
      initialMode: initialMode,
      onConfirm: onConfirm,
    ),
  );
}

/// 星级过滤 Sheet.
class StarRatingFilterSheet extends StatefulWidget {
  const StarRatingFilterSheet({
    required this.initialMinStarRating,
    required this.initialMode,
    required this.onConfirm,
    super.key,
  });

  final int? initialMinStarRating;
  final StarRatingMatchMode initialMode;
  final void Function(int? minStarRating, StarRatingMatchMode mode) onConfirm;

  @override
  State<StarRatingFilterSheet> createState() => _StarRatingFilterSheetState();
}

class _StarRatingFilterSheetState extends State<StarRatingFilterSheet> {
  late int? _selectedRating;
  late StarRatingMatchMode _mode;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialMinStarRating;
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('星级', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),

                  // 匹配模式
                  Text('匹配方式', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<StarRatingMatchMode>(
                    segments: const [
                      ButtonSegment(
                        value: StarRatingMatchMode.greaterOrEqual,
                        label: Text('≥N 星'),
                      ),
                      ButtonSegment(
                        value: StarRatingMatchMode.exact,
                        label: Text('=N 星'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (val) {
                      setState(() => _mode = val.first);
                    },
                  ),

                  const SizedBox(height: 16),

                  // 星级选择
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i <= 5; i++) ...[
                        _StarButton(
                          rating: i,
                          isSelected: _selectedRating == i,
                          onTap: () {
                            setState(() {
                              // 点击同一颗星取消选择
                              _selectedRating = (_selectedRating == i) ? null : i;
                            });
                          },
                        ),
                        if (i < 5) const SizedBox(width: 4),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            widget.onConfirm(_selectedRating, _mode);
                            Navigator.of(context).pop();
                          },
                          child: const Text('确认'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.rating,
    required this.isSelected,
    required this.onTap,
  });

  final int rating;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = rating == 0
        ? theme.colorScheme.outline
        : Colors.amber;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: rating == 0
              ? Icon(Icons.close, size: 20, color: theme.colorScheme.outline)
              : Text(
                  '$rating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }
}