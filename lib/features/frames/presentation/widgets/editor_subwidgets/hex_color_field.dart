import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 十六进制颜色输入框（M2-T4 自定义小工具）。
///
/// 用户输入 `#AARRGGBB` 或 `0xAARRGGBB`（8 位 hex）；不合法时输入框
/// 显示红色错误边框，但 state 不被覆盖（用户可以继续敲），提交或失焦
/// 时如果还非法就**回滚**到 [initialValue]。
///
/// 选 `TextEditingController` + `initialValue` 模式而非纯受控，因为
/// `setState` 不会打掉用户光标位置。`didUpdateWidget` 时只有当外部
/// 初始值和当前文本不一致才覆盖 controller（防输入法被打断）。
class HexColorField extends StatefulWidget {
  const HexColorField({
    required this.initialValue,
    required this.onValidColor,
    this.labelText = '颜色 (AARRGGBB)',
    this.keyPrefix = 'color',
    super.key,
  });

  /// 当前有效颜色（ARGB int）。
  final int initialValue;

  /// 输入合法时回调；非法时不调。
  final ValueChanged<int> onValidColor;

  final String labelText;
  final String keyPrefix;

  @override
  State<HexColorField> createState() => _HexColorFieldState();
}

class _HexColorFieldState extends State<HexColorField> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatHex(widget.initialValue));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HexColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = _formatHex(widget.initialValue);
    if (current != _controller.text && !_isFocused()) {
      // 外部 state 变了，且输入框没在编辑 → 同步
      _controller.text = current;
      _errorText = null;
    }
  }

  bool _isFocused() {
    final focus = FocusScope.of(context);
    return focus.hasFocus && focus.focusedChild != null;
  }

  /// ARGB int → `#AARRGGBB`。
  static String _formatHex(int argb) {
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// `#AARRGGBB` / `0xAARRGGBB` / `AARRGGBB` → ARGB int。
  /// 非法时返回 null。
  static int? _parseHex(String raw) {
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    if (s.length != 8) return null;
    final value = int.tryParse(s, radix: 16);
    return value;
  }

  void _onChanged(String raw) {
    final parsed = _parseHex(raw);
    if (parsed == null) {
      setState(() => _errorText = '格式：AARRGGBB（8 位 hex）');
      return;
    }
    setState(() => _errorText = null);
    widget.onValidColor(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: Key('${widget.keyPrefix}_text_field'),
      controller: _controller,
      onChanged: _onChanged,
      decoration: InputDecoration(
        labelText: widget.labelText,
        isDense: true,
        errorText: _errorText,
        suffixIcon: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Color(widget.initialValue),
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      inputFormatters: [
        // 限制输入：hex 字符 + # / x（用户能打 # 和 0x 前缀）
        FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FxX#]')),
      ],
    );
  }
}
