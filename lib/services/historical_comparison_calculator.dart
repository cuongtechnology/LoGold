import '../models/historical_gold_price.dart';

/// HistoricalComparisonCalculator — pure functions so sánh giá hiện tại/giá
/// mua của user với chuỗi giá SJC lịch sử (`HistoricalPriceService`). Không
/// giữ state, giống `ProfitLossCalculator`.
class HistoricalComparisonCalculator {
  static HistoricalPricePoint? allTimeHigh(List<HistoricalPricePoint> series) {
    if (series.isEmpty) return null;
    return series.reduce((a, b) => a.buyPrice >= b.buyPrice ? a : b);
  }

  static HistoricalPricePoint? allTimeLow(List<HistoricalPricePoint> series) {
    if (series.isEmpty) return null;
    return series.reduce((a, b) => a.buyPrice <= b.buyPrice ? a : b);
  }

  /// % chênh lệch của [price] so với [highPrice]. Âm nghĩa là thấp hơn đỉnh.
  static double percentVsHigh(double price, double highPrice) {
    if (highPrice <= 0) return 0;
    return (price - highPrice) / highPrice * 100;
  }

  /// Tìm toàn bộ giai đoạn "đỉnh → đáy → (hồi phục)" trong series, bỏ qua
  /// các giai đoạn quá nông (< [minDrawdownPercent], mặc định 1%) để tránh
  /// nhiễu do dao động ngày-qua-ngày.
  static List<DrawdownPeriod> findDrawdowns(
    List<HistoricalPricePoint> series, {
    double minDrawdownPercent = 1.0,
  }) {
    if (series.length < 2) return const [];

    final raw = <DrawdownPeriod>[];
    var peakIdx = 0;
    var troughIdx = 0;
    var inDrawdown = false;

    for (var i = 1; i < series.length; i++) {
      if (series[i].buyPrice >= series[peakIdx].buyPrice) {
        if (inDrawdown) {
          raw.add(DrawdownPeriod(
            peakDate: series[peakIdx].date,
            peakPrice: series[peakIdx].buyPrice,
            troughDate: series[troughIdx].date,
            troughPrice: series[troughIdx].buyPrice,
            recoveryDate: series[i].date,
          ));
          inDrawdown = false;
        }
        peakIdx = i;
      } else {
        if (!inDrawdown || series[i].buyPrice < series[troughIdx].buyPrice) {
          troughIdx = i;
        }
        inDrawdown = true;
      }
    }

    // Giai đoạn lỗ còn dang dở tới hết dữ liệu (chưa hồi phục).
    if (inDrawdown) {
      raw.add(DrawdownPeriod(
        peakDate: series[peakIdx].date,
        peakPrice: series[peakIdx].buyPrice,
        troughDate: series[troughIdx].date,
        troughPrice: series[troughIdx].buyPrice,
        recoveryDate: null,
      ));
    }

    return raw.where((d) => d.maxDrawdownPercent <= -minDrawdownPercent).toList();
  }

  /// Trong các giai đoạn lỗ lịch sử, tìm giai đoạn có mức lỗ gần với
  /// [targetLossPercent] nhất (cả 2 đều âm). Trả null nếu không có giai đoạn
  /// nào hoặc [targetLossPercent] không phải mức lỗ (>= 0).
  static DrawdownPeriod? findClosestDrawdown(
    List<DrawdownPeriod> drawdowns,
    double targetLossPercent,
  ) {
    if (drawdowns.isEmpty || targetLossPercent >= 0) return null;
    var best = drawdowns.first;
    var bestDiff = (best.maxDrawdownPercent - targetLossPercent).abs();
    for (final d in drawdowns.skip(1)) {
      final diff = (d.maxDrawdownPercent - targetLossPercent).abs();
      if (diff < bestDiff) {
        best = d;
        bestDiff = diff;
      }
    }
    return best;
  }

  /// Giai đoạn lỗ sâu nhất từng ghi nhận trong lịch sử.
  static DrawdownPeriod? deepestDrawdown(List<DrawdownPeriod> drawdowns) {
    if (drawdowns.isEmpty) return null;
    return drawdowns.reduce(
      (a, b) => a.maxDrawdownPercent <= b.maxDrawdownPercent ? a : b,
    );
  }
}

/// Giai đoạn giá đi từ đỉnh xuống đáy rồi (có thể) hồi phục lại đỉnh cũ.
class DrawdownPeriod {
  final DateTime peakDate;
  final double peakPrice;
  final DateTime troughDate;
  final double troughPrice;
  final DateTime? recoveryDate; // null = tới hết dữ liệu vẫn chưa hồi phục

  DrawdownPeriod({
    required this.peakDate,
    required this.peakPrice,
    required this.troughDate,
    required this.troughPrice,
    this.recoveryDate,
  });

  double get maxDrawdownPercent =>
      peakPrice > 0 ? (troughPrice - peakPrice) / peakPrice * 100 : 0;

  int get daysToTrough => troughDate.difference(peakDate).inDays;

  int? get daysToRecover => recoveryDate?.difference(peakDate).inDays;

  bool get hasRecovered => recoveryDate != null;
}
