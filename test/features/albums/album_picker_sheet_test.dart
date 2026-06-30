import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/albums/data/models/album_model.dart';
import 'package:photo_beauty/features/albums/data/repositories/album_repository.dart';
import 'package:photo_beauty/features/albums/presentation/providers/album_list_provider.dart';
import 'package:photo_beauty/features/albums/presentation/widgets/album_picker_sheet.dart';

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox albumBox;
  late AlbumRepository albumRepo;

  final testAlbums = [
    AlbumModel(id: 'album_001', name: '风景', coverPhotoId: 'p1', photoIds: ['p1', 'p2']),
    AlbumModel(id: 'album_002', name: '人物', coverPhotoId: 'p3', photoIds: ['p3']),
  ];

  setUp(() {
    albumBox = _MockBox();
    albumRepo = AlbumRepository.fromBox(albumBox);

    // mock box.values 返回 Iterable
    when(() => albumBox.values).thenReturn(testAlbums);
    // mock box.put 返回 Future<void>
    when(() => albumBox.put(any(), any())).thenAnswer((_) async {});
    // mock box.get - 已有影集返回影集，新建的不返回（firstWhere 找的是 getAll().firstWhere）
    when(() => albumBox.get(any())).thenReturn(null);
  });

  Widget buildSheet({
    required Set<String> selectedPhotoIds,
    required void Function(String albumId) onConfirm,
  }) {
    return ProviderScope(
      overrides: [
        albumRepositoryProvider.overrideWithValue(albumRepo),
        albumListProvider.overrideWith(() => _SuccessAlbumListNotifier(testAlbums)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AlbumPickerSheet(
            selectedPhotoIds: selectedPhotoIds,
            onConfirm: onConfirm,
          ),
        ),
      ),
    );
  }

  group('AlbumPickerSheet', () {
    testWidgets('显示标题和已选照片数量', (tester) async {
      await tester.pumpWidget(
        buildSheet(
          selectedPhotoIds: {'p1', 'p2', 'p3'},
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('加入影集'), findsOneWidget);
      expect(find.text('已选 3 张'), findsOneWidget);
    });

    testWidgets('显示影集列表', (tester) async {
      await tester.pumpWidget(
        buildSheet(
          selectedPhotoIds: {'p1'},
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('风景'), findsOneWidget);
      expect(find.text('人物'), findsOneWidget);
      expect(find.text('2 张照片'), findsOneWidget);
      expect(find.text('1 张照片'), findsOneWidget);
    });

    testWidgets('点击影集触发 onConfirm 并关闭', (tester) async {
      String? confirmedAlbumId;
      await tester.pumpWidget(
        buildSheet(
          selectedPhotoIds: {'p1'},
          onConfirm: (id) => confirmedAlbumId = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('风景'));
      await tester.pumpAndSettle();

      expect(confirmedAlbumId, 'album_001');
    });

    testWidgets('点击"新建影集并添加"按钮打开对话框', (tester) async {
      await tester.pumpWidget(
        buildSheet(
          selectedPhotoIds: {'p1'},
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建影集并添加'));
      await tester.pumpAndSettle();

      expect(find.text('新建影集'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('新建影集时 onConfirm 被调用', (tester) async {
      bool onConfirmCalled = false;
      String? confirmedAlbumId;

      await tester.pumpWidget(
        buildSheet(
          selectedPhotoIds: {'photo_1', 'photo_2'},
          onConfirm: (id) {
            onConfirmCalled = true;
            confirmedAlbumId = id;
          },
        ),
      );
      await tester.pumpAndSettle();

      // 点击"新建影集并添加"
      await tester.tap(find.text('新建影集并添加'));
      await tester.pumpAndSettle();

      // 输入影集名称
      await tester.enterText(find.byType(TextField), '我的新影集');
      await tester.pumpAndSettle();

      // 点击创建按钮
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      // 验证 onConfirm 被调用
      expect(onConfirmCalled, isTrue);
      expect(confirmedAlbumId, isNotNull);
    });
  });
}

/// 成功的影集列表 Notifier（直接返回预定义数据）.
class _SuccessAlbumListNotifier extends AlbumListNotifier {
  _SuccessAlbumListNotifier(this._albums);
  final List<AlbumModel> _albums;

  @override
  Future<List<AlbumModel>> build() async => _albums;
}
