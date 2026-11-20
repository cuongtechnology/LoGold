import 'dart:async';

import '../models/price_alert.dart';
import '../services/alert_evaluator.dart';
import '../services/local_notification_service.dart';
import '../services/profit_loss_calculator.dart';
import '../services/storage_service.dart';

/// NotificationService - Handles price alerts and notifications.
/// Alerts persist qua Hive (kèm trạng thái `triggered`); notifications giữ
/// in-memory (không cần lưu lâu). Khi alert bắn: thêm vào list in-app và hiện
/// notification hệ thống qua `LocalNotificationService`. Alert chỉ được kiểm
/// tra lúc giá được làm mới khi app đang chạy (không có tác vụ nền).
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();

  NotificationService._();

  final List<PriceAlert> _alerts = [];
  final List<AppNotification> _notifications = [];

  List<PriceAlert> get alerts => List.unmodifiable(_alerts);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Load alerts từ Hive. Notifications không persist — chỉ session này.
  Future<void> init() async {
    _alerts.clear();
    _alerts.addAll(
      StorageService.readMapList(StorageService.alerts)
          .map(PriceAlert.fromMap),
    );
  }

  Future<void> addAlert(PriceAlert alert) async {
    _alerts.add(alert.copyWith(triggered: false));
    await _persistAlerts();
  }

  Future<void> removeAlert(String id) async {
    _alerts.removeWhere((a) => a.id == id);
    await _persistAlerts();
  }

  /// Bật/tắt alert. Cả hai chiều đều reset `triggered` để alert được "lên
  /// đạn" lại — tắt rồi bật lại sẽ báo lại nếu điều kiện đang đúng.
  /// Trả về trạng thái `enabled` mới (null nếu không tìm thấy alert).
  Future<bool?> toggleAlert(String id) async {
    final index = _alerts.indexWhere((a) => a.id == id);
    if (index < 0) return null;
    final enabled = !_alerts[index].enabled;
    _alerts[index] = _alerts[index].copyWith(enabled: enabled, triggered: false);
    await _persistAlerts();
    return enabled;
  }

  /// Xin quyền thông báo hệ thống (Android 13+/iOS). Gọi khi user tạo/bật
  /// cảnh báo, không gọi lúc khởi động app.
  Future<bool> requestSystemPermission() =>
      LocalNotificationService.instance.requestPermission();

  /// Kiểm tra mọi alert với trạng thái hiện tại. Mỗi alert chỉ bắn khi điều
  /// kiện chuyển từ sai → đúng (xem `evaluateAlert`); trạng thái `triggered`
  /// được lưu lại. Trả về các notification vừa bắn.
  ///
  /// [buyPrices]: goldTypeId -> giá tiệm thu mua (đ/lượng) hiện tại.
  /// [priceChanges]: goldTypeId -> chênh lệch giá thu mua so với lần trước.
  /// [goldTypeNames]: goldTypeId -> tên hiển thị (cho nội dung thông báo).
  List<AppNotification> checkAlerts({
    required PortfolioSummary summary,
    required Map<String, double> buyPrices,
    required Map<String, double> priceChanges,
    Map<String, String> goldTypeNames = const {},
  }) {
    final triggered = <AppNotification>[];
    final ctx = AlertContext(
      totalProfitLoss: summary.totalProfitLoss,
      hasHoldings: summary.holdings.isNotEmpty,
      buyPrices: buyPrices,
      priceChanges: priceChanges,
    );
    var changed = false;

    for (var i = 0; i < _alerts.length; i++) {
      final alert = _alerts[i];
      final decision = evaluateAlert(
        alert,
        ctx,
        formatVnd: _formatVnd,
        goldTypeName: goldTypeNames[alert.goldTypeId],
      );

      if (decision.triggered != alert.triggered) {
        _alerts[i] = alert.copyWith(triggered: decision.triggered);
        changed = true;
      }

      if (decision.fire) {
        final now = DateTime.now();
        final notification = AppNotification(
          id: '${alert.id}_${now.millisecondsSinceEpoch}',
          title: decision.title,
          body: decision.body,
          timestamp: now,
          type: alert.type,
        );
        triggered.add(notification);
        _notifications.insert(0, notification);
        // Không await — lỗi/chậm của hệ thống thông báo không được chặn việc
        // cập nhật giá (service tự nuốt lỗi).
        unawaited(LocalNotificationService.instance.show(
          title: decision.title,
          body: decision.body,
        ));
      }
    }

    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }

    if (changed) unawaited(_persistAlerts());

    return triggered;
  }

  void clearNotifications() {
    _notifications.clear();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }

  // Xếp hàng các lần ghi (writeMapList = clear + putAll) để không chồng lấn.
  Future<void> _persistChain = Future.value();

  Future<void> _persistAlerts() {
    final snapshot = _alerts.map((a) => a.toMap()).toList();
    return _persistChain = _persistChain.catchError((_) {}).then(
          (_) => StorageService.writeMapList(
            StorageService.alerts,
            snapshot,
            keyOf: (m) => m['id'] as String,
          ),
        );
  }

  String _formatVnd(double value) {
    final abs = value.abs().round();
    final str = abs.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return value < 0 ? '-${str}đ' : '${str}đ';
  }
}

/// In-app notification model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final PriceAlertType type;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    PriceAlertType? type,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
    );
  }
}
