import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';
import '../utils/gold_units.dart';
import '../utils/formatters.dart';
import 'more_calculators.dart';

/// Utilities screen - unit converter, buy/sell calculator, breakeven calculator.
class UtilitiesScreen extends StatefulWidget {
  /// Tab to open first; use the [UtilityTab] constants.
  final int initialTab;

  const UtilitiesScreen({super.key, this.initialTab = UtilityTab.unitConverter});

  @override
  State<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends State<UtilitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiện ích'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textHint,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Đổi đơn vị'),
            Tab(text: 'Mua/Bán'),
            Tab(text: 'Hòa vốn'),
            Tab(text: 'Chốt lời'),
            Tab(text: 'Giá bình quân'),
            Tab(text: 'Mua được bao nhiêu'),
            Tab(text: 'Vàng vs Tiết kiệm'),
            Tab(text: 'Chênh lệch'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _UnitConverterTab(),
            const _BuySellCalculatorTab(),
            _BreakevenCalculatorTab(),
            const TargetProfitTab(),
            const AverageCostTab(),
            const BudgetTab(),
            const SavingsCompareTab(),
            const SpreadTab(),
          ],
        ),
      ),
    );
  }
}

/// Tab indexes of [UtilitiesScreen], for deep links from the home screen.
abstract final class UtilityTab {
  static const unitConverter = 0;
  static const buySell = 1;
  static const breakeven = 2;
  static const targetProfit = 3;
  static const averageCost = 4;
  static const budget = 5;
  static const savings = 6;
  static const spread = 7;
}

// =================== Tab 1: Unit Converter ===================

class _UnitConverterTab extends StatefulWidget {
  @override
  State<_UnitConverterTab> createState() => _UnitConverterTabState();
}

class _UnitConverterTabState extends State<_UnitConverterTab> {
  final _inputCtrl = TextEditingController(text: '1');
  String _fromUnit = 'luong';
  String _toUnit = 'gram';

