import 'historical_comparison_calculator.dart';
import '../models/historical_gold_price.dart';
import '../utils/formatters.dart';

/// HistoricalMemeGenerator — sinh câu "hỏi đểu" dựa trên so sánh giá hiện
/// tại/mức lỗ của user với lịch sử giá SJC.
///
/// Khác `MemeEngine` (chọn nội dung tĩnh từ `MemeDatabase` theo % lãi/lỗ),
/// câu chữ ở đây chèn số liệu thực (ngày tháng, %, số tháng tính từ
/// `HistoricalComparisonCalculator`) nên được ghép từ template + số liệu
/// thay vì lấy nguyên văn có sẵn.
class HistoricalMemeGenerator {
  /// Sinh 1 câu meme theo tình huống phù hợp nhất:
  /// 1. User đang lỗ và có giai đoạn lỗ lịch sử tương tự → so sánh trực tiếp.
  /// 2. Còn lại (không lỗ / chưa có holding) → so giá hiện tại với đỉnh lịch sử.
  static String generate({
    required List<HistoricalPricePoint> series,
    required double currentPrice,
    double? userProfitLossPercent,
  }) {
    if (series.isEmpty) {
      return 'Chưa có dữ liệu lịch sử để so sánh — đang tải hoặc nguồn tạm gián đoạn.';
    }

    if (userProfitLossPercent != null && userProfitLossPercent < 0) {
      final drawdowns = HistoricalComparisonCalculator.findDrawdowns(series);
      final closest = HistoricalComparisonCalculator.findClosestDrawdown(
        drawdowns,
        userProfitLossPercent,
      );
      if (closest != null) {
        return _drawdownMeme(closest);
      }
    }

    return _peakComparisonMeme(series, currentPrice);
  }

  static String _drawdownMeme(DrawdownPeriod d) {
    final peakLabel = Formatters.formatDate(d.peakDate);
    final historyPercent = d.maxDrawdownPercent.toStringAsFixed(1);

    if (d.hasRecovered) {
      final months = (d.daysToRecover! / 30).round();
      final variants = [
        'Không phải mình bạn đâu. Đỉnh ngày $peakLabel, giá cũng từng rớt '
            '$historyPercent% y như bạn — và mất $months tháng mới về bờ. Ráng chờ! 🧘',
        'Lịch sử lặp lại: đỉnh $peakLabel từng lỗ $historyPercent% giống bạn '
            'hiện tại, sau $months tháng mới hồi phục. Có tiền lệ rồi, yên tâm... hoặc không 😅',
      ];
      return variants[_dailySeed % variants.length];
    }

    final variants = [
      'Đỉnh $peakLabel từng lỗ $historyPercent% giống bạn — và tính tới nay '
          'vẫn CHƯA hồi phục. Chúc may mắn hơn phiên bản đó của lịch sử 🙏',
      'Mức lỗ $historyPercent% từ đỉnh $peakLabel giống bạn hiện tại vẫn còn '
          'mắc kẹt tới tận bây giờ. Không phải lời động viên đâu 😬',
    ];
    return variants[_dailySeed % variants.length];
  }

  static String _peakComparisonMeme(
    List<HistoricalPricePoint> series,
    double currentPrice,
  ) {
    final high = HistoricalComparisonCalculator.allTimeHigh(series)!;
    if (currentPrice >= high.buyPrice) {
      return 'Giá hiện tại đã vượt đỉnh lịch sử (${Formatters.formatDate(high.date)}, '
          '${Formatters.formatVndCompact(high.buyPrice)}) — vàng đang lập kỷ lục mới. '
          'Đu đúng sóng hay đu đỉnh, tính sau 🚀';
    }
    final percentBelow = HistoricalComparisonCalculator.percentVsHigh(
      currentPrice,
      high.buyPrice,
    ).abs();
    return 'Giá hiện tại còn thấp hơn đỉnh lịch sử (${Formatters.formatDate(high.date)}) '
        '${percentBelow.toStringAsFixed(1)}%. Đỉnh vẫn còn đó chờ ngày quay lại 🫡';
  }

  static int get _dailySeed =>
      DateTime.now().difference(DateTime(2025, 1, 1)).inDays;
}
