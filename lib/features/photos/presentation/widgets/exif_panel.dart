import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/datasources/exif_datasource.dart';

/// EXIF 信息面板 — 以表格形式展示相机参数。
///
/// 设计要点：
/// - **字段名称中文本地化**：make→相机 / model→镜头 / dateTimeOriginal→拍摄时间
///   / fNumber→光圈 / exposureTime→快门 / iso→ISO / focalLength→焦距
/// - **isEmpty 时不渲染**：父级检测 `exif.isEmpty` 后跳过此组件
/// - **友好数值格式化**：曝光时间显示为分数形式（如 1/200s）而非小数
class ExifPanel extends StatelessWidget {
  const ExifPanel({required this.exif, super.key});

  final ExifSummary exif;

  /// 格式化曝光时间为分数形式，如 1/200
  String _formatExposureTime(double? seconds) {
    if (seconds == null) return '—';
    if (seconds >= 1) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    // 转换为分数形式
    final denominator = (1 / seconds).round();
    return '1/$denominator s';
  }

  /// 格式化光圈值
  String _formatFNumber(double? value) {
    if (value == null) return '—';
    return 'f/${value.toStringAsFixed(1)}';
  }

  /// 格式化焦距
  String _formatFocalLength(double? mm) {
    if (mm == null) return '—';
    return '${mm.toStringAsFixed(0)} mm';
  }

  /// 格式化 ISO
  String _formatIso(int? iso) {
    if (iso == null) return '—';
    return 'ISO $iso';
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (exif.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark
        ? Colors.white70
        : Colors.black87;
    final labelColor = theme.brightness == Brightness.dark
        ? Colors.white38
        : Colors.black45;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 相机 + 镜头一行
          if (exif.make != null || exif.model != null) ...[
            _ExifRow(
              icon: Icons.camera_alt_outlined,
              label: '相机',
              value: [exif.make, exif.model]
                  .whereType<String>()
                  .join(' ')
                  .trim(),
              valueColor: textColor,
              labelColor: labelColor,
            ),
            const SizedBox(height: 8),
          ],

          // 拍摄时间
          if (exif.dateTimeOriginal != null) ...[
            _ExifRow(
              icon: Icons.access_time,
              label: '拍摄时间',
              value: _formatDateTime(exif.dateTimeOriginal),
              valueColor: textColor,
              labelColor: labelColor,
            ),
            const SizedBox(height: 8),
          ],

          // 光圈 + 快门 + ISO 一行（三列）
          Row(
            children: [
              if (exif.fNumber != null)
                Expanded(
                  child: _ExifCell(
                    icon: Icons.camera_outlined,
                    label: '光圈',
                    value: _formatFNumber(exif.fNumber),
                    valueColor: textColor,
                    labelColor: labelColor,
                  ),
                ),
              if (exif.exposureTime != null)
                Expanded(
                  child: _ExifCell(
                    icon: Icons.shutter_speed,
                    label: '快门',
                    value: _formatExposureTime(exif.exposureTime),
                    valueColor: textColor,
                    labelColor: labelColor,
                  ),
                ),
              if (exif.iso != null)
                Expanded(
                  child: _ExifCell(
                    icon: Icons.iso,
                    label: 'ISO',
                    value: _formatIso(exif.iso),
                    valueColor: textColor,
                    labelColor: labelColor,
                  ),
                ),
            ],
          ),

          // 焦距
          if (exif.focalLength != null) ...[
            const SizedBox(height: 8),
            _ExifRow(
              icon: Icons.straighten,
              label: '焦距',
              value: _formatFocalLength(exif.focalLength),
              valueColor: textColor,
              labelColor: labelColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// 单行 EXIF 字段展示。
class _ExifRow extends StatelessWidget {
  const _ExifRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: labelColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: labelColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: valueColor),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// 单格 EXIF 字段展示（三列布局用）。
class _ExifCell extends StatelessWidget {
  const _ExifCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: labelColor),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: labelColor),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, color: valueColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}