  double _getConverted() {
    final input = Formatters.parseQuantity(_inputCtrl.text) ?? 0;
    return GoldUnits.convert(input, _fromUnit, _toUnit);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final converted = _getConverted();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chuyển đổi đơn vị vàng',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '1 lượng = 10 chỉ = 37.5 gram',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Input
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhập số lượng',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inputCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bgPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                    suffixText: GoldUnits.label(_fromUnit),
                    suffixStyle:
                        const TextStyle(color: AppColors.textHint, fontSize: 14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Từ đơn vị',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _buildUnitSelector(true),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // Swap icon
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _swapUnits,
                icon: const Icon(Icons.swap_vert, color: AppColors.gold),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Output
          AppCard(
            color: const Color(0xFF2A2520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kết quả chuyển đổi',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '${converted.toStringAsFixed(4)} ${GoldUnits.shortLabel(_toUnit)}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sang đơn vị',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _buildUnitSelector(false),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Full conversion table
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bảng quy đổi đầy đủ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildConversionTable(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector(bool isFrom) {
    final selected = isFrom ? _fromUnit : _toUnit;
    return Row(
      children: GoldUnits.units.map((unit) {
        final isSelected = unit == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isFrom) {
                    _fromUnit = unit;
                  } else {
                    _toUnit = unit;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.gold : AppColors.divider,
                  ),
                ),
                child: Center(
                  child: Text(
                    GoldUnits.label(unit),
                    style: TextStyle(
                      color: isSelected ? AppColors.gold : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _swapUnits() {
    setState(() {
      final temp = _fromUnit;
      _fromUnit = _toUnit;
      _toUnit = temp;
    });
  }

  List<Widget> _buildConversionTable() {
    final input = Formatters.parseQuantity(_inputCtrl.text) ?? 0;
    final results = <Widget>[];

    for (final unit in GoldUnits.units) {
      final value = GoldUnits.convert(input, _fromUnit, unit);
      results.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                GoldUnits.label(unit),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              Text(
                value.toStringAsFixed(4),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return results;
  }
}

// =================== Tab 2: Buy/Sell Calculator ===================

class _BuySellCalculatorTab extends StatefulWidget {
  const _BuySellCalculatorTab();

  @override
  State<_BuySellCalculatorTab> createState() => _BuySellCalculatorTabState();
}

class _BuySellCalculatorTabState extends State<_BuySellCalculatorTab> {
  final _priceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '0');
  String _unit = 'luong';
  String _selectedGoldTypeId = 'sjc';
  bool _isBuying = true;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  double get _pricePerUnit => Formatters.parseMoney(_priceCtrl.text) ?? 0;
  double get _quantity => Formatters.parseQuantity(_quantityCtrl.text) ?? 0;
  double get _fee => Formatters.parseMoney(_feeCtrl.text) ?? 0;

  double get _quantityInLuong => GoldUnits.toLuong(_quantity, _unit);
  double get _pricePerLuong => GoldUnits.pricePerLuong(_pricePerUnit, _unit);
  double get _totalCost => _pricePerLuong * _quantityInLuong + _fee;
  double get _totalReceive => _pricePerLuong * _quantityInLuong - _fee;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Máy tính mua/bán vàng',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tính tổng tiền khi mua hoặc bán vàng',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Buy/Sell toggle
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isBuying = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isBuying
                            ? AppColors.gold.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isBuying ? AppColors.gold : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '🛒 Mua vàng',
                          style: TextStyle(
                            color: _isBuying ? AppColors.gold : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isBuying = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isBuying
                            ? AppColors.gold.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_isBuying ? AppColors.gold : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '💰 Bán vàng',
                          style: TextStyle(
                            color: !_isBuying ? AppColors.gold : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Gold type selector
          if (store.goldTypes.isNotEmpty) ...[
            const Text(
              'Loại vàng',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: store.goldTypes.map((gt) {
                  final selected = gt.id == _selectedGoldTypeId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(gt.displayName),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedGoldTypeId = gt.id;
                          _unit = gt.defaultUnit;
                        });
                      },
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
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Inputs
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(
                  'Giá ${_isBuying ? "mua" : "bán"} (per ${GoldUnits.label(_unit)})',
                  _priceCtrl,
                  suffix: 'đ',
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  'Số lượng',
                  _quantityCtrl,
                  suffix: GoldUnits.label(_unit),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                _buildUnitChips(),
                const SizedBox(height: 12),
                _buildInputField(
                  _isBuying ? 'Phí mua (tùy chọn)' : 'Phí bán/làm công (tùy chọn)',
                  _feeCtrl,
                  suffix: 'đ',
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Results
          AppCard(
            color: _isBuying ? const Color(0xFF1E2520) : const Color(0xFF25201E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isBuying ? 'Tổng chi phí mua' : 'Tổng tiền nhận được',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.formatVnd(_isBuying ? _totalCost : _totalReceive),
                  style: TextStyle(
                    color: _isBuying ? AppColors.loss : AppColors.profit,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _resultRow(
                  'Tương đương',
                  '${_quantityInLuong.toStringAsFixed(4)} lượng',
                ),
                const SizedBox(height: 6),
                _resultRow(
                  'Giá quy đổi/lượng',
                  Formatters.formatVnd(_pricePerLuong),
                ),
                if (_fee > 0) ...[
                  const SizedBox(height: 6),
                  _resultRow(
                    'Phí',
                    Formatters.formatVnd(_fee),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          // Hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isBuying
                        ? 'Tổng chi phí = Giá mua × Số lượng (quy đổi lượng) + Phí. '
                          'Đây là số tiền bạn cần bỏ ra để mua vàng.'
                        : 'Tổng tiền nhận = Giá bán × Số lượng (quy đổi lượng) - Phí. '
                          'Đây là số tiền tiệm sẽ trả cho bạn khi bán vàng.',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitChips() {
    return Row(
      children: GoldUnits.units.map((unit) {
        final selected = unit == _unit;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(GoldUnits.label(unit)),
            selected: selected,
            onSelected: (_) => setState(() => _unit = unit),
            selectedColor: AppColors.gold.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: selected ? AppColors.gold : AppColors.textSecondary,
              fontSize: 12,
            ),
            side: BorderSide(
              color: selected ? AppColors.gold : AppColors.divider,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController ctrl, {
    String suffix = '',
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bgPrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =================== Tab 3: Breakeven Calculator ===================

class _BreakevenCalculatorTab extends StatefulWidget {
  @override
  State<_BreakevenCalculatorTab> createState() => _BreakevenCalculatorTabState();
}

class _BreakevenCalculatorTabState extends State<_BreakevenCalculatorTab> {
  final _totalCostCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _currentPriceCtrl = TextEditingController();
  String _unit = 'luong';

  @override
  void dispose() {
    _totalCostCtrl.dispose();
    _quantityCtrl.dispose();
    _currentPriceCtrl.dispose();
    super.dispose();
  }

  double get _totalCost => Formatters.parseMoney(_totalCostCtrl.text) ?? 0;
  double get _quantity => Formatters.parseQuantity(_quantityCtrl.text) ?? 0;
  double get _currentPrice => Formatters.parseMoney(_currentPriceCtrl.text) ?? 0;

  double get _quantityInLuong => GoldUnits.toLuong(_quantity, _unit);
  double get _breakevenPricePerLuong =>
      _quantityInLuong > 0 ? _totalCost / _quantityInLuong : 0;
  double get _breakevenPricePerUnit =>
      GoldUnits.priceFromLuong(_breakevenPricePerLuong, _unit);
  double get _currentPricePerLuong =>
      GoldUnits.pricePerLuong(_currentPrice, _unit);
  double get _diffPerLuong => _breakevenPricePerLuong - _currentPricePerLuong;
  double get _diffPercent => _currentPricePerLuong > 0
      ? (_diffPerLuong / _currentPricePerLuong) * 100
      : 0;
  double get _currentValue => _quantityInLuong * _currentPricePerLuong;
  double get _profitLoss => _currentValue - _totalCost;
  bool get _isProfit => _profitLoss >= 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tính giá hòa vốn',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Giá vàng cần đạt để không lỗ không lãi',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Inputs
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(
                  'Tổng vốn đã bỏ ra (VNĐ)',
                  _totalCostCtrl,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  'Số lượng vàng',
                  _quantityCtrl,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 8),
                _buildUnitChips(),
                const SizedBox(height: 12),
                _buildInputField(
                  'Giá mua vào hiện tại (per ${GoldUnits.label(_unit)})',
                  _currentPriceCtrl,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_quantityInLuong > 0 && _totalCost > 0) ...[
            // Breakeven price card
            AppCard(
              color: const Color(0xFF2A2520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giá hòa vốn',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.formatVnd(_breakevenPricePerLuong),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '/ lượng (tương đương ${Formatters.formatVnd(_breakevenPricePerUnit)}/${GoldUnits.shortLabel(_unit)})',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Distance to breakeven
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khoảng cách đến hòa vốn',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _diffRow(
                    'Giá hiện tại',
                    Formatters.formatVnd(_currentPricePerLuong),
                    AppColors.textPrimary,
                  ),
                  const SizedBox(height: 8),
                  _diffRow(
                    'Giá hòa vốn',
                    Formatters.formatVnd(_breakevenPricePerLuong),
                    AppColors.gold,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isProfit
                          ? AppColors.profitBg
                          : AppColors.lossBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isProfit
                              ? 'Đang lãi rồi!'
                              : 'Cần giá tăng thêm',
                          style: TextStyle(
                            color: _isProfit ? AppColors.profit : AppColors.loss,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_diffPerLuong >= 0 ? '+' : ''}${Formatters.formatVndCompact(_diffPerLuong)}\n'
                          '(${Formatters.formatPercent(_diffPercent)})',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _isProfit ? AppColors.profit : AppColors.loss,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Current P/L preview
            AppCard(
              color: _isProfit ? const Color(0xFF1E2520) : const Color(0xFF251E1E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lãi/lỗ nếu bán ngay bây giờ',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        Formatters.formatVnd(_profitLoss),
                        style: TextStyle(
                          color: _isProfit ? AppColors.profit : AppColors.loss,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${Formatters.formatPercent(
                          _totalCost > 0 ? (_profitLoss / _totalCost) * 100 : 0,
                        )})',
                        style: TextStyle(
                          color: _isProfit ? AppColors.profit : AppColors.loss,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _diffRow(
                    'Giá trị hiện tại',
                    Formatters.formatVnd(_currentValue),
                    AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ] else
            AppCard(
              child: const Column(
                children: [
                  Text('⚖️', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    'Nhập tổng vốn và số lượng vàng để tính giá hòa vốn',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textHint, fontSize: 14),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          // Formula explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Công thức:',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Giá hòa vốn = Tổng vốn ÷ Số lượng vàng (lượng)\n'
                  'Khoảng cách = Giá hòa vốn - Giá hiện tại\n'
                  'Lãi/lỗ = (Giá hiện tại × Số lượng) - Tổng vốn',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitChips() {
    return Row(
      children: GoldUnits.units.map((unit) {
        final selected = unit == _unit;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(GoldUnits.label(unit)),
            selected: selected,
            onSelected: (_) => setState(() => _unit = unit),
            selectedColor: AppColors.gold.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: selected ? AppColors.gold : AppColors.textSecondary,
              fontSize: 12,
            ),
            side: BorderSide(
              color: selected ? AppColors.gold : AppColors.divider,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController ctrl, {
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bgPrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }

  Widget _diffRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
