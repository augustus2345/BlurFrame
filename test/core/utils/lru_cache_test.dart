import 'package:flutter_test/flutter_test.dart';
import 'package:photo_beauty/core/utils/lru_cache.dart';

void main() {
  group('LruCache basic operations', () {
    test('get on empty cache returns null', () {
      final cache = LruCache<String, int>(3);
      expect(cache.get('nonexistent'), isNull);
    });

    test('put and get returns the value', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      expect(cache.get('a'), 1);
    });

    test('get moves key to end (most recently used)', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      // Access 'a' (should become most recently used)
      cache.get('a');
      // Add 'd' - should evict 'b' (least recently used)
      cache.put('d', 4);
      // 'a' should still be there (was accessed after 'b' and 'c')
      expect(cache.containsKey('a'), isTrue);
      // 'b' should be evicted
      expect(cache.containsKey('b'), isFalse);
    });

    test('put with existing key updates value and moves to end', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      // Update 'a' — it moves to end (most recently used)
      // Cache still has size=2, no eviction since maxSize=3
      cache.put('a', 10);
      expect(cache.get('a'), 10);
      // 'b' is still present (was LRU but we never hit capacity)
      expect(cache.containsKey('b'), isTrue);
      // Now add 'c' — still size=2, no eviction
      cache.put('c', 3);
      expect(cache.containsKey('b'), isTrue);
      // Add 'd' — hits capacity 3, should evict LRU ('b')
      cache.put('d', 4);
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.containsKey('d'), isTrue);
    });

    test('eviction removes least recently used (first inserted)', () {
      final cache = LruCache<int, int>(3);
      cache.put(1, 100);
      cache.put(2, 200);
      cache.put(3, 300);
      // Adding 4th item should evict key 1
      cache.put(4, 400);
      expect(cache.containsKey(1), isFalse);
      expect(cache.containsKey(2), isTrue);
      expect(cache.containsKey(3), isTrue);
      expect(cache.containsKey(4), isTrue);
    });

    test('isFull returns true when at capacity', () {
      final cache = LruCache<String, int>(2);
      expect(cache.isFull, isFalse);
      cache.put('a', 1);
      expect(cache.isFull, isFalse);
      cache.put('b', 2);
      expect(cache.isFull, isTrue);
    });

    test('clear removes all items', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.clear();
      expect(cache.isEmpty, isTrue);
      expect(cache.length, 0);
    });

    test('length returns correct count', () {
      final cache = LruCache<String, int>(5);
      expect(cache.length, 0);
      cache.put('a', 1);
      expect(cache.length, 1);
      cache.put('b', 2);
      expect(cache.length, 2);
    });

    test('keys and values return in LRU order (oldest first)', () {
      final cache = LruCache<String, int>(5);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      expect(cache.keys, ['a', 'b', 'c']);
      expect(cache.values, [1, 2, 3]);
    });

    test('keys returns most recently used last after get', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      cache.get('a'); // Access 'a' to make it most recent
      expect(cache.keys, ['b', 'c', 'a']);
    });
  });

  group('LruCache getOrPut', () {
    test('getOrPut returns existing value without calling factory', () async {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      var factoryCalls = 0;
      final result = await cache.getOrPut('a', () async {
        factoryCalls++;
        return 99;
      });
      expect(result, 1); // Returns cached value
      expect(factoryCalls, 0); // Factory not called
    });

    test('getOrPut computes and stores value on cache miss', () async {
      final cache = LruCache<String, int>(3);
      var factoryCalls = 0;
      final result = await cache.getOrPut('a', () async {
        factoryCalls++;
        return 42;
      });
      expect(result, 42);
      expect(factoryCalls, 1);
      expect(cache.get('a'), 42); // Also stored in cache
    });
  });

  group('LruCache getOrPutSync', () {
    test('getOrPutSync returns existing value without calling factory', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      var factoryCalls = 0;
      final result = cache.getOrPutSync('a', () {
        factoryCalls++;
        return 99;
      });
      expect(result, 1);
      expect(factoryCalls, 0);
    });

    test('getOrPutSync computes and stores value on cache miss', () {
      final cache = LruCache<String, int>(3);
      var factoryCalls = 0;
      final result = cache.getOrPutSync('a', () {
        factoryCalls++;
        return 42;
      });
      expect(result, 42);
      expect(factoryCalls, 1);
      expect(cache.get('a'), 42);
    });
  });

  group('LruCache constructor validation', () {
    test('maxSize <= 0 throws ArgumentError', () {
      expect(() => LruCache<String, int>(0), throwsArgumentError);
      expect(() => LruCache<String, int>(-1), throwsArgumentError);
    });
  });

  group('LruCache isEmpty / isFull', () {
    test('isEmpty returns true when cache is empty', () {
      final cache = LruCache<String, int>(3);
      expect(cache.isEmpty, isTrue);
    });

    test('isEmpty returns false when cache has items', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      expect(cache.isEmpty, isFalse);
    });
  });
}
