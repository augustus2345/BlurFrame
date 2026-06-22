import 'package:flutter/material.dart';

import '../../../../shared/widgets/empty_state.dart';

/// Top-level "all photos" grid. Swipe-up-to-delete gesture, multi-select
/// for batch frame application and album creation live here.
class PhotoGalleryScreen extends StatelessWidget {
  const PhotoGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相册'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '清理',
            onPressed: () {
              // TODO: navigate to cleanup screen
            },
          ),
        ],
      ),
      body: const EmptyState(
        icon: Icons.photo_library_outlined,
        title: '暂无照片',
        message: '授权后这里会展示你设备上的所有照片',
      ),
    );
  }
}