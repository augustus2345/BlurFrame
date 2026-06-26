import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../data/datasources/exif_datasource.dart';

/// [ExifDatasource] 的 DI 入口。
///
/// 生产路径走默认（`asset.originBytes` + `readExifFromBytes`），测试路径可 override。
final exifDatasourceProvider = Provider<ExifDatasource>((ref) {
  return ExifDatasource();
});

/// 根据 assetId 加载并解析 EXIF 数据。
///
/// 用 [AssetEntity.fromId] 获取 AssetEntity，然后调用 [ExifDatasource.parse]。
final exifByIdProvider = FutureProvider.family<ExifSummary, String>((ref, assetId) async {
  final datasource = ref.read(exifDatasourceProvider);
  final asset = await AssetEntity.fromId(assetId);
  if (asset == null) return ExifSummary.empty;
  return datasource.parse(asset);
});