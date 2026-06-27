import 'package:flutter/material.dart';

import '../../data/models/tag_model.dart';

/// 标签列表单个 Chip 条目。
///
/// 左侧彩色圆点 + 标签名称 + 使用量（如果被引用）。
/// 点击跳转到详情页。
class TagListItem extends StatelessWidget {
  const TagListItem({
    required this.tag,
    required this.usageCount,
    this.onTap,
    super.key,
  });

  final TagModel tag;
  final int usageCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = Color(tag.colorValue);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: tagColor,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        tag.name,
        style: theme.textTheme.bodyLarge,
      ),
      trailing: usageCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$usageCount 张照片',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            )
          : null,
    );
  }
}