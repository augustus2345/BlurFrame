import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:photo_beauty/features/tags/data/models/tag_model.dart';
import 'package:photo_beauty/features/tags/data/repositories/tag_repository.dart';
import 'package:photo_beauty/features/tags/presentation/providers/tag_list_provider.dart';

void main() {
  group('TagListNotifier', () {
    late Directory tempDir;
    late Box<dynamic> tagsBox;
    late Box<dynamic> photosBox;
    late TagRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tag_list_provider_test_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(TagModelAdapter());
      }
      tagsBox = await Hive.openBox<dynamic>('test_tags');
      photosBox = await Hive.openBox<dynamic>('test_photos');
      repo = TagRepository.fromBox(tagsBox, photosBox);
    });

    tearDown(() async {
      await tagsBox.close();
      await photosBox.close();
      await Hive.deleteFromDisk();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('build 同步返回空列表', () async {
      final container = ProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final state = await container.read(tagListProvider.future);
      expect(state, isEmpty);
    });

    test('refresh 加载所有标签', () async {
      // 直接写入 box，绕过 repo.create 的 UUID 依赖
      await tagsBox.put('tag_001', TagModel(id: 'tag_001', name: '风景', colorValue: 0xFF66BB6A));
      await tagsBox.put('tag_002', TagModel(id: 'tag_002', name: '人物', colorValue: 0xFF42A5F5));

      final container = ProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(tagListProvider.notifier).refresh();
      final tags = await container.read(tagListProvider.future);

      expect(tags.length, 2);
      expect(tags.map((t) => t.name), containsAll(['风景', '人物']));
    });

    test('refresh 错误时 state 为 AsyncError', () async {
      final badRepo = _BadTagRepository();
      final container = ProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(badRepo)],
      );
      addTearDown(container.dispose);

      await container.read(tagListProvider.notifier).refresh();
      final state = container.read(tagListProvider);

      expect(state.hasError, true);
    });

    test('refresh 幂等：多次调用结果一致', () async {
      await tagsBox.put('tag_001', TagModel(id: 'tag_001', name: '美食', colorValue: 0xFFFF7043));

      final container = ProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(tagListProvider.notifier).refresh();
      await container.read(tagListProvider.notifier).refresh();
      await container.read(tagListProvider.notifier).refresh();

      final tags = await container.read(tagListProvider.future);
      expect(tags.length, 1);
    });
  });
}

/// 永远抛错的 Repository，用于测试错误路径。
class _BadTagRepository implements TagRepository {
  @override
  List<TagModel> getAll() => throw Exception('getAll error');

  @override
  TagModel? getById(String id) => null;

  @override
  Future<TagModel> create({required String name, int colorValue = 0xFF808080}) async => throw UnimplementedError();

  @override
  Future<void> rename(String id, String newName) async {}

  @override
  Future<void> setColor(String id, int newColorValue) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  bool isTagInUse(String tagId) => false;
}