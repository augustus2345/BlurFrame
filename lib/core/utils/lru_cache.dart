import 'dart:collection';

/// 基于 [LinkedHashMap] 实现的 LRU（Least Recently Used）缓存。
///
/// 使用 [LinkedHashMap] 的 `moveToEnd` 特性自然维护访问顺序，
/// 淘汰时自动删除最久未使用的条目。
///
/// 类型参数：
/// - [K] 缓存 key（如 `String` assetId）
/// - [V] 缓存 value（如 `Uint8List` 缩略图字节）
class LruCache<K, V> {
  /// 构造带指定容量的 LRU 缓存。
  ///
  /// [maxSize] 必须 > 0，否则抛出 [ArgumentError]。
  LruCache(this.maxSize) {
    if (maxSize <= 0) {
      throw ArgumentError('maxSize must be positive, got $maxSize');
    }
  }

  /// 缓存最大容量（条目数）。
  final int maxSize;

  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  /// 当前缓存条目数。
  int get length => _cache.length;

  /// 缓存是否为空。
  bool get isEmpty => _cache.isEmpty;

  /// 缓存是否已满。
  bool get isFull => _cache.length >= maxSize;

  /// 获取缓存值，同时将对应 key 移到访问顺序尾部（most recently used）。
  ///
  /// 如果 [key] 不存在，返回 `null`。
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      // 重新插入尾部表示最近使用
      _cache[key] = value;
    }
    return value;
  }

  /// 将 [key]-[value] 存入缓存。
  ///
  /// 如果 [key] 已存在，则更新 value 并移到尾部。
  /// 如果缓存已满，淘汰最久未使用的条目（LinkedHashMap 头部）再插入。
  void put(K key, V value) {
    // 先移除旧条目（如果存在），避免重复
    _cache.remove(key);
    if (isFull) {
      // 淘汰最久未使用的条目（map 的第一个条目）
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// 如果 [key] 不存在，则使用 [ifAbsent] 生成值并存入缓存。
  ///
  /// 这是一个便捷的 get-or-compute 操作。
  Future<V> getOrPut(
    K key,
    Future<V> Function() ifAbsent,
  ) async {
    final existing = get(key);
    if (existing != null) return existing;
    final value = await ifAbsent();
    put(key, value);
    return value;
  }

  /// 同步 get-or-compute（如果 loader 是同步的用这个）。
  V getOrPutSync(K key, V Function() ifAbsent) {
    final existing = get(key);
    if (existing != null) return existing;
    final value = ifAbsent();
    put(key, value);
    return value;
  }

  /// 清空所有缓存条目。
  void clear() {
    _cache.clear();
  }

  /// 检查 [key] 是否存在于缓存中（不改变访问顺序）。
  bool containsKey(K key) => _cache.containsKey(key);

  /// 返回缓存中所有 key 的列表（按最近使用顺序，最新在后）。
  List<K> get keys => _cache.keys.toList();

  /// 返回缓存中所有 value 的列表（按最近使用顺序，最新在后）。
  List<V> get values => _cache.values.toList();
}
