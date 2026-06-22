import 'package:flutter/material.dart';

import '../../../../shared/widgets/empty_state.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

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