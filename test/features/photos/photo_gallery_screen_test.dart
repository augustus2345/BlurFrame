import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/app.dart';
import 'package:photo_beauty/features/photos/data/photo_permission_repository.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photo_permission_provider.dart';
import 'package:photo_beauty/features/photos/presentation/screens/photo_gallery_screen.dart';
import 'package:photo_beauty/shared/services/settings_service.dart';
import 'package:photo_manager/photo_manager.dart';

/// Integration tests for [PhotoGalleryScreen] — verifies the gallery correctly
/// delegates to [PermissionRequestScreen] vs the main content based on the
/// permission state.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - When the repository reports `notDetermined` / `denied` / `restricted`,
///   the gallery renders [PermissionRequestScreen] (with the appropriate
///   button — grant vs settings).
/// - When the repository reports `granted` / `limited`, the gallery renders
///   the main content placeholder ("暂无照片").
/// - The gallery's `initState` post-frame callback invokes
///   [PhotoPermissionNotifier.refresh] exactly once on mount.
class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;

  setUp(() {
    box = _MockBox();
  });

  /// Test wrapper: provides a mock repository + settings service so the
  /// gallery can read the initial permission state without touching real
  /// platform channels.
  Widget buildGallery({
    required PermissionState initialState,
    Future<PermissionState> Function()? request,
  }) {
    final repo = PhotoPermissionRepository(
      getCurrent: () async => initialState,
      request: request ?? () async => initialState,
      openSettings: () async {},
    );
    return ProviderScope(
      overrides: <Override>[
        photoPermissionRepositoryProvider.overrideWithValue(repo),
        settingsServiceProvider.overrideWithValue(SettingsService.fromBox(box)),
      ],
      child: const MaterialApp(home: PhotoGalleryScreen()),
    );
  }

  group('PhotoGalleryScreen — permission dispatch', () {
    testWidgets('notDetermined: renders PermissionRequestScreen grant view',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.notDetermined),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permission_grant_button')), findsOneWidget);
      expect(find.text('暂无照片'), findsNothing);
    });

    testWidgets('denied: renders PermissionRequestScreen settings view',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.denied),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permission_settings_button')), findsOneWidget);
      expect(find.byKey(const Key('permission_grant_button')), findsNothing);
    });

    testWidgets('restricted: renders PermissionRequestScreen settings view',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.restricted),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permission_settings_button')), findsOneWidget);
    });

    testWidgets('granted: renders gallery placeholder', (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.authorized),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无照片'), findsOneWidget);
      expect(find.byKey(const Key('permission_grant_button')), findsNothing);
      expect(find.byKey(const Key('permission_settings_button')), findsNothing);
    });

    testWidgets('limited: renders gallery placeholder (limited is usable)',
        (tester) async {
      await tester.pumpWidget(
        buildGallery(initialState: PermissionState.limited),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无照片'), findsOneWidget);
    });
  });

  group('PhotoGalleryScreen — refresh on mount', () {
    testWidgets('initState triggers refresh (post-frame callback)',
        (tester) async {
      var refreshCallCount = 0;
      final repo = PhotoPermissionRepository(
        getCurrent: () async {
          refreshCallCount++;
          return PermissionState.authorized;
        },
        request: () async => PermissionState.notDetermined,
        openSettings: () async {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            photoPermissionRepositoryProvider.overrideWithValue(repo),
            settingsServiceProvider.overrideWithValue(SettingsService.fromBox(box)),
          ],
          child: const MaterialApp(home: PhotoGalleryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(refreshCallCount, 1);
    });
  });
}
