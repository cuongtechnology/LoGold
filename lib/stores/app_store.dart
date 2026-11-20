import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_holding.dart';
import '../models/gold_type.dart';
import '../models/gold_price.dart';
import '../models/price_alert.dart';
import '../models/historical_gold_price.dart';
import '../api/price_adapter.dart';
import '../services/backup_codec.dart';
import '../services/portfolio_service.dart';
import '../services/price_service.dart';
import '../services/notification_service.dart';
import '../services/historical_price_service.dart';
import '../services/profit_loss_calculator.dart';
import '../services/push_notification_service.dart';
import '../services/review_service.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';
import '../utils/pin_security.dart';

/// AppStore - Central state management using Provider ChangeNotifier.
/// Manages all app state: holdings, prices, alerts, settings.
class AppStore extends ChangeNotifier {
  // Settings keys trong Hive settings box.
  static const _kOnboarded = 'onboarded';
  static const _kPrivacyMode = 'privacyMode';
  static const _kPinEnabled = 'pinEnabled';
  // `pin` (plaintext) chỉ còn là key legacy — đọc để migrate rồi xoá.
  static const _kLegacyPin = 'pin';
  static const _kPinSalt = 'pinSalt';
  static const _kPinHash = 'pinHash';
  static const _kPinIterations = 'pinIterations';
  static const _kPinFailCount = 'pinFailCount';
  static const _kPinBlockedUntil = 'pinBlockedUntil'; // epoch ms
  static const _kBiometricEnabled = 'biometricEnabled';

  // Services
  final _portfolio = PortfolioService.instance;
  final _priceService = PriceService.instance;
  final _notificationService = NotificationService.instance;
  final _historicalPriceService = HistoricalPriceService.instance;
  final _pushNotificationService = PushNotificationService.instance;
  final _reviewService = ReviewService.instance;
  final _biometric = BiometricService.instance;

  // State
  bool _isOnboarded = false;
  bool _privacyMode = false; // hide actual amounts
  bool _pinEnabled = false;
  PinCredential? _pinCredential;
  int _pinFailCount = 0;
  int? _pinBlockedUntilMs;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
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
  bool get biometricEnabled => _pinEnabled && _biometricEnabled;
  bool get biometricAvailable => _biometricAvailable;

  /// Thời gian còn bị khoá do nhập sai PIN nhiều lần (zero nếu không bị khoá).
  Duration get pinBlockRemaining =>
      PinLockout.remaining(_pinBlockedUntilMs, DateTime.now());

  /// Hộp thoại sinh trắc đang hiện — `main.dart` dùng để không tự khoá app.
  bool get isBiometricPromptActive => _biometric.isPromptActive;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  List<UserHolding> get holdings => _holdings;
  List<UserHolding> get activeHoldings =>
      _holdings.where((h) => h.status == 'holding').toList();
  /// Holdings đã bán, mới bán nhất lên đầu.
  List<UserHolding> get soldHoldings {
    final list = _holdings.where((h) => h.status == 'sold').toList();
    DateTime when(UserHolding h) => h.sellDate ?? h.updatedAt;
    list.sort((a, b) => when(b).compareTo(when(a)));
    return list;
  }

  /// Tổng lãi/lỗ đã chốt (chỉ tính holding đã bán có ghi giá bán).
  RealizedSummary get realizedSummary =>
      ProfitLossCalculator.calculateRealizedSummary(_holdings);
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
    unawaited(refreshBiometricAvailability());

    await _portfolio.init();
    await _notificationService.init();

    _goldTypes = _portfolio.goldTypes;
    _holdings = _portfolio.allHoldings;
    // Bắn ngay ở đây — không đợi `refreshPrices()` (phụ thuộc mạng, có thể
    // chậm/timeout) mới cho UI (vd: chọn loại vàng ở Onboarding) thấy dữ
    // liệu local đã sẵn sàng.
    notifyListeners();

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
    _biometricEnabled =
        StorageService.getSetting<bool>(_kBiometricEnabled) ?? false;
    _pinFailCount = StorageService.getSetting<int>(_kPinFailCount) ?? 0;
    _pinBlockedUntilMs = StorageService.getSetting<int>(_kPinBlockedUntil);

