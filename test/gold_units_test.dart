import 'package:flutter_test/flutter_test.dart';
import 'package:lo/utils/gold_units.dart';

void main() {
  group('GoldUnits quantity conversion', () {
    test('toLuong', () {
      expect(GoldUnits.toLuong(1, 'luong'), 1);
      expect(GoldUnits.toLuong(5, 'chi'), closeTo(0.5, 1e-9));
      expect(GoldUnits.toLuong(37.5, 'gram'), closeTo(1, 1e-9));
      expect(GoldUnits.toLuong(25, 'phan'), closeTo(0.25, 1e-9));
    });

    test('fromLuong', () {
      expect(GoldUnits.fromLuong(1, 'chi'), 10);
      expect(GoldUnits.fromLuong(2, 'gram'), 75);
    });

    test('convert between units', () {
      expect(GoldUnits.convert(1, 'chi', 'gram'), closeTo(3.75, 1e-9));
      expect(GoldUnits.convert(7.5, 'gram', 'chi'), closeTo(2, 1e-9));
      expect(GoldUnits.convert(1, 'chi', 'phan'), closeTo(10, 1e-9));
    });
  });

  group('GoldUnits price conversion', () {
    test('pricePerLuong from price per chỉ', () {
      // 12,000,000/chỉ -> 120,000,000/lượng
      expect(GoldUnits.pricePerLuong(12000000, 'chi'), closeTo(120000000, 1e-3));
    });

    test('pricePerLuong from price per gram', () {
      // 3,200,000/gram -> 120,000,000/lượng
      expect(GoldUnits.pricePerLuong(3200000, 'gram'), closeTo(120000000, 1e-3));
    });

    test('pricePerLuong from price per phân', () {
      // 1,200,000/phân -> 120,000,000/lượng
      expect(GoldUnits.pricePerLuong(1200000, 'phan'), closeTo(120000000, 1e-3));
    });

    test('pricePerLuong is identity for lượng', () {
      expect(GoldUnits.pricePerLuong(116000000, 'luong'), 116000000);
    });

    test('priceFromLuong is the inverse of pricePerLuong', () {
      expect(GoldUnits.priceFromLuong(120000000, 'chi'), closeTo(12000000, 1e-3));
      expect(GoldUnits.priceFromLuong(120000000, 'gram'), closeTo(3200000, 1e-3));
      for (final unit in GoldUnits.units) {
        final perLuong = GoldUnits.pricePerLuong(11500000, unit);
        expect(GoldUnits.priceFromLuong(perLuong, unit), closeTo(11500000, 1e-3));
      }
    });

    test('total cost of 5 chỉ at 12tr/chỉ is 60tr', () {
      final qtyLuong = GoldUnits.toLuong(5, 'chi');
      final priceLuong = GoldUnits.pricePerLuong(12000000, 'chi');
      expect(qtyLuong * priceLuong, closeTo(60000000, 1e-3));
    });
  });
}
