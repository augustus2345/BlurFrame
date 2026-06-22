import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('外观'),
          RadioListTile<ThemeMode>(
            title: const Text('跟随系统'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (mode) =>
                mode == null ? null : ref.read(themeModeProvider.notifier).state = mode,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('浅色'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (mode) =>
                mode == null ? null : ref.read(themeModeProvider.notifier).state = mode,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('深色'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (mode) =>
                mode == null ? null : ref.read(themeModeProvider.notifier).state = mode,
          ),
          const Divider(),
          const _SectionHeader('数据'),
          ListTile(
            title: const Text('清除本地数据'),
            subtitle: const Text('删除所有影集、标签与相框模板（不会删除设备原图）'),
            onTap: () {
              // TODO: confirm + call HiveService.clearAll()
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  // ignore: unused_element_parameter
  const _SectionHeader(this.label, {super.key});
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