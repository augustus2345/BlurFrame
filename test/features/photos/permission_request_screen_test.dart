import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/photo_permission_status.dart';
import 'package:photo_beauty/features/photos/presentation/screens/permission_request_screen.dart';

/// Tests for [PermissionRequestScreen] — the first-launch / permission-denied
/// guidance UI.
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - `notDetermined` → friendly title + "授权访问" button (Key:
///   `permission_grant_button`).
/// - Tapping the grant button fires `onRequest` exactly once per tap.
/// - `requesting` → shows a loading indicator; no buttons rendered (caller is
///   expected to drive the transition; this is a defensive UX guard against
///   double-tap).
/// - `denied` and `restricted` → "打开系统设置" button (Key:
///   `permission_settings_button`); grant button absent.
/// - Tapping the settings button fires `onOpenSettings` exactly once per tap.
/// - `granted` / `limited` → "已授权" fallback (defensive; in practice the
///   gallery should not render this screen when usable).
///
/// Tests inject callbacks so we never touch real platform channels; the screen
/// is pure UI + callback dispatch.
void main() {
  Widget buildScreen({
    required PhotoPermissionStatus status,
    Future<void> Function()? onRequest,
    Future<void> Function()? onOpenSettings,
  }) {
    return MaterialApp(
      home: PermissionRequestScreen(
        status: status,
        onRequest: onRequest ?? () async {},
        onOpenSettings: onOpenSettings ?? () async {},
      ),
    );
  }

  group('PermissionRequestScreen — notDetermined', () {
    testWidgets('shows grant button and friendly title', (tester) async {
      await tester.pumpWidget(
        buildScreen(status: PhotoPermissionStatus.notDetermined),
      );

      expect(find.text('查看你的相册'), findsOneWidget);
      expect(
        find.byKey(const Key('permission_grant_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('permission_settings_button')),
        findsNothing,
      );
    });

    testWidgets('tapping grant button calls onRequest once', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildScreen(
          status: PhotoPermissionStatus.notDetermined,
          onRequest: () async {
            callCount++;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('permission_grant_button')));
      await tester.pump();

      expect(callCount, 1);
    });
  });

  group('PermissionRequestScreen — requesting', () {
    testWidgets('shows loading indicator, no buttons rendered', (tester) async {
      await tester.pumpWidget(
        buildScreen(status: PhotoPermissionStatus.requesting),
      );

      expect(
        find.byKey(const Key('permission_requesting_indicator')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const Key('permission_grant_button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('permission_settings_button')),
        findsNothing,
      );
    });
  });

  group('PermissionRequestScreen — denied', () {
    testWidgets('shows settings button and denial title', (tester) async {
      await tester.pumpWidget(
        buildScreen(status: PhotoPermissionStatus.denied),
      );

      expect(find.text('需要相册权限'), findsOneWidget);
      expect(
        find.byKey(const Key('permission_settings_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('permission_grant_button')),
        findsNothing,
      );
    });

    testWidgets('tapping settings button calls onOpenSettings once',
        (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildScreen(
          status: PhotoPermissionStatus.denied,
          onOpenSettings: () async {
            callCount++;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('permission_settings_button')));
      await tester.pump();

      expect(callCount, 1);
    });
  });

  group('PermissionRequestScreen — restricted', () {
    testWidgets('shows settings button with restricted copy', (tester) async {
      await tester.pumpWidget(
        buildScreen(status: PhotoPermissionStatus.restricted),
      );

      expect(find.text('系统限制访问'), findsOneWidget);
      expect(
        find.byKey(const Key('permission_settings_button')),
        findsOneWidget,
      );
    });
  });

  group('PermissionRequestScreen — granted / limited fallback', () {
    testWidgets('granted shows "已授权" fallback (defensive)', (tester) async {
      await tester.pumpWidget(
        buildScreen(status: PhotoPermissionStatus.granted),
      );

      expect(find.text('已授权'), findsOneWidget);
      expect(
        find.byKey(const Key('permission_grant_button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('permission_settings_button')),
        findsNothing,
      );
    });

    testWidgets('limited shows "已授权" fallback (defensive)', (tester) async {
      await tester.pumpWidget(
        buildScreen(status: PhotoPermissionStatus.limited),
      );

      expect(find.text('已授权'), findsOneWidget);
    });
  });
}
