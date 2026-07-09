import '../models/gold_price.dart';
import '../api/price_adapter.dart';
import '../api/mock_price_adapter.dart';

/// PriceService - Central service for fetching and caching gold prices.
///
/// Uses the adapter pattern to support multiple price sources.
/// Currently uses MockPriceAdapter for development; real API adapters
/// can be registered via registerAdapter() without changing the service.
class PriceService {
  static PriceService? _instance;
  static PriceService get instance => _instance ??= PriceService._();

  PriceService._();

  final Map<String, PriceAdapter> _adapters = {};
  PriceAdapter _activeAdapter = MockPriceAdapter();

  // Cache of current prices: goldTypeId -> GoldPrice
  final Map<String, GoldPrice> _priceCache = {};

  // Price history cache: goldTypeId -> List<PriceHistoryEntry>
  final Map<String, List<PriceHistoryEntry>> _historyCache = {};

  PriceSourceStatus _status = PriceSourceStatus.unavailable;
  String _statusMessage = '';

  /// Current status of the price source
  PriceSourceStatus get status => _status;
  String get statusMessage => _statusMessage;

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

  /// Fetch current prices from the active adapter and update cache.
  Future<List<GoldPrice>> fetchCurrentPrices() async {
    try {
      _status = PriceSourceStatus.unavailable;
      _statusMessage = 'Đang tải giá...';

      final available = await _activeAdapter.isAvailable();
      if (!available) {
        _status = PriceSourceStatus.unavailable;
        _statusMessage = 'Nguồn giá không khả dụng';
        return [];
      }

      final prices = await _activeAdapter.fetchPrices();

      // Update cache
      for (final price in prices) {
        _priceCache[price.goldTypeId] = price;
      }

      _status = PriceSourceStatus.fresh;
      _statusMessage = 'Đã cập nhật giá vàng';

      return prices;
    } catch (e) {
      _status = PriceSourceStatus.error;
      _statusMessage = 'Lỗi khi tải giá: $e';
      return [];
    }
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
