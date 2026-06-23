import 'package:flutter/material.dart';

import '../../../../shared/widgets/empty_state.dart';

/// 搜索 / 过滤屏 — 多维度定位照片。
///
/// 后续（M4）将承载：
/// - 顶部过滤条件 chip 行：标签（多选 + AND/OR）/ 日期（预设 + 自定义）/ 影集 / 相框状态
/// - 点 chip 弹底部 sheet 选择
/// - 下方结果网格（同 `PhotoGalleryScreen` 网格组件，多选 → 批量打标签 / 删除）
/// - 4 维过滤由 `SearchFilter` model 承载，结果由 `searchRepository.matches(filter)` 返回
///
/// 当前为占位 `EmptyState`。
class SearchScreen extends StatelessWidget {
  /// 路由 `/search` 的目标 widget。由 `AppShell` 包裹。
  const SearchScreen({super.key});

  /// 后续需要的状态：
  /// - `searchFilterProvider`（`StateProvider<SearchFilter>`）
  /// - `searchResultsProvider`（按 filter 派生 `AsyncValue<List<AssetEntity>>`）
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
      ),
      body: const EmptyState(
        icon: Icons.search_outlined,
        title: '按标签、日期、相机参数搜索',
        message: '支持 Lightroom 风格的标签筛选与 EXIF 元数据过滤',
      ),
    );
  }
}