import 'package:flutter/material.dart';

import '../../../data/models/frame_template.dart';

/// 模糊边框层的参数编辑区（M2-T4）。
///
/// 控件：
/// - Slider: intensity 0–10（步长 0.5）
/// - Switch: edge only（仅边缘 / 整图）
class BlurBorderEditor extends StatelessWidget {
  const BlurBorderEditor({
    required this.layer,
    required this.onIntensityChanged,
    required this.onEdgeOnlyChanged,
    super.key,
  });

  final BlurBorderLayer layer;
  final ValueChanged<double> onIntensityChanged;
  final ValueChanged<bool> onEdgeOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 强度
        Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('强度'),
            ),
            Expanded(
              child: Slider(
                key: const Key('blur_intensity_slider'),
                value: layer.intensity.clamp(0, 10).toDouble(),
                min: 0,
                max: 10,
                divisions: 20,
                label: layer.intensity.toStringAsFixed(1),
                onChanged: onIntensityChanged,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                layer.intensity.toStringAsFixed(1),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        // 仅边缘
        SwitchListTile(
          key: const Key('blur_edge_only_switch'),
          title: const Text('仅边缘'),
          subtitle: const Text('关闭则整张图片模糊'),
          value: layer.edge,
          onChanged: onEdgeOnlyChanged,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
