import 'package:flutter/material.dart';

/// 照片星级评分组件 — 5 颗可点星标，评 0–5 星。
///
/// 设计要点：
/// - **未评（0 星）**：全部显示空心星星
/// - **已评（N 星）**：前 N 颗显示填充星星，后 5-N 颗空心
/// - **点击交互**：点击第 N 颗 → 设置为 N 星（再次点击同一颗可取消评星）
/// - **布局风格**：与 [TagPills] 保持一致（标题行 + 内容行）
class StarRating extends StatelessWidget {
  const StarRating({
    required this.starRating,
    required this.onChanged,
    super.key,
  });

  /// 当前星级（0–5）。
  final int starRating;

  /// 星级变化回调（传入新的星级值 0–5）。
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = starRating.clamp(0, 5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '星级',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1; // 1-based
              final isFilled = starIndex <= rating;

              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  key: ValueKey('star_$starIndex'),
                  onTap: () => onChanged(starIndex),
                  child: Icon(
                    isFilled ? Icons.star : Icons.star_border,
                    size: 28,
                    color: isFilled
                        ? Colors.amber
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
