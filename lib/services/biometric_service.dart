import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Bọc `local_auth` (vân tay / Face ID). Singleton — chỉ `AppStore` gọi.
/// Mọi hàm đều không throw: lỗi/huỷ/không hỗ trợ đều trả `false`.
class BiometricService {
  BiometricService._();
  static BiometricService? _instance;
  static BiometricService get instance => _instance ??= BiometricService._();

  /// Sau khi hộp thoại sinh trắc đóng, vẫn bỏ qua sự kiện `paused` muộn một
  /// lúc (vài máy Android bắn trễ) để không tự khoá lại ngay sau khi mở khoá.
  static const _lifecycleGrace = Duration(seconds: 1);

  final _auth = LocalAuthentication();
  bool _prompting = false;
  DateTime? _lastPromptEnd;

  /// True khi hộp thoại sinh trắc đang hiện (hoặc vừa đóng xong). `main.dart`
  /// dùng để không coi việc app bị `paused` do hộp thoại là "ra nền".
  bool get isPromptActive {
    if (_prompting) return true;
    final end = _lastPromptEnd;
    return end != null && DateTime.now().difference(end) < _lifecycleGrace;
  }

  /// Thiết bị có sinh trắc học dùng được (đã đăng ký vân tay/khuôn mặt).
  /// Luôn false trên web.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.canCheckBiometrics) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Hiện hộp thoại sinh trắc. True nếu xác thực thành công; huỷ/lỗi → false.
  Future<bool> authenticate(String reason) async {
    if (kIsWeb || _prompting) return false;
    _prompting = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    } finally {
      _prompting = false;
      _lastPromptEnd = DateTime.now();
    }
  }
}
