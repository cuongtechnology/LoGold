import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';
import '../utils/formatters.dart';
import '../services/profit_loss_calculator.dart';
import '../services/meme_engine.dart';
import '../components/banner_ad_widget.dart';
import '../models/user_holding.dart';
import 'add_purchase_screen.dart';
import 'holding_detail_screen.dart';

/// Portfolio Screen - Full list of gold holdings with P/L details.
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  String _filter = 'active'; // 'active' or 'all'

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final allHoldings = store.holdings;
    final holdings = _filter == 'active'
        ? store.activeHoldings
        : allHoldings;
    final privacyMode = store.privacyMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục vàng'),
        actions: [
          IconButton(
            onPressed: store.togglePrivacyMode,
            icon: Icon(
              store.privacyMode ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _filterChip('Đang giữ', 'active'),
                  const SizedBox(width: 8),
                  _filterChip('Tất cả', 'all'),
                  const Spacer(),
                  Text(
                    '${holdings.length} mục',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Holdings list
            Expanded(
              child: holdings.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: holdings.length + 1,
                      itemBuilder: (context, index) {
                        if (index == holdings.length) {
                          return const BannerAdWidget();
                        }
                        final holding = holdings[index];
                        return _buildHoldingCard(
                          context,
                          holding,
                          store.getHoldingResult(holding.id),
                          store.getGoldType(holding.goldTypeId),
                          privacyMode,
                        );
                      },
                    ),
            ),
            const DisclaimerBar(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAdd(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHoldingCard(
    BuildContext context,
    UserHolding holding,
    ProfitLossResult? result,
    dynamic goldType,
    bool privacyMode,
  ) {
    final isSold = holding.status == 'sold';
    final isProfit = result?.isProfit ?? false;
    final color = isProfit ? AppColors.profit : AppColors.loss;
    final displayName = goldType?.displayName ?? holding.goldTypeId;

    return AppCard(
      onTap: () => _navigateToDetail(context, holding.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: gold type + status
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: AppColors.gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isSold) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.neutral.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Đã bán',
                              style: TextStyle(
                                color: AppColors.neutral,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.formatQuantity(holding.quantity, holding.unit)} · ${Formatters.formatDate(holding.buyDate)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // P/L section
          if (result != null && !isSold)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isProfit ? AppColors.profitBg : AppColors.lossBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _infoColumn(
                      'Giá trị hiện tại',
                      privacyMode ? '••••••' : Formatters.formatVnd(result.currentValue),
                      AppColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: _infoColumn(
                      'Tổng vốn',
                      privacyMode ? '••••••' : Formatters.formatVnd(result.totalCost),
                      AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: _infoColumn(
                      'Lãi/Lỗ',
                      privacyMode
                          ? '••••••'
                          : Formatters.formatVnd(result.profitLoss),
                      privacyMode ? AppColors.textHint : color,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgCardHighlight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _infoColumn(
                      'Tổng vốn',
                      privacyMode ? '••••••' : Formatters.formatVnd(holding.totalCost),
                      AppColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: _infoColumn(
                      'Giá mua/lượng',
                      privacyMode ? '••••' : Formatters.formatVnd(holding.buyPricePerLuong),
                      AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // P/L percentage bar
          if (result != null && !isSold) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  privacyMode
                      ? '••••'
                      : Formatters.formatPercent(result.profitLossPercent),
                  style: TextStyle(
                    color: privacyMode ? AppColors.textHint : color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                if (!privacyMode)
                  Text(
                    result.isProfit ? '🎉 Đang lãi' : '💸 Đang lỗ',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTease(result, holding),
          ],
          // Note
          if (holding.note != null && holding.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgCardHighlight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      holding.note!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildTease(ProfitLossResult result, UserHolding holding) {
    final tease = MemeEngine.getInlineTease(
      result.profitLossPercent,
      seed: holding.id,
    );
    return TeaseLine(
      content: tease.content,
      emoji: tease.emoji,
      severityLevel: tease.severityLevel,
    );
  }

  Widget _infoColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      emoji: '📭',
      title: 'Chưa có vàng nào',
      subtitle: 'Thêm lần mua vàng để theo dõi lãi/lỗ',
      actionText: 'Thêm vàng ngay',
      onAction: () => _navigateToAdd(context),
    );
  }

  void _navigateToAdd(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPurchaseScreen()),
    );
  }

  void _navigateToDetail(BuildContext context, String holdingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HoldingDetailScreen(holdingId: holdingId),
      ),
    );
  }
}
