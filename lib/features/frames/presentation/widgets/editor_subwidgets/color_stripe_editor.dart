import 'package:flutter/material.dart';

import '../../../data/models/frame_template.dart';
import 'hex_color_field.dart';

/// 颜色条层的参数编辑区（M2-T4）。
///
/// 控件：
/// - Dropdown: position（top / bottom）
/// - Slider: width 0.02–0.30（条厚度，照片高的比例）
/// - Slider: cornerRadius 0–20（圆角，px）
/// - HexColorField: color
class ColorStripeEditor extends StatelessWidget {
  const ColorStripeEditor({
    required this.layer,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onCornerRadiusChanged,
    required this.onPositionChanged,
    super.key,
  });

  final ColorStripeLayer layer;
  final ValueChanged<int> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onCornerRadiusChanged;
  final ValueChanged<StripePosition> onPositionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<StripePosition>(
          key: const Key('stripe_position_dropdown'),
          value: layer.position,
          decoration: const InputDecoration(
            labelText: '位置',
            isDense: true,
          ),
          items: const <DropdownMenuItem<StripePosition>>[
            DropdownMenuItem(
              value: StripePosition.top,
              child: Text('顶部'),
            ),
            DropdownMenuItem(
              value: StripePosition.bottom,
              child: Text('底部'),
            ),
          ],
          onChanged: (position) {
            if (position != null) onPositionChanged(position);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(width: 80, child: Text('厚度')),
            Expanded(
              child: Slider(
                key: const Key('stripe_width_slider'),
                value: layer.width.clamp(0.02, 0.30).toDouble(),
                min: 0.02,
                max: 0.30,
                divisions: 28,
                label: layer.width.toStringAsFixed(2),
                onChanged: onWidthChanged,
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                layer.width.toStringAsFixed(2),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 80, child: Text('圆角')),
            Expanded(
              child: Slider(
                key: const Key('stripe_corner_radius_slider'),
                value: layer.cornerRadius.clamp(0, 20).toDouble(),
                min: 0,
                max: 20,
                divisions: 20,
                label: layer.cornerRadius.toStringAsFixed(0),
                onChanged: onCornerRadiusChanged,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                layer.cornerRadius.toStringAsFixed(0),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        HexColorField(
          keyPrefix: 'stripe',
          initialValue: layer.color,
          onValidColor: onColorChanged,
        ),
      ],
    );
  }
}
