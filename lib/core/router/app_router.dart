import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/albums/presentation/screens/album_list_screen.dart';
import '../../features/frames/presentation/screens/frame_template_list_screen.dart';
import '../../features/photos/presentation/screens/photo_detail_screen.dart';
import '../../features/photos/presentation/screens/photo_gallery_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../widgets/app_shell.dart';

/// Top-level route names — referenced from navigation and deep-links.
abstract class AppRoute {
  static const gallery = '/gallery';
  static const albums = '/albums';
  static const frames = '/frames';
  static const search = '/search';
  static const settings = '/settings';

  // Detail/sub routes
  static const photoDetail = '/photo/:id';
  static const frameEditor = '/frames/editor';
  static const albumDetail = '/albums/:id';
  static const cleanup = '/cleanup';
}

/// Single source of truth for the router — exposed as a Riverpod provider
/// so the app rebuilds naturally when config changes (e.g. redirect rules).
final routerProvider = Provider<GoRouter>((ref) {
  return _buildRouter();
});

GoRouter _buildRouter() {
  final shellNavigatorKey = GlobalKey<NavigatorState>();
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: AppRoute.gallery,
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    routes: [
      // 详情页：顶层 GoRoute（脱离 ShellRoute）→ push 时全屏沉浸，隐藏底部 5 tab。
      GoRoute(
        path: AppRoute.photoDetail,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final assetId = state.pathParameters['id'] ?? '';
          return MaterialPage<void>(
            key: state.pageKey,
            child: PhotoDetailScreen(assetId: assetId),
          );
        },
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoute.gallery,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PhotoGalleryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoute.albums,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: AlbumListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoute.frames,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: FrameTemplateListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoute.search,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: AppRoute.settings,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
}
