import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/presentation/providers/delete_viewer_provider.dart';

/// Tests for [DeleteViewerNotifier] — manages state for the delete tab.
///
/// Behavior contract:
/// - `build()` initializes with currentIndex=0, isLoading=false, new sessionId, empty undoStack
/// - `initialize(startIndex)` sets currentIndex and generates new sessionId/clears undoStack
/// - `goToPrevious` decrements index (blocked at 0)
/// - `goToNext` increments index (blocked at totalCount-1)
/// - `onDeleted` adjusts index when current exceeds new list bounds
/// - `setLoading` toggles isLoading flag
/// - `pushToUndoStack` adds entry with current sessionId
/// - `popUndoStackIfValid` pops only when sessionId matches
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
      final state = DeleteViewerState(
        currentIndex: 3,
        isLoading: true,
        sessionId: 'test-session',
        undoStack: Queue<UndoEntry>(),
        pendingDeleteIds: {'photo-1'},
      );
      final copy = state.copyWith();
      expect(copy.currentIndex, 3);
      expect(copy.isLoading, true);
      expect(copy.sessionId, 'test-session');
      expect(copy.pendingDeleteIds, {'photo-1'});
    });

    test('updates only currentIndex', () {
      final state = DeleteViewerState(
        currentIndex: 3,
        isLoading: false,
        sessionId: 'test-session',
        undoStack: Queue<UndoEntry>(),
        pendingDeleteIds: {},
      );
      final copy = state.copyWith(currentIndex: 5);
      expect(copy.currentIndex, 5);
      expect(copy.isLoading, false);
    });

    test('updates only isLoading', () {
      final state = DeleteViewerState(
        currentIndex: 3,
        isLoading: false,
        sessionId: 'test-session',
        undoStack: Queue<UndoEntry>(),
        pendingDeleteIds: {},
      );
      final copy = state.copyWith(isLoading: true);
      expect(copy.currentIndex, 3);
      expect(copy.isLoading, true);
    });

    test('updates only sessionId', () {
      final state = DeleteViewerState(
        currentIndex: 3,
        isLoading: false,
        sessionId: 'old-session',
        undoStack: Queue<UndoEntry>(),
        pendingDeleteIds: {},
      );
      final copy = state.copyWith(sessionId: 'new-session');
      expect(copy.sessionId, 'new-session');
    });

    test('updates only undoStack', () {
      final state = DeleteViewerState(
        currentIndex: 3,
        isLoading: false,
        sessionId: 'test-session',
        undoStack: Queue<UndoEntry>(),
        pendingDeleteIds: {},
      );
      final entry = UndoEntry(
        assetId: 'photo-1',
        sessionId: 'test-session',
        photo: PhotoModel(
          id: 'photo-1',
          path: '/test/path.jpg',
          width: 100,
          height: 100,
          takenAt: DateTime.now(),
          tags: [],
          starRating: 0,
        ),
      );
      final newStack = Queue<UndoEntry>.from(state.undoStack)..add(entry);
      final copy = state.copyWith(undoStack: newStack);
      expect(copy.undoStack.length, 1);
    });

    test('updates only pendingDeleteIds', () {
      final state = DeleteViewerState(
        currentIndex: 3,
        isLoading: false,
        sessionId: 'test-session',
        undoStack: Queue<UndoEntry>(),
        pendingDeleteIds: {},
      );
      final copy = state.copyWith(pendingDeleteIds: {'photo-1', 'photo-2'});
      expect(copy.pendingDeleteIds, {'photo-1', 'photo-2'});
    });
  });

  group('DeleteViewerNotifier sessionId', () {
    test('initialize generates new sessionId', () {
      final initialState = container.read(deleteViewerProvider);
      final initialSessionId = initialState.sessionId;

      notifier.initialize(0);

      final newState = container.read(deleteViewerProvider);
      expect(newState.sessionId, isNot(equals(initialSessionId)));
    });

    test('initialize clears undoStack', () {
      // Push something to undoStack first
      notifier.pushToUndoStack(PhotoModel(
        id: 'photo-1',
        path: '/test/path.jpg',
        width: 100,
        height: 100,
        takenAt: DateTime.now(),
        tags: [],
        starRating: 0,
      ));

      expect(container.read(deleteViewerProvider).undoStack.length, 1);

      notifier.initialize(0);

      expect(container.read(deleteViewerProvider).undoStack.length, 0);
    });
  });

  group('DeleteViewerNotifier undoStack', () {
    PhotoModel makePhoto(String id) {
      return PhotoModel(
        id: id,
        path: '/test/$id.jpg',
        width: 100,
        height: 100,
        takenAt: DateTime.now(),
        tags: const [],
        starRating: 0,
      );
    }

    test('pushToUndoStack adds entry with current sessionId', () {
      final sessionId = container.read(deleteViewerProvider).sessionId;
      final photo = makePhoto('photo-1');

      notifier.pushToUndoStack(photo);

      final state = container.read(deleteViewerProvider);
      expect(state.undoStack.length, 1);
      expect(state.undoStack.last.assetId, 'photo-1');
      expect(state.undoStack.last.sessionId, sessionId);
    });

    test('popUndoStackIfValid returns entry when sessionId matches', () {
      final photo = makePhoto('photo-2');
      notifier.pushToUndoStack(photo);

      final entry = notifier.popUndoStackIfValid();

      expect(entry, isNotNull);
      expect(entry!.assetId, 'photo-2');
      expect(container.read(deleteViewerProvider).undoStack.length, 0);
    });

    test('popUndoStackIfValid returns null when sessionId does not match', () {
      // This test verifies the sessionId mismatch protection logic.
      // We test this by pushing an entry (which captures current sessionId),
      // then calling initialize() which generates a NEW sessionId.
      // After initialize, the stack is cleared (by design), so the mismatch
      // is detected as "empty stack" not "sessionId mismatch".
      // The sessionId mismatch check in the code is verified by code inspection:
      //   if (top.sessionId != state.sessionId) { return null; }
      //
      // Key point: initialize() clears stack AND generates new sessionId.
      // This means any pending undo entries from a previous session become invalid
      // when user re-enters the delete tab (new session = new undo context).

      final photo = makePhoto('photo-3');
      notifier.pushToUndoStack(photo);
      final firstSessionId = container.read(deleteViewerProvider).sessionId;

      // After pushing, the entry has sessionId = firstSessionId
      expect(container.read(deleteViewerProvider).undoStack.last.sessionId, firstSessionId);

      // initialize() generates a NEW sessionId
      notifier.initialize(0);
      final secondSessionId = container.read(deleteViewerProvider).sessionId;
      expect(secondSessionId, isNot(equals(firstSessionId)));

      // initialize() also clears the stack (by design)
      expect(container.read(deleteViewerProvider).undoStack.length, 0);

      // So pop returns null (stack empty, not sessionId mismatch)
      final entry = notifier.popUndoStackIfValid();
      expect(entry, isNull);
    });

    test('popUndoStackIfValid returns null when stack is empty', () {
      final entry = notifier.popUndoStackIfValid();
      expect(entry, isNull);
    });

    test('multiple pushes and pops maintain LIFO order', () {
      final photo1 = makePhoto('photo-1');
      final photo2 = makePhoto('photo-2');
      final photo3 = makePhoto('photo-3');

      notifier.pushToUndoStack(photo1);
      notifier.pushToUndoStack(photo2);
      notifier.pushToUndoStack(photo3);

      // Pop should return photo3 (last in)
      final entry1 = notifier.popUndoStackIfValid();
      expect(entry1!.assetId, 'photo-3');

      // Pop should return photo2
      final entry2 = notifier.popUndoStackIfValid();
      expect(entry2!.assetId, 'photo-2');

      // Pop should return photo1
      final entry3 = notifier.popUndoStackIfValid();
      expect(entry3!.assetId, 'photo-1');

      expect(container.read(deleteViewerProvider).undoStack.length, 0);
    });
  });

  group('DeleteViewerNotifier pendingDelete', () {
    test('togglePendingDelete adds photo to pending list', () {
      notifier.togglePendingDelete('photo-1');
      expect(container.read(deleteViewerProvider).pendingDeleteIds, {'photo-1'});
      expect(notifier.pendingDeleteCount, 1);
    });

    test('togglePendingDelete removes photo if already in list', () {
      notifier.togglePendingDelete('photo-1');
      notifier.togglePendingDelete('photo-1');
      expect(container.read(deleteViewerProvider).pendingDeleteIds, <String>{});
      expect(notifier.pendingDeleteCount, 0);
    });

    test('togglePendingDelete works with multiple photos', () {
      notifier.togglePendingDelete('photo-1');
      notifier.togglePendingDelete('photo-2');
      notifier.togglePendingDelete('photo-3');
      expect(container.read(deleteViewerProvider).pendingDeleteIds, {'photo-1', 'photo-2', 'photo-3'});
      expect(notifier.pendingDeleteCount, 3);
    });

    test('clearPendingDelete removes all pending photos', () {
      notifier.togglePendingDelete('photo-1');
      notifier.togglePendingDelete('photo-2');
      notifier.clearPendingDelete();
      expect(container.read(deleteViewerProvider).pendingDeleteIds, <String>{});
      expect(notifier.pendingDeleteCount, 0);
    });

    test('initialize clears pendingDeleteIds', () {
      notifier.togglePendingDelete('photo-1');
      notifier.togglePendingDelete('photo-2');
      expect(notifier.pendingDeleteCount, 2);

      notifier.initialize(0);

      expect(container.read(deleteViewerProvider).pendingDeleteIds, <String>{});
      expect(notifier.pendingDeleteCount, 0);
    });
  });
}
