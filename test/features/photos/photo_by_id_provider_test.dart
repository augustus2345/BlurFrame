import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/features/photos/data/models/photo_model.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photo_by_id_provider.dart';
import 'package:photo_beauty/features/photos/presentation/providers/photos_provider.dart';

import '../../test_utils/test_photo_fixtures.dart';

/// Tests for [photoByIdProvider] — the detail-page's single-photo lookup.
class _StubPhotosNotifier extends PhotosNotifier {
  _StubPhotosNotifier(this._data, {AsyncValue<List<PhotoModel>>? initialState})
      : _initialState = initialState;

  final List<PhotoModel> _data;
  final AsyncValue<List<PhotoModel>>? _initialState;

  @override
  Future<List<PhotoModel>> build() async => _data;

  @override
  AsyncValue<List<PhotoModel>> get state =>
      _initialState ?? AsyncValue<List<PhotoModel>>.data(_data);
}

void main() {
  final photos = TestPhotoFixtures.photos(count: 3);

  group('photoByIdProvider', () {
    test('returns matching PhotoModel when id is in the gallery list',
        () async {
      final container = ProviderContainer(
        overrides: <Override>[
          photosProvider.overrideWith(() => _StubPhotosNotifier(photos)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(photosProvider.future);
      final result = container.read(photoByIdProvider('photo_001'));

      expect(result, isNotNull);
      expect(result!.id, 'photo_001');
      expect(result.path, '/DCIM/IMG_0001.jpg');
    });

    test('returns null when id is not in the gallery list', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          photosProvider.overrideWith(() => _StubPhotosNotifier(photos)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(photosProvider.future);
      final result = container.read(photoByIdProvider('photo_999'));

      expect(result, isNull);
    });

    test('returns null when gallery state is loading', () {
      final container = ProviderContainer(
        overrides: <Override>[
          photosProvider.overrideWith(
            () => _StubPhotosNotifier(
              photos,
              initialState: const AsyncValue<List<PhotoModel>>.loading(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(photoByIdProvider('photo_001'));

      expect(result, isNull);
    });
  });
}
