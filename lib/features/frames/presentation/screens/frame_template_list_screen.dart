import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/empty_state.dart';

class FrameTemplateListScreen extends ConsumerWidget {
  const FrameTemplateListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相框'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建模板',
            onPressed: () => context.push(AppRoute.frameEditor),
          ),
        ],
      ),
      body: const EmptyState(
        icon: Icons.crop_square_outlined,
        title: '还没有相框模板',
        message: '添加一个模板：EXIF 水印、边缘模糊、边框等',
      ),
    );
  }
}