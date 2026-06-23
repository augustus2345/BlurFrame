import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

/// EXIF 数据的不可变业务摘要。
///
/// 设计原则：
/// 1. **只暴露业务关心的 7 个字段** — 不暴露 `exif` 包的 `IfdTag` / `IfdValues`
///    类型，业务层不需要知道 JPEG IFD 结构。
/// 2. **所有字段都可空** — 缺失 / 解析失败 / 文件损坏 → `null`，业务层不
///    做哨兵值处理。
/// 3. **不进 Hive** — EXIF 是详情页临时展示数据，每次从 `AssetEntity` 实时
///    读更准；持久化会引入与系统源的同步问题。`PhotoModel`（typeId: 1）
///    HiveField 0–6 也不为它留位。
@immutable
class ExifSummary {
  const ExifSummary({
    this.make,
    this.model,
    this.dateTimeOriginal,
    this.fNumber,
    this.exposureTime,
    this.iso,
    this.focalLength,
  });

  /// 相机制造商，如 `"Canon"` / `"Apple"` / `"SONY"`。
  final String? make;

  /// 相机型号，如 `"Canon EOS R5"` / `"iPhone 15 Pro"`。
  final String? model;

  /// 拍摄瞬间的本地时间（EXIF 规范不带时区）。
  final DateTime? dateTimeOriginal;

  /// 光圈值（f-number），如 1.8 / 2.8 / 5.6。
  final double? fNumber;

  /// 曝光时间（秒），如 1/200 s → 0.005 / 1 s → 1.0。
  final double? exposureTime;

  /// ISO 感光度。
  final int? iso;

  /// 镜头物理焦距（mm）。
  final double? focalLength;

  /// 全字段为空的占位 — 详情页 UI 检测后跳过 EXIF 区块。
  static const ExifSummary empty = ExifSummary();

  /// 7 字段都为 `null` 时返回 `true`。
  bool get isEmpty =>
      make == null &&
      model == null &&
      dateTimeOriginal == null &&
      fNumber == null &&
      exposureTime == null &&
      iso == null &&
      focalLength == null;

