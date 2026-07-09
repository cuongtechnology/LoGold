import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_holding.dart';
import '../models/gold_type.dart';
import '../models/gold_price.dart';
import '../models/price_alert.dart';
import '../models/historical_gold_price.dart';
import '../api/price_adapter.dart';
import '../services/portfolio_service.dart';
import '../services/price_service.dart';
import '../services/notification_service.dart';
import '../services/historical_price_service.dart';
import '../services/profit_loss_calculator.dart';
import '../services/push_notification_service.dart';
import '../services/review_service.dart';
import '../services/storage_service.dart';

/// AppStore - Central state management using Provider ChangeNotifier.
/// Manages all app state: holdings, prices, alerts, settings.
class AppStore extends ChangeNotifier {
  // Settings keys trong Hive settings box.
  static const _kOnboarded = 'onboarded';
  static const _kPrivacyMode = 'privacyMode';
  static const _kPinEnabled = 'pinEnabled';
  static const _kPin = 'pin';

  // Services
  final _portfolio = PortfolioService.instance;
  final _priceService = PriceService.instance;
  final _notificationService = NotificationService.instance;
  final _historicalPriceService = HistoricalPriceService.instance;
  final _pushNotificationService = PushNotificationService.instance;
  final _reviewService = ReviewService.instance;

  // State
  bool _isOnboarded = false;
  bool _privacyMode = false; // hide actual amounts
  bool _pinEnabled = false;
  String _pin = '';
  bool _isLoading = false;
  String _loadingMessage = '';

  // Cached data
  List<UserHolding> _holdings = [];
  List<GoldType> _goldTypes = [];
  List<GoldPrice> _prices = [];
  PortfolioSummary? _portfolioSummary;

  // Getters
  bool get isOnboarded => _isOnboarded;
  bool get privacyMode => _privacyMode;
  bool get pinEnabled => _pinEnabled;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  List<UserHolding> get holdings => _holdings;
  List<UserHolding> get activeHoldings =>
      _holdings.where((h) => h.status == 'holding').toList();
  List<GoldType> get goldTypes => _goldTypes;
  List<GoldPrice> get prices => _prices;
  PortfolioSummary? get portfolioSummary => _portfolioSummary;
  List<PriceAlert> get alerts => _notificationService.alerts;
  List<AppNotification> get notifications => _notificationService.notifications;
  PriceSourceStatus get priceStatus => _priceService.status;
  String get priceStatusMessage => _priceService.statusMessage;
  /// Series lịch sử SJC (loại vàng chính, tải sẵn lúc app khởi động).
  List<HistoricalPricePoint> get historicalPrices =>
      _historicalPriceService.seriesFor('sjc');
  String get historicalPriceStatusMessage =>
      _historicalPriceService.statusMessageFor('sjc');

  /// Series lịch sử cho 1 loại vàng bất kỳ — chỉ SJC được tải sẵn lúc khởi
  /// động, loại khác cần gọi `loadHistoricalPricesFor` trước (xem
  /// `price_table_screen.dart`).
  List<HistoricalPricePoint> historicalPricesFor(String goldTypeId) =>
      _historicalPriceService.seriesFor(goldTypeId);
  String historicalPriceStatusMessageFor(String goldTypeId) =>
      _historicalPriceService.statusMessageFor(goldTypeId);
  bool get isPushNotificationReady => _pushNotificationService.isReady;
  String get pushNotificationStatusMessage =>
      _pushNotificationService.statusMessage;

  /// Initialize the app. Yêu cầu `StorageService.init()` đã chạy xong.
  Future<void> init() async {
    _setLoading(true, 'Đang tải dữ liệu...');

    _loadSettings();

    await _portfolio.init();
    await _notificationService.init();

    _goldTypes = _portfolio.goldTypes;
    _holdings = _portfolio.allHoldings;

    await refreshPrices();
    _updatePortfolioSummary();

    _setLoading(false);
    notifyListeners();

    // Không chặn startup vì dữ liệu lịch sử chỉ phục vụ phân tích/so sánh,
    // không cần thiết cho các màn hình chính. Xong sẽ tự notifyListeners.
    unawaited(loadHistoricalPrices());

    // Ghi nhận lần mở đầu tiên + xin đánh giá nếu đủ điều kiện (xem
    // ReviewService — chỉ hỏi sau vài ngày dùng + có vài vị thế, không hỏi
    // ngay lúc mở app lần đầu).
    unawaited(_reviewService.recordFirstOpenIfNeeded());
    unawaited(
      _reviewService.maybeRequestReview(
        activeHoldingCount: activeHoldings.length,
      ),
    );
  }

  /// Tải series giá SJC lịch sử (dùng cho phân tích/so sánh + meme).
  Future<void> loadHistoricalPrices({bool forceRefresh = false}) async {
    await _historicalPriceService.load('sjc', forceRefresh: forceRefresh);
    notifyListeners();
  }

  /// Tải series lịch sử cho 1 loại vàng bất kỳ (Bảng giá khi chọn ngày quá
  /// khứ). An toàn gọi nhiều lần — service tự cache theo từng loại.
  Future<void> loadHistoricalPricesFor(
    String goldTypeId, {
    bool forceRefresh = false,
  }) async {
    await _historicalPriceService.load(goldTypeId, forceRefresh: forceRefresh);
    notifyListeners();
  }