    final salt = StorageService.getSetting<String>(_kPinSalt);
    final hash = StorageService.getSetting<String>(_kPinHash);
    if (salt != null && hash != null) {
      _pinCredential = PinCredential(
        salt: salt,
        hash: hash,
        iterations: StorageService.getSetting<int>(_kPinIterations) ??
            PinCredential.defaultIterations,
      );
    }
    // Migrate PIN plaintext của bản cũ: băm rồi xoá key cũ. Nếu đã có hash
    // (vd: app bị tắt giữa chừng lần trước) thì chỉ cần xoá key cũ.
    final legacy = StorageService.getSetting<String>(_kLegacyPin);
    if (legacy != null) {
      if (_pinCredential == null && _pinEnabled) {
        _pinCredential = PinCredential.migrateLegacy(legacy);
      }
      unawaited(_persistMigratedPin());
    }
    // Bật PIN mà không còn credential nào (dữ liệu hỏng) → không để user
    // bị khoá vĩnh viễn ngoài app; tắt khoá.
    if (_pinEnabled && _pinCredential == null) _pinEnabled = false;
  }

  Future<void> _persistMigratedPin() async {
    final c = _pinCredential;
    if (c != null) await _savePinCredential(c);
    await StorageService.putSetting(_kLegacyPin, null);
  }

  Future<void> _savePinCredential(PinCredential c) async {
    await StorageService.putSetting(_kPinSalt, c.salt);
    await StorageService.putSetting(_kPinHash, c.hash);
    await StorageService.putSetting(_kPinIterations, c.iterations);
  }

  Future<void> _resetPinAttempts() async {
    if (_pinFailCount == 0 && _pinBlockedUntilMs == null) return;
    _pinFailCount = 0;
    _pinBlockedUntilMs = null;
    await StorageService.putSetting(_kPinFailCount, null);
    await StorageService.putSetting(_kPinBlockedUntil, null);
  }

  /// Kiểm tra lại thiết bị có dùng được sinh trắc học không.
  Future<bool> refreshBiometricAvailability() async {
    _biometricAvailable = await _biometric.isAvailable();
    notifyListeners();
    return _biometricAvailable;
  }

  /// Bật/tắt mở khoá bằng sinh trắc. Bật cần xác thực thành công 1 lần;
  /// trả về true nếu trạng thái mới được áp dụng.
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      if (!_pinEnabled || !await refreshBiometricAvailability()) return false;
      final ok = await _biometric
          .authenticate('Xác nhận để bật mở khoá bằng vân tay / Face ID');
      if (!ok) return false;
    }
    _biometricEnabled = enabled;
    await StorageService.putSetting(_kBiometricEnabled, enabled);
    notifyListeners();
    return true;
  }

  /// Mở khoá bằng sinh trắc (lock screen). Huỷ/lỗi chỉ trả false — không
  /// tính là nhập sai PIN.
  Future<bool> unlockWithBiometric() async {
    if (!biometricEnabled || !await _biometric.isAvailable()) return false;
    final ok = await _biometric.authenticate('Mở khoá Lỗ nhiều chưa?');
    if (ok) await _resetPinAttempts();
    return ok;
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
    final credential = enabled ? PinCredential.create(pin) : null;
    _pinCredential = credential;
    _pinEnabled = enabled && credential != null;
    if (credential != null) {
      await _savePinCredential(credential);
    } else {
      // Tắt PIN: xoá salt + hash, tắt luôn sinh trắc (chỉ là lớp tiện lợi).
      _biometricEnabled = false;
      await StorageService.putSetting(_kPinSalt, null);
      await StorageService.putSetting(_kPinHash, null);
      await StorageService.putSetting(_kPinIterations, null);
      await StorageService.putSetting(_kBiometricEnabled, false);
    }
    await StorageService.putSetting(_kLegacyPin, null);
    await _resetPinAttempts();
    await StorageService.putSetting(_kPinEnabled, _pinEnabled);
    notifyListeners();
  }

  /// Kiểm tra PIN nhập vào có khớp PIN đã lưu không — dùng bởi `LockScreen`.
  /// Đang bị khoá (sai ≥ 5 lần liên tiếp) thì trả false mà không so khớp;
  /// xem [pinBlockRemaining]. Số lần sai + mốc hết khoá được lưu bền.
  Future<bool> verifyPin(String pin) async {
    final credential = _pinCredential;
    if (!_pinEnabled || credential == null || pin.isEmpty) return false;
    if (pinBlockRemaining > Duration.zero) return false;

    if (credential.verify(pin)) {
      await _resetPinAttempts();
      return true;
    }
    _pinFailCount++;
    final block = PinLockout.blockFor(_pinFailCount);
    _pinBlockedUntilMs = block > Duration.zero
        ? DateTime.now().add(block).millisecondsSinceEpoch
        : null;
    await StorageService.putSetting(_kPinFailCount, _pinFailCount);
    await StorageService.putSetting(_kPinBlockedUntil, _pinBlockedUntilMs);
    return false;
  }

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

  /// Mark a holding as sold (kèm giá bán/lượng, ngày bán, phí bán)
  Future<void> markAsSold(
    String id, {
    required double sellPricePerLuong,
    required DateTime sellDate,
    double sellFee = 0,
  }) async {
    await _portfolio.markAsSold(
      id,
      sellPricePerLuong: sellPricePerLuong,
      sellDate: sellDate,
      sellFee: sellFee,
    );
    _holdings = _portfolio.allHoldings;
    _updatePortfolioSummary();
    notifyListeners();
  }

  /// Hoàn tác bán — về lại "đang giữ", xoá thông tin bán
  Future<void> undoSale(String id) async {
    await _portfolio.undoSale(id);
    _holdings = _portfolio.allHoldings;
    _updatePortfolioSummary();
    notifyListeners();
  }

  /// Parse + validate nội dung file sao lưu. Ném [BackupFormatException]
  /// (message tiếng Việt) nếu file không hợp lệ; chưa đụng tới dữ liệu.
  BackupData parseBackup(String raw) => BackupCodec.parse(raw);

  /// Số mục trong file so với dữ liệu hiện có, để hiện hộp thoại xác nhận.
  ImportPreview previewImport(BackupData data) =>
      BackupCodec.preview(existingHoldings: _holdings, data: data);

  /// Nhập dữ liệu từ file sao lưu đã parse. Không bị giới hạn free tier.
  /// Trả về kế hoạch đã áp dụng (số mục thêm/bỏ qua). Ném lại lỗi nếu ghi
  /// đĩa thất bại (state memory đã được khôi phục).
  Future<ImportPlan> importBackup(BackupData data, ImportMode mode) async {
    final plan = BackupCodec.plan(
      existingHoldings: _holdings,
      existingGoldTypes: _goldTypes,
      data: data,
      mode: mode,
    );
    await _portfolio.applyImport(plan);
    _holdings = _portfolio.allHoldings;
    _goldTypes = _portfolio.goldTypes;
    _updatePortfolioSummary();
    notifyListeners();
    return plan;
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
