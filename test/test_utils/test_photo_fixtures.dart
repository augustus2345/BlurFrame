import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';

/// 测试用照片 fixture — 用 N 张纯色 PNG 模拟设备上的真实照片。
///
/// 为什么用这个：
/// - 单元 / widget 测试里，`PhotoModel` 是纯数据，不需要真实文件。
/// - 但 `Image.memory` 需要合法字节；用 `image` 包（已在 pubspec）
///   生成 4×4 纯色 PNG 既能跑通 codec，又不占内存。
/// - 不同索引用不同色（HSV 色环等分），肉眼能直接分辨"第 N 格是哪张"，
///   调试时不用打 `print`。
///
/// 用法：
/// ```dart
/// // setUp 一次
/// final photos = TestPhotoFixtures.photos(count: 100);
/// final thumbs = await TestPhotoFixtures.thumbnailMap(count: 100);
///
/// // test 里
/// await tester.pumpWidget(buildGallery(
///   initialState: PermissionState.authorized,
///   photosLoad: () async => photos,
///   thumbnailLoader: (id) async => thumbs[id],
/// ));
/// ```
class TestPhotoFixtures {
  TestPhotoFixtures._();

  /// 生成 [count] 张 [PhotoModel]，id = `'photo_NNN'`（3 位补零）。
  ///
  /// 每张 takenAt 依次往前推 1 天，模拟"最近 100 天的照片"。
  /// 宽高固定 4032×3024（iPhone 12 主摄）。
  static List<PhotoModel> photos({required int count, DateTime? now}) {
    final base = now ?? DateTime.now();
    return List<PhotoModel>.generate(count, (i) {
      return PhotoModel(
        id: 'photo_${i.toString().padLeft(3, '0')}',
        path: '/DCIM/IMG_${i.toString().padLeft(4, '0')}.jpg',
        width: 4032,
        height: 3024,
        takenAt: base.subtract(Duration(days: i)),
      );
    });
  }

  /// 一次性生成 [count] 张照片对应的缩略图 byte 字典。
  ///
  /// 推荐在 setUp 里建一次，测试里直接 `map[id]` 查表。
  /// 每张是 4×4 纯色 PNG（HSV 色环等分），肉眼可分辨。
  static Future<Map<String, Uint8List>> thumbnailMap({
    required int count,
    int size = 4,
  }) async {
    final map = <String, Uint8List>{};
    for (var i = 0; i < count; i++) {
      final id = 'photo_${i.toString().padLeft(3, '0')}';
      map[id] = _colorBlockPng(size: size, hue: (i * 360 ~/ count) % 360);
    }
    return map;
  }

  /// 单张纯色 PNG 字节。hue 0–360。
  static Uint8List _colorBlockPng({required int size, required int hue}) {
    final image = img.Image(width: size, height: size);
    final (r, g, b) = _hsvToRgb(h: hue.toDouble(), s: 0.7, v: 0.9);
    image.clear(img.ColorRgb8(r, g, b));
    return Uint8List.fromList(img.encodePng(image));
  }

  /// HSV → RGB (h: 0-360, s/v: 0-1)。
  static (int, int, int) _hsvToRgb({
    required double h,
    required double s,
    required double v,
  }) {
    final c = v * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = v - c;
    double r;
    double g;
    double b;
    if (h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }
    return (
      ((r + m) * 255).round().clamp(0, 255),
      ((g + m) * 255).round().clamp(0, 255),
      ((b + m) * 255).round().clamp(0, 255),
    );
  }
}