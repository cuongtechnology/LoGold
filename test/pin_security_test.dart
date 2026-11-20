import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lo/utils/pin_security.dart';

void main() {
  group('PinCredential', () {
    test('hash rồi verify đúng PIN', () {
      final c = PinCredential.create('1234');
      expect(c.verify('1234'), isTrue);
    });

    test('PIN sai hoặc rỗng bị từ chối', () {
      final c = PinCredential.create('1234');
      expect(c.verify('1235'), isFalse);
      expect(c.verify('12345'), isFalse);
      expect(c.verify(''), isFalse);
    });

    test('salt khác nhau cho hash khác nhau; hash không chứa PIN gốc', () {
      final a = PinCredential.create('1234');
      final b = PinCredential.create('1234');
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(a.hash, isNot(contains('1234')));
    });

    test('cùng salt + PIN cho cùng hash (deterministic)', () {
      final a = PinCredential.create('4321', random: Random(1));
      final b = PinCredential.create('4321', random: Random(1));
      expect(a.hash, b.hash);
    });

    test('PBKDF2-HMAC-SHA256 khớp test vector RFC 7914 (c=1)', () {
      const hex =
          '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc';
      final bytes = [
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
      final c = PinCredential(
        salt: base64Encode(utf8.encode('salt')),
        hash: base64Encode(bytes),
        iterations: 1,
      );
      expect(c.verify('passwd'), isTrue);
    });

    test('iterations được lưu kèm nên đổi số vòng không làm hỏng PIN cũ', () {
      final c = PinCredential.create('9999', iterations: 50);
      expect(c.verify('9999'), isTrue);
      expect(c.iterations, 50);
    });

    test('dữ liệu lưu bị hỏng thì verify trả false, không throw', () {
      const c = PinCredential(salt: '!!!', hash: '???', iterations: 10);
      expect(c.verify('1234'), isFalse);
    });

    test('migrate PIN plaintext cũ: PIN cũ vẫn mở được, PIN khác thì không',
        () {
      final c = PinCredential.migrateLegacy('2468')!;
      expect(c.verify('2468'), isTrue);
      expect(c.verify('1357'), isFalse);
      expect(PinCredential.migrateLegacy(''), isNull);
      expect(PinCredential.migrateLegacy(null), isNull);
    });

    test('thời gian verify với số vòng mặc định (ghi lại để tham khảo)', () {
      final c = PinCredential.create('1234');
      final sw = Stopwatch()..start();
      c.verify('1234');
      sw.stop();
      // ignore: avoid_print
      print('verify ${PinCredential.defaultIterations} vòng: '
          '${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('PinLockout', () {
    test('4 lần sai đầu không bị khoá, từ lần 5 mới khoá', () {
      for (var i = 0; i < 5; i++) {
        expect(PinLockout.blockFor(i), Duration.zero);
      }
      expect(PinLockout.blockFor(5), const Duration(seconds: 30));
    });

    test('mỗi lần sai thêm kéo dài khoá, có trần 5 phút', () {
      expect(PinLockout.blockFor(6), const Duration(minutes: 1));
      expect(PinLockout.blockFor(7), const Duration(minutes: 2));
      expect(PinLockout.blockFor(8), const Duration(minutes: 4));
      expect(PinLockout.blockFor(9), const Duration(minutes: 5));
      expect(PinLockout.blockFor(500), const Duration(minutes: 5));
    });

    test('remaining: còn/hết hạn/đồng hồ chỉnh lùi', () {
      final now = DateTime(2026, 1, 1, 12);
      final ms = now.millisecondsSinceEpoch;
      expect(PinLockout.remaining(null, now), Duration.zero);
      expect(PinLockout.remaining(ms - 1, now), Duration.zero);
      expect(
          PinLockout.remaining(ms + 20000, now), const Duration(seconds: 20));
      expect(PinLockout.remaining(ms + 86400000, now), PinLockout.maxBlock);
    });
  });
}
