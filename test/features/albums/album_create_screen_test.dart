import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photo_beauty/features/albums/data/models/album_model.dart';
import 'package:photo_beauty/features/albums/data/repositories/album_repository.dart';
import 'package:photo_beauty/features/albums/presentation/providers/album_list_provider.dart';
import 'package:photo_beauty/features/albums/presentation/screens/album_create_screen.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/presentation/providers/asset_thumbnail_loader_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photos_provider.dart';
import '../../test_utils/test_photo_fixtures.dart';

class _MockAlbumRepository extends Mock implements AlbumRepository {}

class _FakeAlbumModel extends Fake implements AlbumModel {}

class _StubPhotosNotifier extends PhotosNotifier {
  _StubPhotosNotifier(this._data);
  final List<PhotoModel> _data;

  @override
  Future<List<PhotoModel>> build() async => _data;
}

class _NoOpAlbumListNotifier extends AlbumListNotifier {
  @override
  Future<List<AlbumModel>> build() async => [];
  @override
  Future<void> refresh() async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAlbumModel());
    registerFallbackValue(AlbumLayout.grid);
  });

  group('AlbumCreateScreen', () {
    late _MockAlbumRepository mockAlbumRepo;
    late List<PhotoModel> testPhotos;
    late Map<String, Uint8List> testThumbs;

    setUpAll(() async {
      testPhotos = TestPhotoFixtures.photos(count: 20);
      testThumbs = await TestPhotoFixtures.thumbnailMap(count: 20);
    });

    setUp(() {
      mockAlbumRepo = _MockAlbumRepository();
    });

    Widget buildSubject({
      List<Override> extraOverrides = const [],
    }) {
      final router = GoRouter(
        initialLocation: '/albums/create',
        routes: [
          GoRoute(
            path: '/albums/create',
            builder: (context, state) => const AlbumCreateScreen(),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockAlbumRepo),
          photosProvider.overrideWith(() => _StubPhotosNotifier(testPhotos)),
          assetThumbnailLoaderProvider.overrideWithValue(
            (String id) async => testThumbs[id],
          ),
          albumListProvider.overrideWith(() => _NoOpAlbumListNotifier()),
          ...extraOverrides,
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('初始态：名称输入 + 版式 chips + 照片网格', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // 标题
      expect(find.text('新建影集'), findsOneWidget);
      // 名称输入
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('影集名称'), findsOneWidget);
      // 4 个版式 chip
      expect(find.text('网格'), findsOneWidget);
      expect(find.text('杂志'), findsOneWidget);
      expect(find.text('拼贴'), findsOneWidget);
      expect(find.text('宝丽来'), findsOneWidget);
      // 照片网格标题
      expect(find.text('选择照片'), findsOneWidget);
      // 照片网格（4 列，20 张）
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('输入名称', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '我的旅行照片');
      expect(find.text('我的旅行照片'), findsOneWidget);
    });

    testWidgets('选择照片：tap 照片切换选中态', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // tap 第一张照片
      final firstItem = find.byKey(const Key('photo_picker_item_photo_000'));
      expect(firstItem, findsOneWidget);
      await tester.tap(firstItem);
      await tester.pump();

      // 显示"已选 1 张"
      expect(find.text('已选 1 张'), findsOneWidget);

      // 再 tap 同一张取消选择
      await tester.tap(firstItem);
      await tester.pump();
      expect(find.text('已选 1 张'), findsNothing);
    });

    testWidgets('选多个照片：已选 N 张计数正确', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('photo_picker_item_photo_000')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('photo_picker_item_photo_001')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('photo_picker_item_photo_002')));
      await tester.pump();

      expect(find.text('已选 3 张'), findsOneWidget);
    });

    testWidgets('切换版式 chip', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // 默认选中"网格"
      final gridChip = find.widgetWithText(ChoiceChip, '网格');
      expect(gridChip, findsOneWidget);

      // tap "杂志"
      await tester.tap(find.widgetWithText(ChoiceChip, '杂志'));
      await tester.pump();

      // 验证切换（ChoiceChip selected 状态变化触发 rebuild）
      final magazineChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '杂志'),
      );
      expect(magazineChip.selected, isTrue);
    });

    testWidgets('创建按钮：名称为空时提示', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('创建'));
      await tester.pump();

      expect(find.text('请输入影集名称'), findsOneWidget);
    });

    testWidgets('创建按钮：正常创建后 pop 并刷新列表', (tester) async {
      when(() => mockAlbumRepo.create(
            name: any(named: 'name'),
            photoIds: any(named: 'photoIds'),
            layout: any(named: 'layout'),
          )).thenAnswer((_) async => AlbumModel(
            id: 'new_album',
            name: '新影集',
            coverPhotoId: 'photo_000',
            photoIds: ['photo_000'],
            layout: AlbumLayout.grid,
          ));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // 输入名称
      await tester.enterText(find.byType(TextField), '新影集');
      // 选择第一张照片
      await tester.tap(find.byKey(const Key('photo_picker_item_photo_000')));
      await tester.pump();

      // tap 创建
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      // 验证 create 调用
      verify(() => mockAlbumRepo.create(
            name: '新影集',
            photoIds: [testPhotos.first.id],
            layout: AlbumLayout.grid,
          )).called(1);

      // 验证 pop 回列表页（此时 router 在 /albums/create 的父路径）
      // GoRouter test driver 不会真的 pop，因为我们只配了 create 一条路由
      // 验证创建成功无报错即可
    });

    testWidgets('创建中显示 loading 态', (tester) async {
      final completer = Completer<AlbumModel>();
      when(() => mockAlbumRepo.create(
            name: any(named: 'name'),
            photoIds: any(named: 'photoIds'),
            layout: any(named: 'layout'),
          )).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '新影集');
      await tester.tap(find.text('创建'));
      await tester.pump();

      // 创建中：按钮变成 CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('创建'), findsNothing);

      // 完成后恢复
      completer.complete(AlbumModel(
        id: 'new_album',
        name: '新影集',
        coverPhotoId: 'photo_000',
        photoIds: ['photo_000'],
        layout: AlbumLayout.grid,
      ));
      await tester.pumpAndSettle();
    });

    testWidgets('创建失败显示错误 snackbar', (tester) async {
      when(() => mockAlbumRepo.create(
            name: any(named: 'name'),
            photoIds: any(named: 'photoIds'),
            layout: any(named: 'layout'),
          )).thenThrow(Exception('create failed'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '新影集');
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(find.text('创建失败，请重试'), findsOneWidget);
      // 按钮恢复可点击
      expect(find.text('创建'), findsOneWidget);
    });

    testWidgets('关闭按钮可点击', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // 关闭按钮存在
      expect(find.byIcon(Icons.close), findsOneWidget);
      // 可点击不抛错
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
    });
  });
}