import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/data/repositories/photo_repository.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photos_provider.dart';

/// Tests for [PhotosNotifier] — the gallery's reactive view over
/// [PhotoRepository.loadAllFromSystem].
///
/// Behavior contract (CLAUDE.md §1.3 — test defines expected behavior):
/// - `build()` returns an empty initial state (no auto-load — gallery calls
///   `refresh()` on mount). This follows CLAUDE.md §7.5: keep `build()` sync,
///   trigger async work from explicit method calls.
/// - `refresh()` delegates to [PhotoRepository.loadAllFromSystem] and exposes
///   the result via `AsyncValue.data(...)`.
/// - `refresh()` on a thrown error exposes `AsyncValue.error(...)` so the UI
///   can render an error state with retry (M1-T9).
/// - `refresh()` can be called multiple times — each call hits the repository.
class _MockRepo extends Mock implements PhotoRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: <Override>[
        photoRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('PhotosNotifier.build', () {
    test('initial state resolves to empty data (no auto-load)', () async {
      final container = makeContainer();

      // `AsyncNotifier.build()` 是 async，第一帧是 AsyncLoading；
      // await future 等待 build 的 Future 完成 → 拿到 AsyncData([])。
      final value = await container.read(photosProvider.future);

      expect(value, isEmpty);
      verifyNever(() => repo.loadAllFromSystem());
    });
  });

  group('PhotosNotifier.refresh', () {
    test('updates state to AsyncData with loaded photos', () async {
      final photos = <PhotoModel>[
        const PhotoModel(id: 'a', path: '/a'),
        const PhotoModel(id: 'b', path: '/b'),
      ];
      when(() => repo.loadAllFromSystem()).thenAnswer((_) async => photos);

      final container = makeContainer();
      await container.read(photosProvider.notifier).refresh();

      expect(
        container.read(photosProvider),
        AsyncData<List<PhotoModel>>(photos),
      );
      verify(() => repo.loadAllFromSystem()).called(1);
    });

    test('updates state to AsyncError when load throws', () async {
      final err = StateError('load failed');
      when(() => repo.loadAllFromSystem()).thenThrow(err);

      final container = makeContainer();
      await container.read(photosProvider.notifier).refresh();

      final value = container.read(photosProvider);
      expect(value, isA<AsyncError<List<PhotoModel>>>());
      expect(value.error, err);
    });

    test('can be called multiple times (idempotent re-entry)', () async {
      var callIndex = 0;
      when(() => repo.loadAllFromSystem()).thenAnswer((_) async {
        callIndex++;
        return callIndex == 1
            ? const <PhotoModel>[PhotoModel(id: 'a', path: '/a')]
            : const <PhotoModel>[
                PhotoModel(id: 'a', path: '/a'),
                PhotoModel(id: 'b', path: '/b'),
              ];
      });

      final container = makeContainer();
      final notifier = container.read(photosProvider.notifier);

      await notifier.refresh();
      expect(container.read(photosProvider).value, hasLength(1));

      await notifier.refresh();
      expect(container.read(photosProvider).value, hasLength(2));

      verify(() => repo.loadAllFromSystem()).called(2);
    });

    test('refresh after error restores data state', () async {
      var callIndex = 0;
      when(() => repo.loadAllFromSystem()).thenAnswer((_) async {
        callIndex++;
        if (callIndex == 1) {
          throw StateError('boom');
        }
        return const <PhotoModel>[PhotoModel(id: 'a', path: '/a')];
      });

      final container = makeContainer();
      final notifier = container.read(photosProvider.notifier);

      await notifier.refresh();
      expect(
        container.read(photosProvider),
        isA<AsyncError<List<PhotoModel>>>(),
      );

      await notifier.refresh();
      expect(
        container.read(photosProvider),
        const AsyncData<List<PhotoModel>>(<PhotoModel>[
          PhotoModel(id: 'a', path: '/a'),
        ]),
      );
    });
  });
}