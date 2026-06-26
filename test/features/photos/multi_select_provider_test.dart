import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blurframe/features/photos/presentation/providers/multi_select_provider.dart';

void main() {
  group('MultiSelectNotifier', () {
    late ProviderContainer container;
    late MultiSelectNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(multiSelectProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('初始状态为空选集', () {
      final state = container.read(multiSelectProvider);
      expect(state.selectedIds, isEmpty);
      expect(state.isMultiSelectMode, isFalse);
    });

    test('toggle 添加未选中的 ID', () {
      notifier.toggle('photo_001');
      final state = container.read(multiSelectProvider);
      expect(state.selectedIds, contains('photo_001'));
      expect(state.isMultiSelectMode, isTrue);
    });

    test('toggle 移除已选中的 ID', () {
      notifier.toggle('photo_001');
      notifier.toggle('photo_001');
      final state = container.read(multiSelectProvider);
      expect(state.selectedIds, isNot(contains('photo_001')));
    });

    test('selectAll 选中所有照片', () {
      notifier.enterMultiSelectMode();
      notifier.selectAll({'photo_001', 'photo_002', 'photo_003'});
      final state = container.read(multiSelectProvider);
      expect(state.selectedIds, {'photo_001', 'photo_002', 'photo_003'});
    });

    test('clearSelection 清空选集但保持多选模式', () {
      notifier.toggle('photo_001');
      notifier.toggle('photo_002');
      notifier.clearSelection();
      final state = container.read(multiSelectProvider);
      expect(state.selectedIds, isEmpty);
      expect(state.isMultiSelectMode, isTrue);
    });

    test('exitMultiSelectMode 退出多选模式并清空选集', () {
      notifier.toggle('photo_001');
      notifier.exitMultiSelectMode();
      final state = container.read(multiSelectProvider);
      expect(state.selectedIds, isEmpty);
      expect(state.isMultiSelectMode, isFalse);
    });

    test('enterMultiSelectMode 进入多选模式', () {
      notifier.enterMultiSelectMode();
      final state = container.read(multiSelectProvider);
      expect(state.isMultiSelectMode, isTrue);
    });

    test('isAllSelected 当全部选中时返回 true', () {
      notifier.enterMultiSelectMode();
      notifier.selectAll({'photo_001', 'photo_002'});
      expect(notifier.isAllSelected({'photo_001', 'photo_002'}), isTrue);
    });

    test('isAllSelected 当部分选中时返回 false', () {
      notifier.enterMultiSelectMode();
      notifier.selectAll({'photo_001', 'photo_002'});
      notifier.toggle('photo_001');
      expect(notifier.isAllSelected({'photo_001', 'photo_002'}), isFalse);
    });
  });
}