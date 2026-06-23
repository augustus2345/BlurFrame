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

  /// Resolve a [location] (a path *without* query string) to the index of
  /// the tab it belongs to.
  ///
  /// Match rule (defensive against future prefix collisions):
  /// - exact path equality, OR
  /// - sub-path beginning with `path + '/'` (a real path-segment boundary).
  ///
  /// `startsWith(path)` alone is unsafe: it would treat `/settings-extra`
  /// as `/settings`. The `path/` boundary disambiguates.
  ///
  /// Exposed `@visibleForTesting` so the lookup table is unit-testable
  /// without spinning up a full widget tree.
  @visibleForTesting
  static int indexFromLocation(String location, List<String> tabPaths) {
    for (var i = 0; i < tabPaths.length; i++) {
      final path = tabPaths[i];
      if (location == path || location.startsWith('$path/')) return i;
    }
    return 0;
  }

  int _indexFromLocation(String location) {
    return indexFromLocation(
      location,
      _tabs.map((t) => t.path).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use `uri.path` (not `uri.toString()`) so query strings don't
    // pollute the tab lookup — `/albums?sort=new` should still resolve
    // to the Albums tab.
    final location = GoRouterState.of(context).uri.path;
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