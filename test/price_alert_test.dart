import 'package:flutter_test/flutter_test.dart';
import 'package:lo/models/price_alert.dart';
import 'package:lo/services/alert_evaluator.dart';

PriceAlert _alert(
  PriceAlertType type, {
  String? goldTypeId,
  double? targetPrice,
  double? targetProfitLoss,
  PriceAlertDirection direction = PriceAlertDirection.above,
  bool enabled = true,
  bool triggered = false,
}) {
  return PriceAlert(
    id: 'a1',
    type: type,
    goldTypeId: goldTypeId,
    targetPrice: targetPrice,
    targetProfitLoss: targetProfitLoss,
    direction: direction,
    enabled: enabled,
    triggered: triggered,
    createdAt: DateTime(2026, 1, 1),
  );
}

AlertContext _ctx({
  double pl = 0,
  bool hasHoldings = true,
  Map<String, double> prices = const {},
  Map<String, double> changes = const {},
}) {
  return AlertContext(
    totalProfitLoss: pl,
    hasHoldings: hasHoldings,
    buyPrices: prices,
    priceChanges: changes,
  );
}

void main() {
  group('priceTarget', () {
    test('hướng above: báo khi giá >= mục tiêu, không báo khi thấp hơn', () {
      final a = _alert(PriceAlertType.priceTarget,
          goldTypeId: 'sjc', targetPrice: 100);
      expect(evaluateAlert(a, _ctx(prices: {'sjc': 99})).fire, isFalse);
      expect(evaluateAlert(a, _ctx(prices: {'sjc': 100})).fire, isTrue);
      expect(evaluateAlert(a, _ctx(prices: {'sjc': 120})).fire, isTrue);
    });

    test('hướng below: báo khi giá <= mục tiêu', () {
      final a = _alert(PriceAlertType.priceTarget,
          goldTypeId: 'sjc',
          targetPrice: 100,
          direction: PriceAlertDirection.below);
      expect(evaluateAlert(a, _ctx(prices: {'sjc': 101})).fire, isFalse);
      expect(evaluateAlert(a, _ctx(prices: {'sjc': 100})).fire, isTrue);
      expect(evaluateAlert(a, _ctx(prices: {'sjc': 80})).fire, isTrue);
    });

    test('chỉ so với giá của đúng loại vàng; thiếu giá thì không báo', () {
      final a = _alert(PriceAlertType.priceTarget,
          goldTypeId: 'sjc', targetPrice: 100);
      expect(evaluateAlert(a, _ctx(prices: {'doji': 500})).fire, isFalse);
      expect(evaluateAlert(a, _ctx()).fire, isFalse);
    });

    test('thiếu giá thì giữ nguyên trạng thái triggered', () {
      final a = _alert(PriceAlertType.priceTarget,
          goldTypeId: 'sjc', targetPrice: 100, triggered: true);
      expect(evaluateAlert(a, _ctx()).triggered, isTrue);
    });
  });

  group('edge-triggering', () {
    test('báo 1 lần, không báo lại khi điều kiện vẫn đúng', () {
      var a = _alert(PriceAlertType.priceTarget,
          goldTypeId: 'sjc', targetPrice: 100);
      final ctx = _ctx(prices: {'sjc': 110});

      final first = evaluateAlert(a, ctx);
      expect(first.fire, isTrue);
      expect(first.triggered, isTrue);

      a = a.copyWith(triggered: first.triggered);
      final second = evaluateAlert(a, ctx);
      expect(second.fire, isFalse);
      expect(second.triggered, isTrue);
    });

    test('re-arm khi điều kiện sai trở lại rồi báo lại khi đúng', () {
      var a = _alert(PriceAlertType.priceTarget,
          goldTypeId: 'sjc', targetPrice: 100, triggered: true);

      final down = evaluateAlert(a, _ctx(prices: {'sjc': 90}));
      expect(down.fire, isFalse);
      expect(down.triggered, isFalse);

      a = a.copyWith(triggered: down.triggered);
      final up = evaluateAlert(a, _ctx(prices: {'sjc': 105}));
      expect(up.fire, isTrue);
    });

    test('alert tắt thì không báo và giữ nguyên trạng thái', () {
      final a = _alert(PriceAlertType.priceTarget,
          goldTypeId: 'sjc', targetPrice: 100, enabled: false);
      final d = evaluateAlert(a, _ctx(prices: {'sjc': 200}));
      expect(d.fire, isFalse);
      expect(d.triggered, isFalse);
    });

    test('trạng thái triggered được lưu/đọc qua toMap/fromMap', () {
      final a = _alert(PriceAlertType.priceTarget,
          goldTypeId: 'sjc',
          targetPrice: 100,
          direction: PriceAlertDirection.below,
          triggered: true);
      final back = PriceAlert.fromMap(a.toMap());
      expect(back.triggered, isTrue);
      expect(back.direction, PriceAlertDirection.below);
    });

    test('alert cũ không có direction/triggered: mặc định above, chưa báo', () {
      final old = {
        'id': 'x',
        'type': 'priceTarget',
        'goldTypeId': 'sjc',
        'targetPrice': 100.0,
        'targetProfitLoss': null,
        'enabled': true,
        'createdAt': '2026-01-01T00:00:00.000',
      };
      final a = PriceAlert.fromMap(old);
      expect(a.direction, PriceAlertDirection.above);
      expect(a.triggered, isFalse);
    });
  });

  group('ngưỡng lãi/lỗ', () {
    test('lossThreshold báo khi lỗ >= ngưỡng', () {
      final a = _alert(PriceAlertType.lossThreshold, targetProfitLoss: 5000000);
      expect(evaluateAlert(a, _ctx(pl: -4999999)).fire, isFalse);
      expect(evaluateAlert(a, _ctx(pl: -5000000)).fire, isTrue);
      expect(evaluateAlert(a, _ctx(pl: 1000000)).fire, isFalse);
    });

    test('profitThreshold báo khi lãi >= ngưỡng', () {
      final a =
          _alert(PriceAlertType.profitThreshold, targetProfitLoss: 10000000);
      expect(evaluateAlert(a, _ctx(pl: 9999999)).fire, isFalse);
      expect(evaluateAlert(a, _ctx(pl: 10000000)).fire, isTrue);
    });

    test('ngưỡng thiếu/0 thì không báo', () {
      expect(
        evaluateAlert(_alert(PriceAlertType.lossThreshold), _ctx(pl: -1)).fire,
        isFalse,
      );
      expect(
        evaluateAlert(
          _alert(PriceAlertType.profitThreshold, targetProfitLoss: 0),
          _ctx(pl: 5),
        ).fire,
        isFalse,
      );
    });
  });

  group('breakeven', () {
    final a = _alert(PriceAlertType.breakeven);
    test('báo khi 0 <= P/L < 100.000đ', () {
      expect(evaluateAlert(a, _ctx(pl: 0)).fire, isTrue);
      expect(evaluateAlert(a, _ctx(pl: 99999)).fire, isTrue);
      expect(evaluateAlert(a, _ctx(pl: 100000)).fire, isFalse);
      expect(evaluateAlert(a, _ctx(pl: -1)).fire, isFalse);
    });

    test('chưa có vị thế thì không báo', () {
      expect(evaluateAlert(a, _ctx(pl: 0, hasHoldings: false)).fire, isFalse);
    });
  });

  group('priceSurge', () {
    test('báo khi có loại vàng biến động > 1 triệu', () {
      final a = _alert(PriceAlertType.priceSurge);
      expect(evaluateAlert(a, _ctx(changes: {'sjc': 500000})).fire, isFalse);
      expect(evaluateAlert(a, _ctx(changes: {'sjc': -1500000})).fire, isTrue);
    });

    test('nếu gắn loại vàng thì chỉ xét loại đó', () {
      final a = _alert(PriceAlertType.priceSurge, goldTypeId: 'doji');
      expect(
        evaluateAlert(a, _ctx(changes: {'sjc': 2000000, 'doji': 100})).fire,
        isFalse,
      );
      expect(
        evaluateAlert(a, _ctx(changes: {'doji': 2000000})).fire,
        isTrue,
      );
    });
  });
}
