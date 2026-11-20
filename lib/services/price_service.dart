import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/gold_price.dart';
import '../api/price_adapter.dart';
import '../api/mock_price_adapter.dart';
import 'storage_service.dart';

/// Bản chụp giá đã lưu để hiển thị ngay khi mở app / khi mất mạng.
class PriceCacheSnapshot {
  final List<GoldPrice> prices;
  final DateTime fetchedAt;

  const PriceCacheSnapshot({required this.prices, required this.fetchedAt});
}

/// Nơi lưu bản chụp giá — tách ra để test PriceService không cần Hive.
abstract class PriceCacheStorage {
  Future<PriceCacheSnapshot?> load();
  Future<void> save(PriceCacheSnapshot snapshot);
}

/// Lưu vào Hive (`priceHistory` box, 1 key JSON). Mọi lỗi (box chưa init,
/// JSON hỏng) đều bị nuốt — cache hỏng thì coi như chưa có cache.
class HivePriceCacheStorage implements PriceCacheStorage {
  static const _key = 'lastPrices';

  @override
  Future<PriceCacheSnapshot?> load() async {
    try {
      final raw = StorageService.priceHistory.get(_key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final prices = (map['prices'] as List)
          .map((e) => GoldPrice.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      return PriceCacheSnapshot(
        prices: prices,
        fetchedAt: DateTime.parse(map['fetchedAt'] as String),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('PriceService: không đọc được cache giá ($e)');
      return null;
    }
  }

  @override
  Future<void> save(PriceCacheSnapshot snapshot) async {
    try {
      await StorageService.putMap(StorageService.priceHistory, _key, {
        'fetchedAt': snapshot.fetchedAt.toIso8601String(),
        'prices': snapshot.prices.map((p) => p.toMap()).toList(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('PriceService: không lưu được cache giá ($e)');
    }
  }
}

/// PriceService - Central service for fetching and caching gold prices.
///
/// Uses the adapter pattern to support multiple price sources.
/// `fetchCurrentPrices` thử adapter đang active trước; nếu lỗi thì gọi mọi
/// adapter còn lại và gộp kết quả (trùng loại vàng thì adapter đăng ký trước
/// thắng). Giá thành công gần nhất được lưu xuống đĩa; nếu mọi nguồn đều lỗi thì vẫn trả giá
/// đã lưu và đánh dấu `stale`.
class PriceService {
  static PriceService? _instance;
  static PriceService get instance =>
      _instance ??= PriceService._(HivePriceCacheStorage());

  PriceService._(this._storage, [DateTime Function()? now])
      : _now = now ?? DateTime.now;

  /// Instance độc lập cho test (không dùng singleton, không đụng Hive).
  @visibleForTesting
  PriceService.forTest({PriceCacheStorage? storage, DateTime Function()? now})
      : _storage = storage,
        _now = now ?? DateTime.now;

  final PriceCacheStorage? _storage;
  final DateTime Function() _now;

  final Map<String, PriceAdapter> _adapters = {};
  PriceAdapter _activeAdapter = MockPriceAdapter();

  // Cache of current prices: goldTypeId -> GoldPrice
  final Map<String, GoldPrice> _priceCache = {};

  // Price history cache: goldTypeId -> List<PriceHistoryEntry>
  final Map<String, List<PriceHistoryEntry>> _historyCache = {};

  PriceSourceStatus _status = PriceSourceStatus.unavailable;
  String _statusMessage = '';
  DateTime? _lastUpdated;
  Future<List<GoldPrice>>? _inFlight;

  /// Current status of the price source
  PriceSourceStatus get status => _status;
  String get statusMessage => _statusMessage;

  /// Thời điểm lấy giá thành công gần nhất (kể cả từ cache đã lưu).
  DateTime? get lastUpdated => _lastUpdated;

  /// Register a new price adapter
  void registerAdapter(PriceAdapter adapter) {
    _adapters[adapter.sourceKey] = adapter;
  }

  /// Set the active price adapter
  void setActiveAdapter(String sourceKey) {
    if (_adapters.containsKey(sourceKey)) {
      _activeAdapter = _adapters[sourceKey]!;
    }
  }

  /// Thứ tự thử: adapter active, rồi các adapter còn lại theo thứ tự đăng ký.
  List<PriceAdapter> get _adapterOrder => [
        _activeAdapter,
        ..._adapters.values.where((a) => a.sourceKey != _activeAdapter.sourceKey),
      ];

  /// Nạp giá đã lưu vào cache (gọi 1 lần lúc khởi động, trước lần fetch đầu)
  /// để UI có số ngay. Không làm gì nếu đã có giá trong cache.
  Future<void> loadCachedPrices() async {
    if (_priceCache.isNotEmpty) return;
    final snapshot = await _storage?.load();
    if (snapshot == null || snapshot.prices.isEmpty) return;
    for (final price in snapshot.prices) {
      _priceCache[price.goldTypeId] = price;
    }
    _lastUpdated = snapshot.fetchedAt;
    _markStale();
  }

  /// Fetch current prices (adapter active → fallback) and update cache.
  /// Gọi chồng nhau sẽ dùng chung 1 lần fetch đang chạy.
  Future<List<GoldPrice>> fetchCurrentPrices() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<List<GoldPrice>> _fetch() async {
    if (_priceCache.isEmpty) {
      _status = PriceSourceStatus.unavailable;
      _statusMessage = 'Đang tải giá...';
    }

    final order = _adapterOrder;

    // Nguồn chính phủ đủ mọi loại vàng — thành công thì không cần hỏi thêm.
    final primary = await _tryFetch(order.first);
    if (primary.isNotEmpty) return _accept(primary);

    // Nguồn chính lỗi: hỏi song song mọi nguồn dự phòng rồi gộp lại, vì mỗi
    // nguồn dự phòng chỉ có một phần các loại vàng (SJC, PNJ, Worker...).
    // Trùng loại thì nguồn đăng ký trước thắng.
    final results = await Future.wait(order.skip(1).map(_tryFetch));
    final merged = <String, GoldPrice>{};
    for (final prices in results) {
      for (final price in prices) {
        merged.putIfAbsent(price.goldTypeId, () => price);
      }
    }
    if (merged.isNotEmpty) return _accept(merged.values.toList());

    // Mọi nguồn đều thất bại.
    if (_priceCache.isNotEmpty) {
      _markStale();
    } else {
      _status = PriceSourceStatus.error;
      _statusMessage = 'Không tải được giá vàng, kiểm tra mạng rồi kéo xuống để thử lại';
    }
    return getAllPrices();
  }

  /// Gọi 1 adapter; lỗi / không khả dụng / rỗng đều trả list rỗng.
  Future<List<GoldPrice>> _tryFetch(PriceAdapter adapter) async {
    try {
      if (!await adapter.isAvailable()) return const [];
      return await adapter.fetchPrices();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PriceService: nguồn ${adapter.sourceKey} lỗi: $e');
      }
      return const [];
    }
  }

  /// Ghi giá mới vào cache (loại nào nguồn không có thì giữ giá cũ), đánh
  /// dấu fresh và lưu xuống đĩa.
  List<GoldPrice> _accept(List<GoldPrice> prices) {
    for (final price in prices) {
      _priceCache[price.goldTypeId] = price;
    }
    _lastUpdated = _now();
    _status = PriceSourceStatus.fresh;
    _statusMessage = 'Đã cập nhật giá vàng';
    // Lưu nền — lỗi ghi đĩa không ảnh hưởng kết quả fetch.
    _storage?.save(PriceCacheSnapshot(
      prices: _priceCache.values.toList(),
      fetchedAt: _lastUpdated!,
    ));
    return prices;
  }

  void _markStale() {
    _status = PriceSourceStatus.stale;
    final at = _lastUpdated;
    _statusMessage = at == null
        ? 'Đang dùng giá đã lưu (chưa kết nối được)'
        : 'Đang dùng giá đã lưu lúc ${DateFormat('HH:mm dd/MM').format(at)} (chưa kết nối được)';
  }

  /// Get cached price for a specific gold type
  GoldPrice? getPrice(String goldTypeId) {
    return _priceCache[goldTypeId];
  }

  /// Get all cached prices
  List<GoldPrice> getAllPrices() {
    return _priceCache.values.toList();
  }

  /// Get the current buy price (per luong) for a gold type.
  /// This is the price the shop would pay you (your sell price).
  double? getBuyPrice(String goldTypeId) {
    return _priceCache[goldTypeId]?.buyPrice;
  }

  /// Get the current sell price (per luong) for a gold type.
  /// This is the price the shop charges you (your buy price).
  double? getSellPrice(String goldTypeId) {
    return _priceCache[goldTypeId]?.sellPrice;
  }

  /// Fetch price history for charts
  Future<List<PriceHistoryEntry>> fetchPriceHistory(
    String goldTypeId, {
    int days = 30,
  }) async {
    // Check cache first
    final cacheKey = '${goldTypeId}_${days}';
    if (_historyCache.containsKey(cacheKey)) {
      return _historyCache[cacheKey]!;
    }

    try {
      final history =
          await _activeAdapter.fetchPriceHistory(goldTypeId, days: days);
      _historyCache[cacheKey] = history;
      return history;
    } catch (e) {
      return [];
    }
  }

  /// Get all registered adapter source keys
  List<String> get availableSources => _adapters.keys.toList();

  /// Get the active adapter's display name
  String get activeSourceName => _activeAdapter.displayName;
}
