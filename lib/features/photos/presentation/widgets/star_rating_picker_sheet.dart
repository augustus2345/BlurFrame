import 'package:flutter/material.dart';

/// 批量星级选择底部弹窗.
///
/// 展示 0–5 星选项，用户选择一个后即应用.
Future<void> showBatchStarRatingSheet({
  required BuildContext context,
  required void Function(int starRating) onConfirm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => _BatchStarRatingSheet(onConfirm: onConfirm),
  );
}

/// 批量星级选择 Sheet.
class _BatchStarRatingSheet extends StatelessWidget {
  const _BatchStarRatingSheet({required this.onConfirm});

  final void Function(int starRating) onConfirm;

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
                  Text('批量设置星级', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '将为所有选中照片设置相同星级',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 星级按钮行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int i = 0; i <= 5; i++)
                        _StarButton(
                          rating: i,
                          onTap: () {
                            onConfirm(i);
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 取消按钮
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
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

/// 单个星级按钮.
class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.rating,
    required this.onTap,
  });

  final int rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = rating == 0
        ? theme.colorScheme.outline
        : Colors.amber;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rating == 0 ? Icons.star_outline : Icons.star,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              rating == 0 ? '清除' : '$rating 星',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
