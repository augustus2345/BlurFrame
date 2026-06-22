import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder provider for the photo list. Real implementation will pull
/// from photo_manager and stream changes via watch().
final photoListProvider = FutureProvider<void>((ref) async {
  // TODO: fetch photos from device via photo_manager.
});