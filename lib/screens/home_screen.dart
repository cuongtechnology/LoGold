import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../services/profit_loss_calculator.dart';
import '../services/meme_engine.dart';
import '../models/meme_template.dart'; // EmotionalStatusX (label/emoji) dùng ở _buildStatusSection
import '../components/ui_components.dart';
import '../components/banner_ad_widget.dart';
import 'add_purchase_screen.dart';
import 'holding_detail_screen.dart';
import 'utilities_screen.dart';
import 'charts_screen.dart';
import 'historical_comparison_screen.dart';

/// Home Dashboard - main screen with portfolio overview, P/L, and meme status.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  /// Gọi để chuyển tab của `MainShell` (vd: bấm "Xem tất cả" → tab Danh mục).
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final summary = store.portfolioSummary;
    final privacyMode = store.privacyMode;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => store.refreshPrices(),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(store),
              ),
              // Content
              if (store.isLoading && summary == null)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                )
              else if (summary == null || summary.holdingCount == 0)
                SliverFillRemaining(
                  child: _buildEmptyState(store),
                )
              else ...[
                SliverToBoxAdapter(child: _buildPortfolioCard(summary, privacyMode)),
                SliverToBoxAdapter(child: _buildStatusSection(summary)),
                SliverToBoxAdapter(child: _buildMemeSection(summary)),
                // Xen giữa 2 section thuần hiển thị (không nút bấm) để tránh
                // click nhầm — theo chính sách khoảng cách ad của AdMob/Play.
                const SliverToBoxAdapter(child: BannerAdWidget()),
                SliverToBoxAdapter(child: _buildHoldingsPreview(store, summary)),
                SliverToBoxAdapter(child: _buildQuickActions(store)),
                const SliverToBoxAdapter(child: BannerAdWidget()),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPurchase(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(AppStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      store.priceStatusMessage,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    AppConstants.slogan,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getGreeting(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Privacy toggle
          IconButton(
            onPressed: store.togglePrivacyMode,
            icon: Icon(
              store.privacyMode ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textSecondary,
            ),
          ),
          // Refresh
          IconButton(
            onPressed: () => store.refreshPrices(),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng! Vàng hôm nay thế nào?';
    if (hour < 18) return 'Chào buổi chiều! Vàng có lên không?';
    return 'Chào buổi tối! Lỗ nhiều chưa?';
  }

  Widget _buildPortfolioCard(PortfolioSummary summary, bool privacyMode) {
    final isProfit = summary.isProfit;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total portfolio value
          const Text(
            'Tổng giá trị hiện tại',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          AnimatedNumber(
            value: summary.totalCurrentValue,
            format: 'vnd',
            style: TextStyle(
              color: privacyMode ? AppColors.textHint : AppColors.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 24),

          // P/L section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isProfit ? AppColors.profitBg : AppColors.lossBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lãi / Lỗ',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      PLDisplay(
                        amount: summary.totalProfitLoss,
                        isProfit: isProfit,
                        privacyMode: privacyMode,
                        fontSize: 24,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '% Lãi / Lỗ',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      PLDisplay(
                        amount: summary.totalProfitLossPercent,
                        isProfit: isProfit,
                        isPercentage: true,
                        privacyMode: privacyMode,
                        fontSize: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details row
          Row(
            children: [
              _detailItem(
                'Tổng vốn',
                privacyMode ? '••••••' : _formatVnd(summary.totalCost),
              ),
              _detailItem(
                'Tổng vàng',
                privacyMode ? '••••' : '${summary.totalQuantityInLuong.toStringAsFixed(2)} lượng',
              ),
              _detailItem(
                'Giá hòa vốn',
                privacyMode ? '••••' : _formatVndCompact(summary.breakEvenPricePerLuong),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textHint, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(PortfolioSummary summary) {
    final status = summary.emotionalStatus;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: summary.isProfit ? AppColors.profitBg : AppColors.lossBg,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(status.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trạng thái cảm xúc',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  status.label,
                  style: TextStyle(
                    color: summary.isProfit ? AppColors.profit : AppColors.loss,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemeSection(PortfolioSummary summary) {
    // Tính trực tiếp từ P/L% thật mỗi lần rebuild — luôn khớp tình huống
    // hiện tại, không cho đổi/random tay (MemeEngine.getMeme deterministic
    // theo ngày, không phải getRandomMeme).
    final meme = MemeEngine.getMeme(summary.totalProfitLossPercent);
    return MemeCard(
      title: meme.title,
      content: meme.content,
      emoji: meme.emoji,
      severityLevel: meme.severityLevel,
    );
  }

  Widget _buildHoldingsPreview(AppStore store, PortfolioSummary summary) {
    final holdings = store.activeHoldings.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Vàng của bạn',
          actionText: 'Xem tất cả',
          onAction: _navigateToPortfolioTab,
        ),
        ...holdings.map((h) {
          final result = store.getHoldingResult(h.id);
          final goldType = store.getGoldType(h.goldTypeId);
          return _buildHoldingTile(
            goldType?.displayName ?? h.goldTypeId,
            h.quantity,
            h.unit,
            result,
            store.privacyMode,
            () => _navigateToHoldingDetail(context, h.id),
          );
        }),
      ],
    );
  }

  Widget _buildHoldingTile(
    String name,
    double qty,
    String unit,
    ProfitLossResult? result,
    bool privacyMode,
    VoidCallback onTap,
  ) {
    final isProfit = result?.isProfit ?? false;
    final color = isProfit ? AppColors.profit : AppColors.loss;

    return AppCard(
      onTap: onTap,
      child: Row(
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
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${qty.toStringAsFixed(2)} ${unit == 'luong'
                      ? 'lượng'
                      : unit == 'chi'
                      ? 'chỉ'
                      : unit == 'phan'
                      ? 'phân'
                      : 'gram'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (result != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  privacyMode ? '••••' : _formatVnd(result.profitLoss),
                  style: TextStyle(
                    color: privacyMode ? AppColors.textHint : color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  privacyMode ? '••' : '${result.profitLossPercent >= 0 ? '+' : ''}${result.profitLossPercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: privacyMode ? AppColors.textHint : color,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else
            const Text(
              '...',
              style: TextStyle(color: AppColors.textHint),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(AppStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tiện ích nhanh'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _quickAction('🧮', 'Đổi đơn vị', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UtilitiesScreen(),
                  ),
                );
              }),
              _quickAction('💰', 'Mua/Bán nhanh', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UtilitiesScreen(),
                  ),
                );
              }),
              _quickAction('⚖️', 'Giá hòa vốn', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UtilitiesScreen(),
                  ),
                );
              }),
              _quickAction('📈', 'Biểu đồ', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChartsScreen(),
                  ),
                );
              }),
              _quickAction('📜', 'So sánh lịch sử', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistoricalComparisonScreen(),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickAction(String emoji, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppStore store) {
    return EmptyState(
      emoji: '🪙',
      title: 'Chưa có vàng nào',
      subtitle: 'Thêm lần mua vàng đầu tiên để bắt đầu theo dõi lãi/lỗ',
      actionText: 'Thêm vàng ngay',
      onAction: () => _navigateToAddPurchase(context),
    );
  }

  void _navigateToAddPurchase(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPurchaseScreen()),
    );
  }

  void _navigateToHoldingDetail(BuildContext context, String holdingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HoldingDetailScreen(holdingId: holdingId),
      ),
    );
  }

  void _navigateToPortfolioTab() {
    widget.onNavigateToTab?.call(1);
  }

  String _formatVnd(double value) {
    final abs = value.abs().round();
    final str = abs.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return value < 0 ? '-$str₫' : '$str₫';
  }

  String _formatVndCompact(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)} tỷ';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)}tr';
    }
    return '${value.round()}đ';
  }
}

