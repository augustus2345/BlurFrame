import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app.dart';

/// 设置屏 — 应用级配置项。
///
/// 当前（M0）已实现：
/// - 主题模式：跟随系统 / 浅色 / 深色，绑定到 `themeModeProvider`（持久化在 Hive settings box）
/// - "清除本地数据" 占位（待 M0 之后补：底部确认 sheet → `HiveService.clearAll()`）
///
/// 后续（M6）将补：
/// - 默认导出尺寸（原图 / 1080p / 720p）
/// - 清理中间缓存（合成相框时的临时图片）
/// - 关于页（版本号、致谢、隐私声明）
class SettingsScreen extends ConsumerWidget {
  /// 路由 `/settings` 的目标 widget。由 `AppShell` 包裹。
  const SettingsScreen({super.key});

  /// 监听 `themeModeProvider` 重建 RadioListTile 的选中态；
  /// 用户切换主题时直接写回 provider，由 `SettingsService` 持久化。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('外观'),
          // RadioGroup 接管 groupValue + onChanged，子 RadioListTile 只声明 value。
          // 替代了 Flutter 3.32+ deprecated 的 RadioListTile.groupValue / onChanged。
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode == null) return;
              ref.read(themeModeProvider.notifier).state = mode;
            },
            child: const Column(
              children: <Widget>[
                RadioListTile<ThemeMode>(
                  title: Text('跟随系统'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('浅色'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('深色'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('数据'),
          ListTile(
            title: const Text('清除本地数据'),
            subtitle: const Text('删除所有影集、标签与相框模板（不会删除设备原图）'),
            onTap: () {
              // TODO(M0 后续 / M6): 底部确认 sheet → 二次确认 →
              // HiveService.clearAll() + SettingsService.reset()。
              // 重要：此操作只清 App 自身写入的元数据 / 模板 / 影集，
              // 不调用 PhotoManager 删除设备原图（PRD §4.7 FR-7.5）。
            },
          ),
        ],
      ),
    );
  }
}

/// 设置页分组小标题 — 视觉上将 ListView 切成"外观 / 数据"等组。
class _SectionHeader extends StatelessWidget {
  // ignore: unused_element_parameter
  const _SectionHeader(this.label, {super.key});

  /// 分组标题文案。
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