  void _loadSettings() {
    _isOnboarded = StorageService.getSetting<bool>(_kOnboarded) ?? false;
    _privacyMode = StorageService.getSetting<bool>(_kPrivacyMode) ?? false;
    _pinEnabled = StorageService.getSetting<bool>(_kPinEnabled) ?? false;
    _pin = StorageService.getSetting<String>(_kPin) ?? '';
  }

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    _isOnboarded = true;
    await StorageService.putSetting(_kOnboarded, true);
    notifyListeners();
  }

  /// Toggle privacy mode
  Future<void> togglePrivacyMode() async {
    _privacyMode = !_privacyMode;
    await StorageService.putSetting(_kPrivacyMode, _privacyMode);
    notifyListeners();
  }

  /// Enable/disable PIN lock
  Future<void> setPinEnabled(bool enabled, {String pin = ''}) async {
    _pinEnabled = enabled;
    _pin = pin;
    await StorageService.putSetting(_kPinEnabled, enabled);
    await StorageService.putSetting(_kPin, pin);
    notifyListeners();
  }

  /// Kiểm tra PIN nhập vào có khớp PIN đã lưu không — dùng bởi `LockScreen`.
  bool verifyPin(String pin) => _pinEnabled && pin.isNotEmpty && pin == _pin;

  /// Refresh gold prices from the active source
  Future<void> refreshPrices() async {
    _prices = await _priceService.fetchCurrentPrices();
    _updatePortfolioSummary();
    notifyListeners();
  }

  /// Add a new gold purchase
  Future<void> addHolding({
    required String goldTypeId,
    required double quantity,
    required String unit,
    required double buyPricePerUnit,
    double fee = 0,
    required DateTime buyDate,
    String? note,
  }) async {
    await _portfolio.addHolding(
      goldTypeId: goldTypeId,
      quantity: quantity,
      unit: unit,
      buyPricePerUnit: buyPricePerUnit,
      fee: fee,
      buyDate: buyDate,
      note: note,
    );
    _holdings = _portfolio.allHoldings;
    _updatePortfolioSummary();
    notifyListeners();
  }

  /// Update an existing holding
  Future<void> updateHolding(UserHolding holding) async {
    await _portfolio.updateHolding(holding);
    _holdings = _portfolio.allHoldings;
    _updatePortfolioSummary();
    notifyListeners();
  }

  /// Delete a holding
  Future<void> deleteHolding(String id) async {
    await _portfolio.deleteHolding(id);
    _holdings = _portfolio.allHoldings;
    _updatePortfolioSummary();
    notifyListeners();
  }

  /// Mark a holding as sold
  Future<void> markAsSold(String id) async {
    await _portfolio.markAsSold(id);
    _holdings = _portfolio.allHoldings;
    _updatePortfolioSummary();
    notifyListeners();
  }

  /// Duplicate a holding
  Future<void> duplicateHolding(String id) async {
    await _portfolio.duplicateHolding(id);
    _holdings = _portfolio.allHoldings;
    _updatePortfolioSummary();
    notifyListeners();
  }

  /// Add a price alert
  Future<void> addAlert(PriceAlert alert) async {
    await _notificationService.addAlert(alert);
    notifyListeners();
  }

  /// Remove a price alert
  Future<void> removeAlert(String id) async {
    await _notificationService.removeAlert(id);
    notifyListeners();
  }

  /// Toggle alert enabled
  Future<void> toggleAlert(String id) async {
    await _notificationService.toggleAlert(id);
    notifyListeners();
  }

  /// Get the current buy price for a gold type
  double? getBuyPrice(String goldTypeId) {
    return _priceService.getBuyPrice(goldTypeId);
  }

  /// Get a gold type by ID
  GoldType? getGoldType(String id) => _portfolio.getGoldType(id);

  /// Get P/L result for a specific holding
  ProfitLossResult? getHoldingResult(String holdingId) {
    try {
      return _portfolio.getHoldingResult(holdingId);
    } catch (e) {
      return null;
    }
  }

  /// Holdings sorted by P/L% ascending (deepest loss first).
  /// Only "holding" status is included; entries without a live price fall back
  /// to break-even (buyPricePerLuong) so they sort as ~0% and appear near
  /// the middle instead of blowing up the list.
  List<ProfitLossResult> get topLosers {
    final summary = _portfolioSummary;
    if (summary == null) return const [];
    final list = [...summary.holdings];
    list.sort(
      (a, b) => a.profitLossPercent.compareTo(b.profitLossPercent),
    );
    return list;
  }

  void _updatePortfolioSummary() {
    _portfolioSummary = _portfolio.getPortfolioSummary();

    // Check alerts
    if (_portfolioSummary != null) {
      final priceChanges = <String, double>{};
      for (final price in _prices) {
        priceChanges[price.goldTypeId] = price.buyPriceChange;
      }
      _notificationService.checkAlerts(
        summary: _portfolioSummary!,
        priceChanges: priceChanges,
      );
    }
  }

  void _setLoading(bool loading, [String message = '']) {
    _isLoading = loading;
    _loadingMessage = message;
  }
}
