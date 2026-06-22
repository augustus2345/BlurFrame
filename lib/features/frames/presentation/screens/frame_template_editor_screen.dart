import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_scaffold.dart';

class FrameTemplateEditorScreen extends StatelessWidget {
  const FrameTemplateEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: '编辑相框模板',
      child: Center(
        child: Text('Frame editor — drag to compose border / watermark / EXIF layers'),
      ),
    );
  }
}