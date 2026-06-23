import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/empty_state.dart';

/// 相框模板列表屏 — 内置 + 用户自定义模板的管理入口。
///
/// 后续（M2）将承载：
/// - 内置模板（`isBuiltIn == true`，不可删可复制为自定义）：Classic White / Camera Watermark / Soft Edge
/// - 用户模板列表（可编辑 / 复制 / 删除）
/// - 右上角 "+" 跳 `/frames/editor` 创建空白模板
/// - 点击模板进 `/frames/:id` 编辑器（push 在 Shell 之外）
/// - 长按模板 → 复制为我的模板
///
/// 当前为占位 `EmptyState`。
class FrameTemplateListScreen extends ConsumerWidget {
  /// 路由 `/frames` 的目标 widget。由 `AppShell` 包裹。
  const FrameTemplateListScreen({super.key});

  /// 后续需要的状态：
  /// - `frameTemplateListProvider`（M2 已有占位实现，需改为 `AsyncValue` 暴露）
  /// - 复制 / 删除的二次确认
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