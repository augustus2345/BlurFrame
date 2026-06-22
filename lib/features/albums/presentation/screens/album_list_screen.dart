import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/empty_state.dart';

class AlbumListScreen extends ConsumerWidget {
  const AlbumListScreen({super.key});

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
              // TODO: open "select photos to create album" flow.
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