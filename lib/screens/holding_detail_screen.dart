import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';
import '../utils/formatters.dart';
import '../utils/gold_units.dart';
import '../services/profit_loss_calculator.dart';
import '../services/meme_engine.dart';
import '../models/user_holding.dart';
import 'add_purchase_screen.dart';

/// Holding Detail Screen - Shows full details and P/L for a single gold holding.
class HoldingDetailScreen extends StatefulWidget {
  final String holdingId;

  const HoldingDetailScreen({super.key, required this.holdingId});

  @override
  State<HoldingDetailScreen> createState() => _HoldingDetailScreenState();
}

class _HoldingDetailScreenState extends State<HoldingDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final holding = store.holdings.where((h) => h.id == widget.holdingId).firstOrNull;
    final privacyMode = store.privacyMode;

    if (holding == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Không tìm thấy mục này',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final result = store.getHoldingResult(holding.id);
    final goldType = store.getGoldType(holding.goldTypeId);
    final displayName = goldType?.displayName ?? holding.goldTypeId;
    final isSold = holding.status == 'sold';

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value, holding, store),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
              const PopupMenuItem(value: 'duplicate', child: Text('Nhân bản')),
              const PopupMenuItem(value: 'sold', child: Text('Đánh dấu đã bán')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Xóa', style: TextStyle(color: AppColors.loss)),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // P/L Hero section
              _buildPLHero(result, isSold, privacyMode),
              if (result != null && !isSold) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTease(result, holding),
                ),
              ],
              const SizedBox(height: 16),
              // P/L details
              if (result != null && !isSold) ...[
                SectionHeader(title: 'Chi tiết lãi/lỗ'),
                _buildPLBreakdown(result, privacyMode),
                const SizedBox(height: 16),
              ],
              // Purchase info
              SectionHeader(title: 'Thông tin mua vào'),
              _buildPurchaseInfo(holding, goldType, privacyMode),
              const SizedBox(height: 16),
              // Unit conversion
              SectionHeader(title: 'Quy đổi đơn vị'),
              _buildUnitConversion(holding),
              const SizedBox(height: 16),
              // Note
              if (holding.note != null && holding.note!.isNotEmpty) ...[
                SectionHeader(title: 'Ghi chú'),
                AppCard(
                  child: Text(
                    holding.note!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Disclaimer
              const DisclaimerBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTease(ProfitLossResult result, UserHolding holding) {
    final tease = MemeEngine.getInlineTease(
      result.profitLossPercent,
      seed: 'detail_${holding.id}',
    );
    return TeaseLine(
      content: tease.content,
      emoji: tease.emoji,
      severityLevel: tease.severityLevel,
    );
  }

  Widget _buildPLHero(ProfitLossResult? result, bool isSold, bool privacyMode) {
    if (result == null || isSold) {
      return AppCard(
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 48, color: AppColors.neutral),
            const SizedBox(height: 12),
            const Text(
              'Mục này đã được bán',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final isProfit = result.isProfit;
    final color = isProfit ? AppColors.profit : AppColors.loss;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [AppColors.profitBg, AppColors.bgCard]
              : [AppColors.lossBg, AppColors.bgCard],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            isProfit ? 'Đang lãi 🎉' : 'Đang lỗ 😢',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // P/L amount
          Text(
            privacyMode ? '••••••' : Formatters.formatVnd(result.profitLoss),
            style: TextStyle(
              color: privacyMode ? AppColors.textHint : color,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          // P/L percentage
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              privacyMode
                  ? '••••'
                  : Formatters.formatPercent(result.profitLossPercent),
              style: TextStyle(
                color: privacyMode ? AppColors.textHint : color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPLBreakdown(ProfitLossResult result, bool privacyMode) {
    final isProfit = result.isProfit;
    final color = isProfit ? AppColors.profit : AppColors.loss;

    return AppCard(
      child: Column(
        children: [
          _detailRow(
            'Giá mua vào hiện tại',
            privacyMode ? '••••••' : '${Formatters.formatVnd(result.currentBuyPricePerLuong)}/lượng',
            AppColors.textPrimary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Giá trị hiện tại',
            privacyMode ? '••••••' : Formatters.formatVnd(result.currentValue),
            AppColors.textPrimary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Tổng vốn đầu tư',
            privacyMode ? '••••••' : Formatters.formatVnd(result.totalCost),
            AppColors.textPrimary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Lãi / Lỗ',
            privacyMode ? '••••••' : Formatters.formatVnd(result.profitLoss),
            privacyMode ? AppColors.textHint : color,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Giá hòa vốn',
            privacyMode ? '••••••' : '${Formatters.formatVnd(result.breakEvenPricePerLuong)}/lượng',
            AppColors.textPrimary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Cần giá tăng thêm để hòa vốn',
            privacyMode
                ? '••••••'
                : result.priceIncreaseNeeded > 0
                    ? '${Formatters.formatVnd(result.priceIncreaseNeeded)}/lượng'
                    : 'Đã hòa vốn rồi 👍',
            result.priceIncreaseNeeded > 0 ? AppColors.warning : AppColors.profit,
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseInfo(UserHolding holding, dynamic goldType, bool privacyMode) {
    return AppCard(
      child: Column(
        children: [
          _detailRow(
            'Loại vàng',
            goldType?.displayName ?? holding.goldTypeId,
            AppColors.textPrimary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Số lượng',
            Formatters.formatQuantity(holding.quantity, holding.unit),
            AppColors.textPrimary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Tương đương',
            '${holding.quantityInLuong.toStringAsFixed(4)} lượng',
            AppColors.textSecondary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Giá mua / đơn vị',
            privacyMode
                ? '••••'
                : '${Formatters.formatVnd(GoldUnits.priceFromLuong(holding.buyPricePerLuong, holding.unit))}/${GoldUnits.shortLabel(holding.unit)}',
            AppColors.textPrimary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Giá mua / lượng',
            privacyMode ? '••••' : Formatters.formatVnd(holding.buyPricePerLuong),
            AppColors.textSecondary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Phí phát sinh',
            privacyMode ? '•••' : Formatters.formatVnd(holding.fee),
            AppColors.textSecondary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Tổng vốn',
            privacyMode ? '••••••' : Formatters.formatVnd(holding.totalCost),
            AppColors.textPrimary,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _detailRow(
            'Ngày mua',
            Formatters.formatDate(holding.buyDate),
            AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildUnitConversion(UserHolding holding) {
    final inLuong = holding.quantityInLuong;
    final inChi = GoldUnits.fromLuong(inLuong, 'chi');
    final inPhan = GoldUnits.fromLuong(inLuong, 'phan');
    final inGram = GoldUnits.fromLuong(inLuong, 'gram');

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _unitColumn('Lượng', inLuong.toStringAsFixed(2)),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _unitColumn('Chỉ', inChi.toStringAsFixed(2)),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _unitColumn('Phân', inPhan.toStringAsFixed(2)),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _unitColumn('Gram', inGram.toStringAsFixed(2)),
          ),
        ],
      ),
    );
  }

  Widget _unitColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    UserHolding holding,
    AppStore store,
  ) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddPurchaseScreen(initialGoldTypeId: holding.goldTypeId),
          ),
        );
        break;
      case 'duplicate':
        store.duplicateHolding(holding.id);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã nhân bản mục này'),
            backgroundColor: AppColors.bgCard,
          ),
        );
        break;
      case 'sold':
        _confirmMarkAsSold(context, holding.id, store);
        break;
      case 'delete':
        _confirmDelete(context, holding.id, store);
        break;
    }
  }

  void _confirmMarkAsSold(BuildContext context, String id, AppStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Đánh dấu đã bán?'),
        content: const Text(
          'Mục này sẽ được chuyển sang trạng thái đã bán. Bạn vẫn có thể xem lại thông tin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              store.markAsSold(id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã đánh dấu là đã bán'),
                  backgroundColor: AppColors.bgCard,
                ),
              );
            },
            child: const Text('Xác nhận', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, AppStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Xóa mục này?'),
        content: const Text(
          'Hành động này không thể hoàn tác. Bạn có chắc muốn xóa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              store.deleteHolding(id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa mục này'),
                  backgroundColor: AppColors.bgCard,
                ),
              );
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
  }
}
