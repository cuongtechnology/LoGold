import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';
import '../models/historical_gold_price.dart';
import '../services/historical_comparison_calculator.dart';
import '../services/historical_meme_generator.dart';
import '../services/profit_loss_calculator.dart';
import '../utils/formatters.dart';

/// Màn "So sánh lịch sử" — đối chiếu giá hiện tại/giá mua của user với chuỗi
/// giá SJC lịch sử (2009 → nay, xem `HistoricalPriceService`), kèm meme
/// "hỏi đểu" dựng từ số liệu thực thay vì câu tĩnh.
class HistoricalComparisonScreen extends StatelessWidget {
  const HistoricalComparisonScreen({super.key});

  static const _chartMaxPoints = 400;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final series = store.historicalPrices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('So sánh lịch sử'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại dữ liệu lịch sử',
            onPressed: () => context.read<AppStore>().loadHistoricalPrices(
                  forceRefresh: true,
                ),
          ),
        ],
      ),
      body: SafeArea(
        child: series.isEmpty
            ? EmptyState(
                emoji: '📜',
                title: 'Chưa có dữ liệu lịch sử',
                subtitle: store.historicalPriceStatusMessage.isNotEmpty
                    ? store.historicalPriceStatusMessage
                    : 'Đang tải dữ liệu lần đầu...',
                actionText: 'Thử lại',
                onAction: () =>
                    context.read<AppStore>().loadHistoricalPrices(
                          forceRefresh: true,
                        ),
              )
            : _buildContent(context, store, series),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppStore store,
    List<HistoricalPricePoint> series,
  ) {
    final currentPrice = store.getBuyPrice('sjc') ?? series.last.buyPrice;

    final sjcHoldings =
        store.activeHoldings.where((h) => h.goldTypeId == 'sjc').toList();
    final sjcSummary = sjcHoldings.isEmpty
        ? null
        : ProfitLossCalculator.calculatePortfolio(
            holdings: sjcHoldings,
            currentBuyPrices: {'sjc': currentPrice},
          );

    final meme = HistoricalMemeGenerator.generate(
      series: series,
      currentPrice: currentPrice,
      userProfitLossPercent: sjcSummary?.totalProfitLossPercent,
    );

    final high = HistoricalComparisonCalculator.allTimeHigh(series)!;
    final low = HistoricalComparisonCalculator.allTimeLow(series)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          MemeCard(
            title: 'SO VỚI LỊCH SỬ',
            content: meme,
            emoji: _memeEmoji(sjcSummary?.totalProfitLossPercent),
            severityLevel: _memeSeverity(sjcSummary?.totalProfitLossPercent),
          ),
          const SizedBox(height: 8),
          _buildChartCard(series, sjcSummary?.breakEvenPricePerLuong),
          const SizedBox(height: 8),
          _buildExtremesCard(high, low, currentPrice, sjcSummary),
          const SizedBox(height: 8),
          _buildDisclaimer(series, store),
        ],
      ),
    );
  }

  String _memeEmoji(double? profitLossPercent) {
    if (profitLossPercent == null || profitLossPercent >= 0) return '🕰️';
    if (profitLossPercent >= -3) return '😅';
    if (profitLossPercent >= -7) return '😣';
    if (profitLossPercent >= -15) return '😭';
    return '🧘';
  }

  int _memeSeverity(double? profitLossPercent) {
    if (profitLossPercent == null || profitLossPercent >= 0) return 0;
    if (profitLossPercent >= -3) return 1;
    if (profitLossPercent >= -7) return 2;
    if (profitLossPercent >= -15) return 3;
    return 4;
  }

  Widget _buildChartCard(
    List<HistoricalPricePoint> series,
    double? userAvgBuyPrice,
  ) {
    final sampled = _downsample(series, _chartMaxPoints);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text(
                'Lịch sử giá SJC (mua vào)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: LineChart(_buildLineChartData(sampled, userAvgBuyPrice)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.formatDate(series.first.date),
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
              if (userAvgBuyPrice != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 2,
                      color: AppColors.loss,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Giá bạn mua trung bình',
                      style: TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                  ],
                ),
              Text(
                Formatters.formatDate(series.last.date),
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(
    List<HistoricalPricePoint> sampled,
    double? userAvgBuyPrice,
  ) {
    final spots = <FlSpot>[
      for (var i = 0; i < sampled.length; i++)
        FlSpot(i.toDouble(), sampled[i].buyPrice / 1000000),
    ];

    final prices = sampled.map((e) => e.buyPrice / 1000000).toList();
    var minPrice = prices.reduce((a, b) => a < b ? a : b);
    var maxPrice = prices.reduce((a, b) => a > b ? a : b);
    if (userAvgBuyPrice != null) {
      final avg = userAvgBuyPrice / 1000000;
      minPrice = minPrice < avg ? minPrice : avg;
      maxPrice = maxPrice > avg ? maxPrice : avg;
    }
    final padding = (maxPrice - minPrice) * 0.1;
    final effectivePadding = padding == 0 ? 1.0 : padding;

    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: AppColors.gold,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: AppColors.gold.withValues(alpha: 0.1),
        ),
      ),
    ];

    if (userAvgBuyPrice != null && spots.isNotEmpty) {
      final avg = userAvgBuyPrice / 1000000;
      lineBars.add(
        LineChartBarData(
          spots: [
            FlSpot(0, avg),
            FlSpot(spots.length - 1, avg),
          ],
          isCurved: false,
          color: AppColors.loss,
          barWidth: 1.5,
          dashArray: [6, 4],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return LineChartData(
      minX: 0,
      maxX: (spots.length - 1).toDouble(),
      minY: minPrice - effectivePadding,
      maxY: maxPrice + effectivePadding,
      lineBarsData: lineBars,
      titlesData: const FlTitlesData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxPrice - minPrice) / 4,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: AppColors.divider,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  Widget _buildExtremesCard(
    HistoricalPricePoint high,
    HistoricalPricePoint low,
    double currentPrice,
    PortfolioSummary? sjcSummary,
  ) {
    final percentVsHigh =
        HistoricalComparisonCalculator.percentVsHigh(currentPrice, high.buyPrice);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đỉnh & đáy lịch sử',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _extremeItem(
                  'Đỉnh cao nhất',
                  Formatters.formatVndCompact(high.buyPrice),
                  Formatters.formatDate(high.date),
                  AppColors.profit,
                ),
              ),
              Expanded(
                child: _extremeItem(
                  'Đáy thấp nhất',
                  Formatters.formatVndCompact(low.buyPrice),
                  Formatters.formatDate(low.date),
                  AppColors.loss,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgCardHighlight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Giá hiện tại so với đỉnh',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                Text(
                  Formatters.formatPercent(percentVsHigh),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (sjcSummary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgCardHighlight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Giá bạn mua so với đỉnh',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  Text(
                    Formatters.formatPercent(
                      HistoricalComparisonCalculator.percentVsHigh(
                        sjcSummary.breakEvenPricePerLuong,
                        high.buyPrice,
                      ),
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _extremeItem(
    String label,
    String value,
    String dateLabel,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          dateLabel,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDisclaimer(List<HistoricalPricePoint> series, AppStore store) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Dữ liệu SJC ${Formatters.formatDate(series.first.date)} - '
        '${Formatters.formatDate(series.last.date)} từ giavang.org. '
        '${store.historicalPriceStatusMessage}',
        style: const TextStyle(color: AppColors.textHint, fontSize: 11),
      ),
    );
  }

  List<HistoricalPricePoint> _downsample(
    List<HistoricalPricePoint> series,
    int maxPoints,
  ) {
    if (series.length <= maxPoints) return series;
    final step = (series.length / maxPoints).ceil();
    final result = <HistoricalPricePoint>[
      for (var i = 0; i < series.length; i += step) series[i],
    ];
    if (!identical(result.last, series.last)) {
      result.add(series.last);
    }
    return result;
  }
}
