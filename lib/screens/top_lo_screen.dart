import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';
import '../utils/formatters.dart';
import '../services/meme_engine.dart';
import '../services/profit_loss_calculator.dart';
import '../components/banner_ad_widget.dart';
import 'holding_detail_screen.dart';

/// Top Lỗ Screen - ranks the user's active holdings by P/L%, deepest loss first.
/// Every row carries an inline "nói đểu" tease; the header and empty state
/// switch tone based on whether the user has any losses at all.
class TopLoScreen extends StatelessWidget {
  const TopLoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final privacyMode = store.privacyMode;
    final losers = store.topLosers;
    final actualLosers = losers.where((r) => !r.isProfit).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Lỗ nhiều nhất'),
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
        child: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => store.refreshPrices(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(store, actualLosers)),
              if (losers.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else ...[
                if (actualLosers.isEmpty)
                  SliverToBoxAdapter(child: _buildAllProfitBanner())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildLoserRow(
                        context,
                        index + 1,
                        losers[index],
                        store,
                        privacyMode,
                      ),
                      childCount: losers.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: BannerAdWidget()),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const SliverToBoxAdapter(child: DisclaimerBar()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppStore store, List<ProfitLossResult> actualLosers) {
    final summary = store.portfolioSummary;
    final privacyMode = store.privacyMode;
    final totalLoss = actualLosers.fold<double>(
      0,
      (sum, r) => sum + r.profitLoss,
    );
    final tease = MemeEngine.getInlineTease(
      summary?.totalProfitLossPercent ?? 0,
      seed: 'top_lo_header',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actualLosers.isEmpty
                          ? 'Không có ai trong CLB Lỗ'
                          : 'Bảng phong thần: ${actualLosers.length} mục đang lỗ',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (actualLosers.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        privacyMode
                            ? 'Tổng lỗ: ••••••'
                            : 'Tổng lỗ: ${Formatters.formatVnd(totalLoss)}',
                        style: const TextStyle(
                          color: AppColors.loss,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TeaseLine(
            content: tease.content,
            emoji: tease.emoji,
            severityLevel: tease.severityLevel,
          ),
        ],
      ),
    );
  }

  Widget _buildLoserRow(
    BuildContext context,
    int rank,
    ProfitLossResult result,
    AppStore store,
    bool privacyMode,
  ) {
    final holding = result.holding;
    final goldType = store.getGoldType(holding.goldTypeId);
    final displayName = goldType?.displayName ?? holding.goldTypeId;
    final isProfit = result.isProfit;
    final color = isProfit ? AppColors.profit : AppColors.loss;
    final tease = MemeEngine.getInlineTease(
      result.profitLossPercent,
      seed: holding.id,
    );

    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HoldingDetailScreen(holdingId: holding.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _rankBadge(rank, isProfit),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.formatQuantity(holding.quantity, holding.unit)} · mua ${Formatters.formatDate(holding.buyDate)}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
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
                  const SizedBox(height: 2),
                  Text(
                    privacyMode ? '••••••' : Formatters.formatVnd(result.profitLoss),
                    style: TextStyle(
                      color: privacyMode ? AppColors.textHint : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TeaseLine(
            content: tease.content,
            emoji: tease.emoji,
            severityLevel: tease.severityLevel,
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(int rank, bool isProfit) {
    String label;
    Color bg;
    Color fg;
    switch (rank) {
      case 1:
        label = isProfit ? '🎉' : '👑';
        bg = AppColors.loss.withValues(alpha: 0.2);
        fg = AppColors.loss;
        break;
      case 2:
        label = '🥈';
        bg = AppColors.warning.withValues(alpha: 0.18);
        fg = AppColors.warning;
        break;
      case 3:
        label = '🥉';
        bg = AppColors.warning.withValues(alpha: 0.14);
        fg = AppColors.warning;
        break;
      default:
        label = '#$rank';
        bg = AppColors.bgCardHighlight;
        fg = AppColors.textSecondary;
    }
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: rank <= 3 ? 22 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAllProfitBanner() {
    final tease = MemeEngine.getInlineTease(15, seed: 'all_profit_banner');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: AppCard(
        margin: EdgeInsets.zero,
        color: AppColors.profitBg,
        child: Column(
          children: [
            const Text('🎊', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text(
              'Cả danh mục đều đang lãi',
              style: TextStyle(
                color: AppColors.profit,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Không có ai để top. Nhưng...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TeaseLine(
              content: tease.content,
              emoji: tease.emoji,
              severityLevel: tease.severityLevel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      emoji: '🫥',
      title: 'Chưa có gì để lỗ',
      subtitle: 'Muốn có tên trong Top Lỗ thì phải có vàng đã. Thêm mua vào ở tab Danh mục.',
    );
  }
}
