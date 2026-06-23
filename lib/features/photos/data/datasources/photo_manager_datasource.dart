import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// 系统相册的最小照片信息 — 业务层与 `photo_manager` 的 `AssetEntity` 之间的边界 DTO。
///
/// 引入此 DTO 的目的：
/// 1. `PhotoRepository` 不直接依赖 `package:photo_manager` — 测试和未来切换实现
///    （如直接读 MediaStore / Photos.framework）都更简单。
/// 2. 把"创建时间=0"（`AssetEntity` 把 `null createDateSecond` 算成 epoch 1970）
///    和"宽高=0"（EXIF 解析失败时）这两类**坑值**在边界处归一化为 `null`，
///    业务层不需要再处理。
class SystemPhoto {
  const SystemPhoto({
    required this.id,
    this.path,
    this.width,
    this.height,
    this.takenAt,
  });

  /// `photo_manager` 平台资源 ID（也是 Hive box 的 key）。
  final String id;

  /// 相对路径（`AssetEntity.relativePath`）。在某些系统上可能为 `null`。
  final String? path;

  /// 像素宽。原 `AssetEntity.width == 0`（EXIF 解析失败）时归一化为 `null`。
  final int? width;

  /// 像素高。同上规则。
  final int? height;

  /// 拍摄 / 文件创建时间。`AssetEntity.createDateSecond == null` 时归一化为 `null`。
  final DateTime? takenAt;
}

/// `photo_manager` 权限下的系统相册数据源。
///
/// 封装：
/// - [PhotoManager.getAssetPathList] — 列出所有相册（"最近" / 相机胶卷 / 各 folder）
/// - `AssetPathEntity.getAssetListPaged` — 每个相册分页抓 [AssetEntity]
/// - [mapAsset] — `AssetEntity` → [SystemPhoto] 的边界转换
///
/// 测试入口：构造函数接受 `fetchAll` 注入函数，避免真实平台通道调用。
class PhotoManagerDatasource {
  /// 测试 / DI 入口：传入一个伪 `fetchAll` 函数以替代真实平台调用。
  PhotoManagerDatasource({
    Future<List<SystemPhoto>> Function()? fetchAll,
  }) : _fetchAll = fetchAll ?? _defaultFetchAll;

  final Future<List<SystemPhoto>> Function() _fetchAll;

  /// 抓取所有相册里的所有照片（不分页）。
  ///
  /// M1-T3 阶段：直接抓完；M6-T3 性能优化时改用流式分页。
  /// 已按相册 path 顺序串联，结果顺序 = 第一个 path 全部 + 第二个 path 全部 + ...
  Future<List<SystemPhoto>> fetchAll() => _fetchAll();

  /// 生产路径的默认实现：走 `PhotoManager` 真实 API。
  static Future<List<SystemPhoto>> _defaultFetchAll() async {
    final paths = await PhotoManager.getAssetPathList();
    final all = <SystemPhoto>[];
    for (final path in paths) {
      // M1-T3 暂不分页，先一次性抓完。M6-T3 改为 page-by-page 流式抓取。
      final assets = await path.getAssetListPaged(page: 0, size: 1000);
      for (final asset in assets) {
        all.add(mapAsset(asset));
      }
    }
    return all;
  }

  /// `AssetEntity` → [SystemPhoto] 的边界转换。
  ///
  /// 规则：
  /// - `width` / `height` 为 0 → `null`（EXIF 解析失败的坑值）
  /// - `createDateSecond` 为 `null` → `takenAt` 为 `null`（`AssetEntity.createDateTime`
  ///   在 `createDateSecond == null` 时会算成 1970 epoch，业务层不想要这个值）
  @visibleForTesting
  static SystemPhoto mapAsset(AssetEntity asset) {
    final takenAt = asset.createDateSecond == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(asset.createDateSecond! * 1000);
    return SystemPhoto(
      id: asset.id,
      path: asset.relativePath,
      width: asset.width == 0 ? null : asset.width,
      height: asset.height == 0 ? null : asset.height,
      takenAt: takenAt,
    );
  }
}
