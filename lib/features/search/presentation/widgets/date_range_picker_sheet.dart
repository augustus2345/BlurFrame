import 'package:flutter/material.dart';

/// 日期范围过滤底部弹窗.
///
/// [initialFrom] / [initialTo] — 当前已选范围.
/// [onConfirm] — 确认回调，参数为 (from, to)；null 表示清除该端.
Future<void> showDateRangeFilterSheet({
  required BuildContext context,
  required DateTime? initialFrom,
  required DateTime? initialTo,
  required void Function(DateTime? from, DateTime? to) onConfirm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DateRangeFilterSheet(
      initialFrom: initialFrom,
      initialTo: initialTo,
      onConfirm: onConfirm,
    ),
  );
}

/// 日期范围过滤 Sheet.
class DateRangeFilterSheet extends StatefulWidget {
  const DateRangeFilterSheet({
    required this.initialFrom,
    required this.initialTo,
    required this.onConfirm,
    super.key,
  });

  final DateTime? initialFrom;
  final DateTime? initialTo;
  final void Function(DateTime? from, DateTime? to) onConfirm;

  @override
  State<DateRangeFilterSheet> createState() => _DateRangeFilterSheetState();
}

class _DateRangeFilterSheetState extends State<DateRangeFilterSheet> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _from = picked);
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _to = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽条
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text('拍摄日期', style: theme.textTheme.titleLarge),

              const SizedBox(height: 16),

              // 快捷选项
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickChip(
                    label: '今天',
                    onTap: () {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      setState(() {
                        _from = today;
                        _to = today;
                      });
                    },
                  ),
                  _QuickChip(
                    label: '本周',
                    onTap: () {
                      final now = DateTime.now();
                      final weekday = now.weekday;
                      setState(() {
                        _from = DateTime(now.year, now.month, now.day - weekday + 1);
                        _to = now;
                      });
                    },
                  ),
                  _QuickChip(
                    label: '本月',
                    onTap: () {
                      final now = DateTime.now();
                      setState(() {
                        _from = DateTime(now.year, now.month, 1);
                        _to = now;
                      });
                    },
                  ),
                  _QuickChip(
                    label: '今年',
                    onTap: () {
                      final now = DateTime.now();
                      setState(() {
                        _from = DateTime(now.year, 1, 1);
                        _to = now;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 范围选择
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: '开始日期',
                      value: _from,
                      onTap: _pickFrom,
                      onClear: () => setState(() => _from = null),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('至', style: theme.textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: _DateField(
                      label: '结束日期',
                      value: _to,
                      onTap: _pickTo,
                      onClear: () => setState(() => _to = null),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.onConfirm(_from, _to);
                        Navigator.of(context).pop();
                      },
                      child: const Text('确认'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null
                    ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
                    : label,
                style: value == null
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)
                    : theme.textTheme.bodyMedium,
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 16, color: theme.colorScheme.outline),
              ),
          ],
        ),
      ),
    );
  }
}