import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

/// Bottom navigation shell. Wraps each top-level route with a shared
/// scaffold + nav bar so navigation state is preserved across switches.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _tabs = <_TabSpec>[
    _TabSpec(AppRoute.gallery, Icons.photo_library_outlined, Icons.photo_library_rounded, '相册'),
    _TabSpec(AppRoute.albums, Icons.collections_bookmark_outlined, Icons.collections_bookmark_rounded, '影集'),
    _TabSpec(AppRoute.frames, Icons.crop_square_outlined, Icons.crop_square_rounded, '相框'),
    _TabSpec(AppRoute.search, Icons.search_outlined, Icons.search_rounded, '搜索'),
    _TabSpec(AppRoute.settings, Icons.tune_outlined, Icons.tune_rounded, '设置'),
  ];

  int _indexFromLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.path, this.icon, this.selectedIcon, this.label);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}