  /// 从 `exif` 包的 raw tags map 提取 7 字段。
  ///
  /// 提取规则：
  /// - 缺失 key → `null`
  /// - 类型不匹配（如 `FNumber` 期望 `IfdRatios` 但拿到 `IfdInts`）→ `null`
  /// - 空集合（`ratios.isEmpty` / `ints.isEmpty`）→ `null` — **关键防
  ///   `IfdNone` 陷阱**：`IfdNone.firstAsInt()` 返回 0 而非抛错，会让缺失的
  ///   ISO 被误读为 0
  /// - 字符串带尾随 `\0`（EXIF ASCII 标签惯例）→ 去 `\0` + trim
  /// - `DateTimeOriginal` 是 19 字节 ASCII `"YYYY:MM:DD HH:MM:SS"` → 用
  ///   [DateFormat] 解析为本地时间；长度不足或解析失败 → `null`
  @visibleForTesting
  static ExifSummary fromTags(Map<String, IfdTag> tags) {
    String? asciiString(String key) {
      final t = tags[key];
      if (t == null) return null;
      final v = t.values;
      if (v is IfdBytes) {
        final s = String.fromCharCodes(v.bytes).replaceAll('\x00', '').trim();
        return s.isEmpty ? null : s;
      }
      return null;
    }

    double? ratioDouble(String key) {
      final t = tags[key];
      if (t == null) return null;
      final v = t.values;
      if (v is IfdRatios && v.ratios.isNotEmpty) {
        return v.ratios.first.toDouble();
      }
      return null;
    }

    int? firstInt(String key) {
      final t = tags[key];
      if (t == null) return null;
      final v = t.values;
      if (v is IfdInts && v.ints.isNotEmpty) {
        return v.ints.first;
      }
      return null;
    }

    DateTime? dateTimeOriginalOf(String key) {
      final t = tags[key];
      if (t == null) return null;
      final v = t.values;
      if (v is! IfdBytes || v.bytes.length < 19) return null;
      // EXIF DateTimeOriginal: ASCII "YYYY:MM:DD HH:MM:SS"（本地时间，无时区）
      final ascii = String.fromCharCodes(v.bytes.sublist(0, 19));
      return DateFormat('yyyy:MM:dd HH:mm:ss').tryParse(ascii);
    }

    return ExifSummary(
      make: asciiString('Image Make'),
      model: asciiString('Image Model'),
      dateTimeOriginal: dateTimeOriginalOf('EXIF DateTimeOriginal'),
      fNumber: ratioDouble('EXIF FNumber'),
      exposureTime: ratioDouble('EXIF ExposureTime'),
      iso: firstInt('EXIF ISOSpeedRatings'),
      focalLength: ratioDouble('EXIF FocalLength'),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExifSummary &&
        other.make == make &&
        other.model == model &&
        other.dateTimeOriginal == dateTimeOriginal &&
        other.fNumber == fNumber &&
        other.exposureTime == exposureTime &&
        other.iso == iso &&
        other.focalLength == focalLength;
  }

  @override
  int get hashCode => Object.hash(
        make,
        model,
        dateTimeOriginal,
        fNumber,
        exposureTime,
        iso,
        focalLength,
      );
}

/// 照片 EXIF 数据源 — 把 `exif` 包的原始 IFD 数据归一化为业务 [ExifSummary]。
///
/// 设计原则（与 M1-T3 [PhotoManagerDatasource] 对齐）：
/// 1. **边界封装** — 业务层不直接 import `package:exif` /
///    `package:photo_manager`。
/// 2. **DI 注入** — 构造函数接受 [readBytes] / [parseExif] 两个函数注入点；
///    生产路径走默认（`asset.originBytes` + `readExifFromBytes`），测试
///    路径传 fake。
/// 3. **失败静默** — `originBytes` 为 `null` / 解析抛错 / 数据损坏 → 返回
///    [ExifSummary.empty]，详情页 UI 不会因此崩溃。
///
/// 集成边界：EXIF **不进 Hive**（不动 [PhotoModel]），由详情页（M1-T8）
/// 在用户进入页面时调用 `parse(asset)` 实时解析。
class ExifDatasource {
  /// 测试 / DI 入口：可注入 [readBytes] / [parseExif] 替代默认实现。
  ExifDatasource({
    Future<Uint8List?> Function(AssetEntity)? readBytes,
    Future<Map<String, IfdTag>> Function(Uint8List)? parseExif,
  })  : _readBytes = readBytes ?? _defaultReadBytes,
        _parseExif = parseExif ?? readExifFromBytes;

  final Future<Uint8List?> Function(AssetEntity) _readBytes;
  final Future<Map<String, IfdTag>> Function(Uint8List) _parseExif;

  /// 主入口：`AssetEntity` → `ExifSummary`。
  ///
  /// 失败语义（任意一条命中即返回 [ExifSummary.empty]）：
  /// - [readBytes] 抛异常（权限拒绝 / 平台通道未注册）
  /// - [readBytes] 返回 `null`（asset 没本地缓存）
  /// - [parseExif] 抛异常或返回不可解析数据
  /// - tags 中目标 key 全部缺失
  Future<ExifSummary> parse(AssetEntity asset) async {
    try {
      final bytes = await _readBytes(asset);
      if (bytes == null) return ExifSummary.empty;
      return await parseBytes(bytes);
    } catch (_) {
      return ExifSummary.empty;
    }
  }

  /// 剥离平台依赖的子入口：`bytes` → `ExifSummary`，便于不依赖
  /// `photo_manager` 的集成测试。失败同样静默。
  Future<ExifSummary> parseBytes(Uint8List bytes) async {
    try {
      final tags = await _parseExif(bytes);
      return ExifSummary.fromTags(tags);
    } catch (_) {
      return ExifSummary.empty;
    }
  }

  static Future<Uint8List?> _defaultReadBytes(AssetEntity asset) =>
      asset.originBytes;
}
