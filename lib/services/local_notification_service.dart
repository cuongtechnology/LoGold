import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// LocalNotificationService — plugin `flutter_local_notifications` dùng chung
/// cho push FCM (foreground) và cảnh báo giá. Init 1 lần, idempotent, và KHÔNG
/// phụ thuộc Firebase — cảnh báo giá vẫn hiện được khi chưa cấu hình push.
///
/// Mọi hàm đều nuốt lỗi (chỉ log ở debug) — thông báo hỏng không được làm
/// crash hay chặn luồng cập nhật giá.
class LocalNotificationService {
  static LocalNotificationService? _instance;
  static LocalNotificationService get instance =>
      _instance ??= LocalNotificationService._();

  LocalNotificationService._();

  static const channelId = 'lo_gold_price';
  static const channelName = 'Biến động giá vàng';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 1000;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Không xin quyền lúc init — chỉ xin khi user tạo/bật cảnh báo
      // (xem requestPermission).
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Thông báo khi giá vàng biến động mạnh',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalNotificationService.init lỗi: $e');
    }
  }

  /// Xin quyền hiện thông báo (Android 13+ / iOS). Trả `true` nếu được cấp
  /// hoặc nền tảng không cần xin.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalNotificationService.requestPermission lỗi: $e');
      return false;
    }
  }

  /// Hiện 1 notification hệ thống. [id] null → tự cấp id tăng dần.
  Future<void> show({int? id, String? title, String? body}) async {
    if (kIsWeb) return;
    try {
      await init();
      if (!_initialized) return;
      await _plugin.show(
        id: id ?? _nextId++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('LocalNotificationService.show lỗi: $e');
    }
  }
}
