import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PIN đã băm: salt ngẫu nhiên + PBKDF2-HMAC-SHA256 (không lưu PIN gốc).
/// Pure Dart, không phụ thuộc Hive/Flutter — dễ test riêng.
class PinCredential {
  /// Số vòng lặp PBKDF2. Không gian PIN chỉ 4-6 chữ số nên cần nhiều vòng
  /// để làm chậm brute-force nếu lộ dữ liệu; 10.000 vòng ≈ vài chục ms trên
  /// máy tầm trung (Dart thuần). Số vòng được lưu kèm để sau này tăng được
  /// mà không làm hỏng PIN cũ.
  static const defaultIterations = 10000;

  final String salt; // base64
  final String hash; // base64
  final int iterations;

  const PinCredential({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  /// Tạo credential mới với salt ngẫu nhiên.
  factory PinCredential.create(
    String pin, {
    int iterations = defaultIterations,
    Random? random,
  }) {
    final rnd = random ?? Random.secure();
    final saltBytes = Uint8List.fromList(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    );
    return PinCredential(
      salt: base64Encode(saltBytes),
      hash: base64Encode(_pbkdf2(pin, saltBytes, iterations)),
      iterations: iterations,
    );
  }

  /// Chuyển PIN plaintext kiểu cũ (key `'pin'`) sang dạng đã băm.
  /// Trả null nếu không có PIN cũ hợp lệ để chuyển.
  static PinCredential? migrateLegacy(String? legacyPin) {
    if (legacyPin == null || legacyPin.isEmpty) return null;
    return PinCredential.create(legacyPin);
  }

  /// So khớp PIN nhập vào, so sánh thời gian không đổi.
  bool verify(String pin) {
    if (pin.isEmpty) return false;
    try {
      final actual = _pbkdf2(pin, base64Decode(salt), iterations);
      return _constantTimeEquals(actual, base64Decode(hash));
    } on FormatException {
      return false; // dữ liệu lưu bị hỏng
    }
  }

  static Uint8List _pbkdf2(String pin, List<int> salt, int iterations) {
    // Output 32 byte = đúng 1 block của HMAC-SHA256 nên không cần vòng ngoài.
    final hmac = Hmac(sha256, utf8.encode(pin));
    var u = Uint8List.fromList(hmac.convert([...salt, 0, 0, 0, 1]).bytes);
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final n = min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Lịch khoá khi nhập sai PIN liên tiếp.
class PinLockout {
  /// Số lần sai liên tiếp được phép trước khi bị khoá.
  static const freeAttempts = 5;
  static const maxBlock = Duration(minutes: 5);

  /// Thời gian khoá sau lần sai thứ [failures] (liên tiếp):
  /// lần 5 → 30s, 6 → 1p, 7 → 2p, 8 → 4p, 9 trở đi → 5p (trần).
  static Duration blockFor(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final seconds = 30 * (1 << (failures - freeAttempts).clamp(0, 10));
    final d = Duration(seconds: seconds);
    return d > maxBlock ? maxBlock : d;
  }

  /// Thời gian còn bị khoá tại [now]. Kẹp tối đa [maxBlock] để đồng hồ máy
  /// bị chỉnh lùi cũng không khoá user quá lâu.
  static Duration remaining(int? blockedUntilMs, DateTime now) {
    if (blockedUntilMs == null) return Duration.zero;
    final left = Duration(
      milliseconds: blockedUntilMs - now.millisecondsSinceEpoch,
    );
    if (left <= Duration.zero) return Duration.zero;
    return left > maxBlock ? maxBlock : left;
  }
}
