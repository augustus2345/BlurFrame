import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/core/widgets/app_shell.dart';

/// Tests for [AppShell.indexFromLocation] — the tab-highlight lookup.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - Exact path match → returns that tab's index.
/// - Sub-path match (`/albums/123` matches `/albums`) → returns parent tab.
/// - Ambiguous prefix (`/settings-extra` should NOT match `/settings`) → 0.
/// - Empty / unknown location → 0 (default to first tab).
void main() {
  // Mirror the production tab paths. Keep in sync with `AppShell._tabs`.
  const tabPaths = <String>['/gallery', '/albums', '/frames', '/search', '/settings'];

  group('AppShell.indexFromLocation', () {
    test('exact match returns the tab index', () {
      expect(AppShell.indexFromLocation('/gallery', tabPaths), 0);
      expect(AppShell.indexFromLocation('/albums', tabPaths), 1);
      expect(AppShell.indexFromLocation('/frames', tabPaths), 2);
      expect(AppShell.indexFromLocation('/search', tabPaths), 3);
      expect(AppShell.indexFromLocation('/settings', tabPaths), 4);
    });

    test('sub-path with trailing slash returns the parent tab', () {
      expect(AppShell.indexFromLocation('/gallery/123', tabPaths), 0);
      expect(AppShell.indexFromLocation('/albums/abc', tabPaths), 1);
      expect(AppShell.indexFromLocation('/frames/editor', tabPaths), 2);
    });

    test('prefix collision (e.g. /settings-extra) does NOT match /settings', () {
      // Regression: startsWith('/settings') would wrongly match here.
      // With the `== || path/` rule, the only way to match is the exact
      // string or a path-segment boundary.
      expect(AppShell.indexFromLocation('/settings-extra', tabPaths), 0);
      expect(AppShell.indexFromLocation('/search-results', tabPaths), 0);
    });

    test('empty / unknown location defaults to first tab', () {
      expect(AppShell.indexFromLocation('', tabPaths), 0);
      expect(AppShell.indexFromLocation('/nowhere', tabPaths), 0);
    });

    test('trailing slash on tab path still matches', () {
      expect(AppShell.indexFromLocation('/gallery/', tabPaths), 0);
      expect(AppShell.indexFromLocation('/albums/', tabPaths), 1);
    });
  });
}
