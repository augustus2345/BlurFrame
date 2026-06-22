import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/services/settings_service.dart';

/// Provides the user's persisted theme preference.
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ref.watch(settingsServiceProvider).getThemeMode();
});

class PhotoBeautyApp extends ConsumerWidget {
  const PhotoBeautyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Photo Beauty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}