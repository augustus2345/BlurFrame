import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/presentation/providers/delete_viewer_provider.dart';

/// Tests for [DeleteViewerNotifier] — manages state for the delete tab.
///
/// Behavior contract:
/// - `build()` initializes with currentIndex=0 and isLoading=false
/// - `initialize(startIndex)` sets currentIndex
/// - `goToPrevious` decrements index (blocked at 0)
/// - `goToNext` increments index (blocked at totalCount-1)
/// - `onDeleted` adjusts index when current exceeds new list bounds
/// - `setLoading` toggles isLoading flag
void main() {
  late ProviderContainer container;
  late DeleteViewerNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(deleteViewerProvider.notifier);
    addTearDown(container.dispose);
  });

  group('DeleteViewerNotifier.build', () {
    test('initial state is currentIndex=0, isLoading=false', () {
      final state = container.read(deleteViewerProvider);
      expect(state.currentIndex, 0);
      expect(state.isLoading, false);
    });
  });

  group('DeleteViewerNotifier.initialize', () {
    test('sets currentIndex to given startIndex', () {
      notifier.initialize(5);
      expect(container.read(deleteViewerProvider).currentIndex, 5);
    });
  });

  group('DeleteViewerNotifier.goToPrevious', () {
    test('decrements currentIndex when > 0', () {
      notifier.initialize(3);
      notifier.goToPrevious(5);
      expect(container.read(deleteViewerProvider).currentIndex, 2);
    });

    test('does nothing when currentIndex is 0', () {
      notifier.initialize(0);
      notifier.goToPrevious(5);
      expect(container.read(deleteViewerProvider).currentIndex, 0);
    });
  });

  group('DeleteViewerNotifier.goToNext', () {
    test('increments currentIndex when < totalCount-1', () {
      notifier.initialize(0);
      notifier.goToNext(5);
      expect(container.read(deleteViewerProvider).currentIndex, 1);
    });

    test('does nothing when currentIndex is at last position', () {
      notifier.initialize(4);
      notifier.goToNext(5);
      expect(container.read(deleteViewerProvider).currentIndex, 4);
    });
  });

  group('DeleteViewerNotifier.onDeleted', () {
    test('clamps index to new last position when index >= newCount', () {
      notifier.initialize(4);
      notifier.onDeleted(4); // deleted the last item, new count=4
      // index 4 is now out of bounds (valid indices 0-3), should clamp to 3
      expect(container.read(deleteViewerProvider).currentIndex, 3);
    });

    test('keeps same index when still within bounds', () {
      notifier.initialize(2);
      notifier.onDeleted(5); // removed item at index 2, but still 5 items
      expect(container.read(deleteViewerProvider).currentIndex, 2);
    });

    test('does nothing when list is empty', () {
      notifier.initialize(0);
      notifier.onDeleted(0);
      expect(container.read(deleteViewerProvider).currentIndex, 0);
    });
  });

  group('DeleteViewerNotifier.setLoading', () {
    test('sets isLoading to true', () {
      notifier.setLoading(true);
      expect(container.read(deleteViewerProvider).isLoading, true);
    });

    test('sets isLoading to false', () {
      notifier.setLoading(true);
      notifier.setLoading(false);
      expect(container.read(deleteViewerProvider).isLoading, false);
    });
  });

  group('DeleteViewerState.copyWith', () {
    test('preserves unchanged fields', () {
      const state = DeleteViewerState(currentIndex: 3, isLoading: true);
      final copy = state.copyWith();
      expect(copy.currentIndex, 3);
      expect(copy.isLoading, true);
    });

    test('updates only currentIndex', () {
      const state = DeleteViewerState(currentIndex: 3, isLoading: false);
      final copy = state.copyWith(currentIndex: 5);
      expect(copy.currentIndex, 5);
      expect(copy.isLoading, false);
    });

    test('updates only isLoading', () {
      const state = DeleteViewerState(currentIndex: 3, isLoading: false);
      final copy = state.copyWith(isLoading: true);
      expect(copy.currentIndex, 3);
      expect(copy.isLoading, true);
    });
  });
}
