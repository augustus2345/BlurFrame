/// Centralized constants — keep tunables here so they don't get sprinkled
/// across feature code.
class AppConstants {
  AppConstants._();

  // Hive boxes
  static const String settingsBox = 'settings_box';
  static const String photosMetaBox = 'photos_meta_box';
  static const String albumsBox = 'albums_box';
  static const String tagsBox = 'tags_box';
  static const String framesBox = 'frames_box';

  // Settings keys
  static const String themeModeKey = 'theme_mode';
  static const String firstLaunchKey = 'first_launch';

  // Layout
  static const double pageHorizontalPadding = 16;
  static const double cardRadius = 16;
  static const double buttonRadius = 12;

  // Image processing
  static const int thumbnailSize = 512;
  static const int maxImageDimension = 4096;
}