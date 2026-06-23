import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/empty_state.dart';

/// 影集列表屏 — 主题相册集合的入口。
///
/// 后续（M3）将承载：
/// - 2 列网格，每张影集显示封面（`coverAssetId` 套默认相框后的缩略图）+ 标题 + 照片数
/// - 长按影集 → 多选（删除 / 重命名）
/// - 右上角 "+" → 打开新建影集流程：选照片 + 输名称 + 选版式
/// - 点击进 `/albums/:id` 详情页
///
/// 当前为占位 `EmptyState`。
class AlbumListScreen extends ConsumerWidget {
  /// 路由 `/albums` 的目标 widget。由 `AppShell` 包裹。
  const AlbumListScreen({super.key});

  /// 后续需要的状态：
  /// - `AsyncValue<List<Album>>`（来自 `albumRepositoryProvider`）
  /// - 多选态：本地 `Set<String> selectedAlbumIds`
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('影集'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建影集',
            onPressed: () {
              // TODO(M3): navigate to /albums/new — multi-select photos +
              // name + layout picker.
            },
          ),
        ],
      ),
      body: const EmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: '还没有影集',
        message: '从相册里多选几张照片，组成一个好看的影集',
      ),
    );
  }
}