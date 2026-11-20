import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_notification_service.dart';

/// Xử lý message FCM khi app ở background/terminated. Phải là top-level
/// function (không phải method trong class) và đánh dấu entry-point để
/// Android không tree-shake mất — theo yêu cầu của `firebase_messaging`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Không cần làm gì thêm — hệ điều hành tự hiện notification hệ thống khi
  // app ở background/terminated (payload FCM có kèm "notification" block).
}

/// PushNotificationService — đăng ký nhận + hiển thị push thông báo giá vàng.
///
/// **Yêu cầu để hoạt động** (thiếu thì `init()` tự no-op, không crash app):
/// 1. `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) từ
///    1 project Firebase thật, đặt vào `android/app/` / `ios/Runner/`.
/// 2. Backend thật sự gửi push — xem `worker/src/index.ts`: cron so sánh
///    biến động giá rồi gọi FCM. Token thiết bị đăng ký qua [registerEndpoint].
///
/// Dùng pattern `.instance` singleton (giống các service khác) để Cài đặt
/// có thể đọc lại [statusMessage]/[isReady] sau khi `main()` đã init.
class PushNotificationService {
  static PushNotificationService? _instance;
  static PushNotificationService get instance =>
      _instance ??= PushNotificationService._();

  PushNotificationService._();

  bool _isReady = false;
  bool _isConfigured = false;
  String _statusMessage = 'Chưa khởi tạo';

  /// `false` khi bản build không kèm cấu hình Firebase (vd: iOS chưa có
  /// GoogleService-Info.plist) — UI ẩn hẳn mục thông báo đẩy.
  bool get isConfigured => _isConfigured;

  /// `true` nếu Firebase init thành công và đã đăng ký nhận push.
  bool get isReady => _isReady;

  /// Mô tả trạng thái hiện tại, hiển thị trong Cài đặt.
  String get statusMessage => _statusMessage;

  /// [registerEndpoint] là URL đầy đủ tới endpoint `/register-token` của CF
  /// Worker (vd: `https://lo-gold-proxy.xxx.workers.dev/register-token`).
  /// Để trống nếu chưa deploy worker — service vẫn init Firebase/local
  /// notification bình thường, chỉ bỏ qua bước đăng ký token với backend.
  Future<void> init({String registerEndpoint = ''}) async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      _statusMessage = 'Chưa hỗ trợ trên phiên bản này';
      if (kDebugMode) {
        debugPrint(
          'PushNotificationService: chưa cấu hình Firebase, bỏ qua ($e)',
        );
      }
      return;
    }
    _isConfigured = true;

    await LocalNotificationService.instance.init();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    await _registerToken(await messaging.getToken(), registerEndpoint);
    messaging.onTokenRefresh.listen((token) {
      _registerToken(token, registerEndpoint);
    });

    final permissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    _isReady = permissionGranted;
    _statusMessage = !permissionGranted
        ? 'Bạn đã từ chối quyền thông báo'
        : registerEndpoint.isEmpty
            ? 'Đã bật, chưa kết nối server gửi thông báo'
            : 'Đang hoạt động';
  }

  Future<void> _registerToken(String? token, String registerEndpoint) async {
    if (token == null || registerEndpoint.isEmpty) return;
    try {
      await http.post(
        Uri.parse(registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'platform': defaultTargetPlatform.name,
        }),
      );
    } catch (_) {
      // Backend chưa sẵn sàng/mất mạng — bỏ qua, token refresh lần sau thử lại.
    }
  }

  /// FCM không tự hiện notification khi app đang mở (foreground) — phải tự
  /// show qua `flutter_local_notifications`.
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    LocalNotificationService.instance.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
    );
  }
}
