import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';
import '../utils/formatters.dart';
import '../models/gold_price.dart';
import '../models/gold_type.dart';
import '../models/historical_gold_price.dart';
import '../api/price_adapter.dart';
import '../services/meme_engine.dart';
import 'price_alert_screen.dart';

/// Gold Price Table Screen - Shows current buy/sell prices for all gold types.
/// Có bộ lọc theo ngày: mặc định "Hôm nay" dùng giá live; chọn ngày quá khứ
/// thì tra lịch sử theo từng loại vàng (`AppStore.historicalPricesFor`) —
/// mỗi loại có độ sâu dữ liệu khác nhau (xem `HistoricalPriceService`), loại
/// nào không có dữ liệu quanh ngày đó thì hiện rõ thay vì hiện nhầm giá hôm nay.
class PriceTableScreen extends StatefulWidget {
  const PriceTableScreen({super.key});

  @override
  State<PriceTableScreen> createState() => _PriceTableScreenState();
}

class _PriceTableScreenState extends State<PriceTableScreen> {
  DateTime _selectedDate = _dateOnly(DateTime.now());
  bool _loadingHistorical = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday => _isSameDate(_selectedDate, _dateOnly(DateTime.now()));

  Future<void> _selectDate(DateTime date, AppStore store) async {
    setState(() => _selectedDate = date);
    if (_isSameDate(date, _dateOnly(DateTime.now()))) return;

    setState(() => _loadingHistorical = true);
    await Future.wait(
      store.goldTypes.map((gt) => store.loadHistoricalPricesFor(gt.id)),
    );
    if (mounted) setState(() => _loadingHistorical = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final prices = store.prices;
    final goldTypes = store.goldTypes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng giá vàng'),
        actions: [
          IconButton(
            onPressed: () => store.refreshPrices(),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          ),
          IconButton(
            onPressed: () => _navigateToAlerts(context),
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => store.refreshPrices(),
          child: CustomScrollView(
            slivers: [
              // Status header
              SliverToBoxAdapter(child: _buildStatusHeader(store)),
              // Bộ lọc theo ngày
              SliverToBoxAdapter(child: _buildDateFilterRow(context, store)),
              if (!_isToday)
                ...[
                  if (_loadingHistorical)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final goldType = goldTypes[index];
                          return _buildHistoricalPriceCard(goldType, store);
                        },
                        childCount: goldTypes.length,
                      ),
                    ),
                ]
              else ...[
                if (prices.isNotEmpty)
                  SliverToBoxAdapter(child: _buildPriceTease(prices)),
                // Price cards
                if (prices.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final price = prices[index];
                        final goldType = goldTypes.where((g) => g.id == price.goldTypeId).firstOrNull;
                        return _buildPriceCard(context, price, goldType, store);
                      },
                      childCount: prices.length,
                    ),
                  ),
              ],
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // Disclaimer
              const SliverToBoxAdapter(child: DisclaimerBar()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterRow(BuildContext context, AppStore store) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final lastMonth = _dateOnly(DateTime(now.year, now.month - 1, now.day));
    final lastYear = _dateOnly(DateTime(now.year - 1, now.month, now.day));

    final quickOptions = <(String, DateTime)>[
      ('Hôm nay', today),
      ('Tháng trước', lastMonth),
      ('Năm trước', lastYear),
    ];
    final isQuickSelected =
        quickOptions.any((o) => _isSameDate(_selectedDate, o.$2));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          ...quickOptions.map((opt) {
            final selected = _isSameDate(_selectedDate, opt.$2);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(opt.$1),
                selected: selected,
                onSelected: (_) => _selectDate(opt.$2, store),
                selectedColor: AppColors.gold.withValues(alpha: 0.2),
                checkmarkColor: AppColors.gold,
                labelStyle: TextStyle(
                  color: selected ? AppColors.gold : AppColors.textSecondary,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected ? AppColors.gold : AppColors.divider,
                ),
              ),
            );
          }),
          ActionChip(
            avatar: Icon(
              Icons.calendar_today,
              size: 16,
              color: isQuickSelected ? AppColors.textSecondary : AppColors.gold,
            ),
            label: Text(
              isQuickSelected ? 'Chọn ngày' : Formatters.formatDate(_selectedDate),
            ),
            onPressed: () => _pickDate(context, store),
            backgroundColor: isQuickSelected
                ? AppColors.bgCard
                : AppColors.gold.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: isQuickSelected ? AppColors.textSecondary : AppColors.gold,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isQuickSelected ? AppColors.divider : AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, AppStore store) async {
    final firstDate = store.historicalPrices.isNotEmpty
        ? store.historicalPrices.first.date
        : DateTime(2009, 7, 22);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày xem giá',
    );
    if (picked != null) {
      await _selectDate(_dateOnly(picked), store);
    }
  }

  /// Tìm điểm giá lịch sử gần [target] nhất trong [series] (tối đa lệch
  /// [maxDeltaDays] ngày — dữ liệu có thể thiếu do cuối tuần/lễ/nguồn gián
  /// đoạn). Trả null nếu không có điểm nào đủ gần.
  HistoricalPricePoint? _findNearestHistoricalPoint(
    List<HistoricalPricePoint> series,
    DateTime target, {
    int maxDeltaDays = 5,
  }) {
    HistoricalPricePoint? best;
    var bestDelta = maxDeltaDays + 1;
    for (final p in series) {
      final delta = p.date.difference(target).inDays.abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = p;
      }
    }
    return bestDelta <= maxDeltaDays ? best : null;
  }

  Widget _buildHistoricalPriceCard(GoldType goldType, AppStore store) {
    final series = store.historicalPricesFor(goldType.id);
    if (series.isEmpty) {
      return _historicalPlaceholderCard(
        goldType,
        'Chưa có dữ liệu lịch sử cho loại này',
      );
    }

    final point = _findNearestHistoricalPoint(series, _selectedDate);
    if (point == null) {
      return _historicalPlaceholderCard(
        goldType,
        'Không có dữ liệu quanh ngày ${Formatters.formatDate(_selectedDate)}',
      );
    }

    final matchedExactly = _isSameDate(point.date, _selectedDate);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.monetization_on, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goldType.displayName,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      matchedExactly
                          ? 'Ngày ${Formatters.formatDate(point.date)}'
                          : 'Gần nhất: ${Formatters.formatDate(point.date)}',
                      style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _priceColumn(
                  'Giá mua vào',
                  '(Cửa hàng trả bạn)',
                  Formatters.formatVnd(point.buyPrice),
                  AppColors.profit,
                ),
              ),
              Container(width: 1, height: 50, color: AppColors.divider),
              Expanded(
                child: _priceColumn(
                  'Giá bán ra',
                  '(Cửa hàng bán bạn)',
                  Formatters.formatVnd(point.sellPrice),
                  AppColors.loss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historicalPlaceholderCard(GoldType goldType, String message) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history_toggle_off, color: AppColors.textHint, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goldType.displayName,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(AppStore store) {
    final status = store.priceStatus;
    Color statusColor;
    String statusText;

    switch (status) {
      case PriceSourceStatus.fresh:
        statusColor = AppColors.profit;
        statusText = store.priceStatusMessage;
        break;
      case PriceSourceStatus.stale:
        statusColor = AppColors.warning;
        statusText = 'Dữ liệu có thể cũ';
        break;
      case PriceSourceStatus.error:
        statusColor = AppColors.loss;
        // Show real error để debug — nếu quá dài UI cắt.
        statusText = store.priceStatusMessage.isEmpty
            ? 'Lỗi tải giá'
            : 'Lỗi: ${store.priceStatusMessage}';
        break;
      case PriceSourceStatus.unavailable:
        statusColor = AppColors.neutral;
        statusText = store.priceStatusMessage;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          Text(
            Formatters.formatDateTime(DateTime.now()),
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTease(List<GoldPrice> prices) {
    // Trung bình % thay đổi giá mua vào — map sang mức "P/L" giả để chọn tease.
    // Giá tăng = user đang lãi tưởng tượng → chọn meme profitLow/Medium.
    // Giá giảm = user đang lỗ → chọn meme lossLight/Moderate.
    double totalPct = 0;
    int counted = 0;
    for (final p in prices) {
      if (p.buyPrice <= 0) continue;
      final change = p.buyPriceChange;
      totalPct += (change / p.buyPrice) * 100;
      counted++;
    }
    final avgPct = counted == 0 ? 0.0 : totalPct / counted;
    // Nhân 3 để khuếch đại (biến động giá vàng theo ngày thường nhỏ).
    final tease = MemeEngine.getInlineTease(avgPct * 3, seed: 'price_table_header');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TeaseLine(
        content: tease.content,
        emoji: tease.emoji,
        severityLevel: tease.severityLevel,
      ),
    );
  }

  Widget _buildPriceCard(
    BuildContext context,
    GoldPrice price,
    GoldType? goldType,
    AppStore store,
  ) {
    final displayName = goldType?.displayName ?? price.goldTypeId;
    final defaultUnit = goldType?.defaultUnit ?? 'luong';
    final buyChange = price.buyPriceChange;

    // Convert prices to per-unit display
    final buyPricePerUnit = _pricePerUnit(price.buyPrice, defaultUnit);
    final sellPricePerUnit = _pricePerUnit(price.sellPrice, defaultUnit);
    final buyChangePerUnit = _pricePerUnit(buyChange, defaultUnit);

    final isBuyUp = buyChange > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold type name
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.monetization_on, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Đơn vị: ${_unitLabel(defaultUnit)}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Change indicator
              if (buyChange != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBuyUp ? AppColors.profitBg : AppColors.lossBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBuyUp ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: isBuyUp ? AppColors.profit : AppColors.loss,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isBuyUp ? '+' : ''}${Formatters.formatVnd(buyChangePerUnit)}',
                        style: TextStyle(
                          color: isBuyUp ? AppColors.profit : AppColors.loss,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Buy/Sell prices
          Row(
            children: [
              Expanded(
                child: _priceColumn(
                  'Giá mua vào',
                  '(Cửa hàng trả bạn)',
                  Formatters.formatVnd(buyPricePerUnit),
                  AppColors.profit,
                ),
              ),
              Container(width: 1, height: 50, color: AppColors.divider),
              Expanded(
                child: _priceColumn(
                  'Giá bán ra',
                  '(Cửa hàng bán bạn)',
                  Formatters.formatVnd(sellPricePerUnit),
                  AppColors.loss,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Spread
          Row(
            children: [
              const Text(
                'Chênh lệch (spread):',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                Formatters.formatVnd(_pricePerUnit(price.spread, defaultUnit)),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceColumn(String label, String sublabel, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  double _pricePerUnit(double pricePerLuong, String unit) {
    if (unit == 'luong') return pricePerLuong;
    if (unit == 'chi') return pricePerLuong / 10;
    if (unit == 'gram') return pricePerLuong / 37.5;
    return pricePerLuong;
  }

  String _unitLabel(String unit) {
    switch (unit) {
      case 'luong':
        return 'Lượng';
      case 'chi':
        return 'Chỉ';
      case 'gram':
        return 'Gram';
      default:
        return unit;
    }
  }

  void _navigateToAlerts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PriceAlertScreen()),
    );
  }
}
