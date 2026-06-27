import 'dart:typed_data';

import 'package:gal/gal.dart';

/// 图片保存器抽象（让 [ApplyTemplateNotifier] 可测试）。
///
/// 生产实现 [GalImageSaver] 调 `Gal.putImageBytes`。
/// 测试时注入 fake/mock 实现。
abstract class ImageSaver {
  Future<void> save(Uint8List bytes, {required String name});
}

/// 生产实现：调 [Gal.putImageBytes] 写入系统相册。
class GalImageSaver implements ImageSaver {
  const GalImageSaver();

  @override
  Future<void> save(Uint8List bytes, {required String name}) {
    return Gal.putImageBytes(bytes, name: name);
  }
}