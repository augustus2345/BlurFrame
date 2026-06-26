import 'package:flutter/material.dart';

import '../../data/models/photo_model.dart';

/// 照片标签展示组件 — 以 Chip pills 形式展示标签。
///
/// 设计要点：
/// - **tags 为空时显示"暂无标签"**：灰色 placeholder chip
/// - **单个 Chip 样式**：浅色背景 + 圆角 + 标签名
/// - **可滚动行**：超过一行时横向滚动
///
/// M4 接入后重构：
/// - TagRepository 根据 tagId 查 TagModel.name 替代直接显示 id
class TagPills extends StatelessWidget {
  const TagPills({required this.photo, super.key});

  final PhotoModel photo;

  @override
  Widget build(BuildContext context) {
    final tags = photo.tags;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '标签',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tags.isEmpty)
            Text(
              '暂无标签',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tags.map((tag) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        tag,
                        style: const TextStyle(fontSize: 12),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}