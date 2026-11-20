import 'package:flutter_test/flutter_test.dart';
import 'package:lo/models/meme_template.dart';
import 'package:lo/models/user_holding.dart';
import 'package:lo/services/profit_loss_calculator.dart';

UserHolding _holding({
  String goldTypeId = 'sjc',
  double quantityInLuong = 1,
  double buyPricePerLuong = 120000000,
  double fee = 0,
  String status = 'holding',
}) {
  final now = DateTime(2026, 1, 1);
  return UserHolding(
    id: 'h-$goldTypeId-$quantityInLuong',
    goldTypeId: goldTypeId,
    quantity: quantityInLuong,
    unit: 'luong',
    quantityInLuong: quantityInLuong,
    buyPricePerLuong: buyPricePerLuong,
    totalCost: buyPricePerLuong * quantityInLuong + fee,
    fee: fee,
    buyDate: now,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ProfitLossCalculator.calculate', () {
    test('loss including fee', () {
      final r = ProfitLossCalculator.calculate(
        holding: _holding(buyPricePerLuong: 120000000, fee: 1000000),
        currentBuyPricePerLuong: 115000000,
      );
      expect(r.totalCost, 121000000);
      expect(r.currentValue, 115000000);
      expect(r.profitLoss, -6000000);
      expect(r.profitLossPercent, closeTo(-4.9587, 1e-3));
      expect(r.breakEvenPricePerLuong, 121000000);
      expect(r.priceIncreaseNeeded, 6000000);
      expect(r.isProfit, isFalse);
    });

    test('profit', () {
      final r = ProfitLossCalculator.calculate(
        holding: _holding(quantityInLuong: 0.5, buyPricePerLuong: 100000000),
        currentBuyPricePerLuong: 110000000,
      );
      expect(r.profitLoss, 5000000);
      expect(r.profitLossPercent, closeTo(10, 1e-9));
      expect(r.isProfit, isTrue);
    });
  });

  group('ProfitLossCalculator.calculatePortfolio', () {
    test('aggregates active holdings and skips sold ones', () {
      final summary = ProfitLossCalculator.calculatePortfolio(
        holdings: [
          _holding(goldTypeId: 'sjc', quantityInLuong: 1, buyPricePerLuong: 120000000),
          _holding(goldTypeId: 'ring_9999', quantityInLuong: 2, buyPricePerLuong: 110000000),
          _holding(goldTypeId: 'sjc', quantityInLuong: 5, status: 'sold'),
        ],
        currentBuyPrices: {'sjc': 118000000, 'ring_9999': 112000000},
      );
      expect(summary.holdingCount, 2);
      expect(summary.totalCost, 340000000);
      expect(summary.totalCurrentValue, 342000000);
      expect(summary.totalProfitLoss, 2000000);
      expect(summary.totalQuantityInLuong, 3);
      expect(summary.breakEvenPricePerLuong, closeTo(113333333.33, 0.01));
    });

    test('falls back to buy price when no current price is known', () {
      final summary = ProfitLossCalculator.calculatePortfolio(
        holdings: [_holding(goldTypeId: 'jewelry')],
        currentBuyPrices: const {},
      );
      expect(summary.totalProfitLoss, 0);
    });
  });

  group('status thresholds', () {
    test('meme condition boundaries', () {
      expect(ProfitLossCalculator.getMemeCondition(10), MemeCondition.profitHigh);
      expect(ProfitLossCalculator.getMemeCondition(0), MemeCondition.profitLow);
      expect(ProfitLossCalculator.getMemeCondition(-0.5), MemeCondition.lossMinimal);
      expect(ProfitLossCalculator.getMemeCondition(-20), MemeCondition.lossSpiritual);
    });

    test('emotional status boundaries', () {
      expect(ProfitLossCalculator.getEmotionalStatus(3), EmotionalStatus.profitCautious);
      expect(ProfitLossCalculator.getEmotionalStatus(-1), EmotionalStatus.breakeven);
      expect(ProfitLossCalculator.getEmotionalStatus(-16), EmotionalStatus.lossSpiritual);
    });
  });
}
