import 'package:flutter/material.dart';

import '../../../data/models/frame_template.dart';
import 'hex_color_field.dart';

/// 文字水印层的参数编辑区（M2-T4）。
///
/// 控件：
/// - TextField: text
/// - Dropdown: position（7 个枚举）
/// - Slider: fontSize 8–48
/// - HexColorField: color
class TextWatermarkEditor extends StatefulWidget {
  const TextWatermarkEditor({
    required this.layer,
    required this.onTextChanged,
    required this.onPositionChanged,
    required this.onFontSizeChanged,
    required this.onColorChanged,
    super.key,
  });

  final TextWatermarkLayer layer;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<WatermarkPosition> onPositionChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<int> onColorChanged;

  @override
  State<TextWatermarkEditor> createState() => _TextWatermarkEditorState();
}

class _TextWatermarkEditorState extends State<TextWatermarkEditor> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.layer.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TextWatermarkEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.layer.text != _textController.text) {
      _textController.text = widget.layer.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 文字
        TextField(
          key: const Key('watermark_text_field'),
          controller: _textController,
          onChanged: widget.onTextChanged,
          decoration: const InputDecoration(
            labelText: '水印文字',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        // 位置
        DropdownButtonFormField<WatermarkPosition>(
          key: const Key('watermark_position_dropdown'),
          value: widget.layer.position,
          decoration: const InputDecoration(
            labelText: '位置',
            isDense: true,
          ),
          items: const <DropdownMenuItem<WatermarkPosition>>[
            DropdownMenuItem(
              value: WatermarkPosition.topLeft,
              child: Text('左上'),
            ),
            DropdownMenuItem(
              value: WatermarkPosition.topCenter,
              child: Text('顶部居中'),
            ),
            DropdownMenuItem(
              value: WatermarkPosition.topRight,
              child: Text('右上'),
            ),
            DropdownMenuItem(
              value: WatermarkPosition.center,
              child: Text('正中央'),
            ),
            DropdownMenuItem(
              value: WatermarkPosition.bottomLeft,
              child: Text('左下'),
            ),
            DropdownMenuItem(
              value: WatermarkPosition.bottomCenter,
              child: Text('底部居中'),
            ),
            DropdownMenuItem(
              value: WatermarkPosition.bottomRight,
              child: Text('右下'),
            ),
          ],
          onChanged: (position) {
            if (position != null) widget.onPositionChanged(position);
          },
        ),
        const SizedBox(height: 12),
        // 字号
        Row(
          children: [
            const SizedBox(width: 80, child: Text('字号')),
            Expanded(
              child: Slider(
                key: const Key('watermark_font_size_slider'),
                value: widget.layer.fontSize.clamp(8, 48).toDouble(),
                min: 8,
                max: 48,
                divisions: 40,
                label: widget.layer.fontSize.toStringAsFixed(0),
                onChanged: widget.onFontSizeChanged,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                widget.layer.fontSize.toStringAsFixed(0),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 颜色
        HexColorField(
          keyPrefix: 'watermark',
          initialValue: widget.layer.color,
          onValidColor: widget.onColorChanged,
        ),
      ],
    );
  }
}
