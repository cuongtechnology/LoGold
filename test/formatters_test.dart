import 'package:flutter_test/flutter_test.dart';
import 'package:lo/utils/formatters.dart';

void main() {
  group('Formatters.parseMoney', () {
    test('accepts Vietnamese and English thousand separators', () {
      expect(Formatters.parseMoney('116.000.000'), 116000000);
      expect(Formatters.parseMoney('116,000,000'), 116000000);
      expect(Formatters.parseMoney('116 000 000đ'), 116000000);
      expect(Formatters.parseMoney('116000000'), 116000000);
    });

    test('returns null without digits', () {
      expect(Formatters.parseMoney(''), isNull);
      expect(Formatters.parseMoney('abc'), isNull);
    });

    test('round-trips formatVnd output', () {
      final text = Formatters.formatVnd(11600000, withSymbol: false);
      expect(Formatters.parseMoney(text), 11600000);
    });
  });

  group('Formatters.parseQuantity', () {
    test('accepts comma or dot as decimal separator', () {
      expect(Formatters.parseQuantity('0.5'), 0.5);
      expect(Formatters.parseQuantity('0,5'), 0.5);
      expect(Formatters.parseQuantity(' 2 '), 2);
    });

    test('returns null for empty or malformed input', () {
      expect(Formatters.parseQuantity(''), isNull);
      expect(Formatters.parseQuantity('1.2.3'), isNull);
    });
  });
}
