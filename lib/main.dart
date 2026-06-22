import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/services/hive_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — photos read best in vertical orientation, and the
  // gesture vocabulary (swipe-up-to-delete) is portrait-first.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Persistence layer must be ready before any provider touches storage.
  await HiveService.init();

  runApp(
    const ProviderScope(
      child: PhotoBeautyApp(),
    ),
  );
}