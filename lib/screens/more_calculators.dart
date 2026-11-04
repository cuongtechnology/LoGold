import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/ui_components.dart';
import '../constants/app_constants.dart';
import '../models/gold_price.dart';
import '../stores/app_store.dart';
import '../utils/formatters.dart';
import '../utils/gold_units.dart';

/// Extra calculators shown as tabs in [UtilitiesScreen]:
/// target sell price, average cost, budget, gold vs savings, buy/sell spread.

// =================== Shared building blocks ===================

class _CalcPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? formula;

  const _CalcPage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.formula,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ...children,
          if (formula != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
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
                    formula!,
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
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? hint;

  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 16),
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
}

class _ChoiceRow<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = v == selected;
        return ChoiceChip(
          label: Text(label(v)),
          selected: isSelected,
          onSelected: (_) => onSelected(v),
          selectedColor: AppColors.gold.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 12,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.gold : AppColors.divider,
          ),
        );
      }).toList(),
    );
  }
}

class _UnitChips extends StatelessWidget {
  final String unit;
  final ValueChanged<String> onChanged;

  const _UnitChips({required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) => _ChoiceRow<String>(
        values: GoldUnits.units,
        selected: unit,
        label: GoldUnits.label,
        onSelected: onChanged,
      );
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultRow(this.label, this.value, {this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color color;

  const _Highlight({
    required this.label,
    required this.value,
    this.caption,
    this.color = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFF2A2520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String emoji;
  final String text;

  const _Placeholder(this.emoji, this.text);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fills [controller] with a VND amount, formatted the way users type it.
void _setMoney(TextEditingController controller, double value) {
  controller.text = Formatters.formatVnd(value, withSymbol: false);
}

/// Quantity as users type it: up to 3 decimals, no trailing zeros.
String _qtyText(double value) {
  var text = value.toStringAsFixed(3);
  text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return text;
}

GoldPrice? _priceFor(AppStore store, String goldTypeId) {
  for (final p in store.prices) {
    if (p.goldTypeId == goldTypeId) return p;
  }
  return null;
}

/// Gold type whose price pre-fills the calculators: SJC when available,
/// otherwise the first type with a price.
String? _defaultGoldTypeId(AppStore store) {
  final ids = store.prices.map((p) => p.goldTypeId).toList();
  if (ids.isEmpty) return null;
  return ids.contains('sjc') ? 'sjc' : ids.first;
}

String _goldTypeName(AppStore store, String id) =>
    store.getGoldType(id)?.displayName ?? id;

// =================== Target sell price ===================

/// How high the buy-in price must go to reach a desired profit.
class TargetProfitTab extends StatefulWidget {
  const TargetProfitTab({super.key});

  @override
  State<TargetProfitTab> createState() => _TargetProfitTabState();
}

class _TargetProfitTabState extends State<TargetProfitTab> {
  final _costCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _percentCtrl = TextEditingController(text: '10');
  final _currentCtrl = TextEditingController();
  String _unit = 'chi';

  @override
  void dispose() {
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    _percentCtrl.dispose();
    _currentCtrl.dispose();
    super.dispose();
  }

  double get _cost => Formatters.parseMoney(_costCtrl.text) ?? 0;
  double get _qtyLuong =>
      GoldUnits.toLuong(Formatters.parseQuantity(_qtyCtrl.text) ?? 0, _unit);
  double get _percent => Formatters.parseQuantity(_percentCtrl.text) ?? 0;
  double get _currentPerLuong =>
      GoldUnits.pricePerLuong(Formatters.parseMoney(_currentCtrl.text) ?? 0, _unit);

  void _fillFromPortfolio(AppStore store) {
    final summary = store.portfolioSummary;
    if (summary == null || summary.totalQuantityInLuong <= 0) return;
    setState(() {
      _setMoney(_costCtrl, summary.totalCost);
      _qtyCtrl.text = _qtyText(GoldUnits.fromLuong(summary.totalQuantityInLuong, _unit));
      final typeId = _defaultGoldTypeId(store);
      final price = typeId == null ? null : store.getBuyPrice(typeId);
      if (price != null) {
        _setMoney(_currentCtrl, GoldUnits.priceFromLuong(price, _unit));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final ready = _cost > 0 && _qtyLuong > 0;
    final targetValue = _cost * (1 + _percent / 100);
    final targetPerLuong = ready ? targetValue / _qtyLuong : 0.0;
    final gapPercent = _currentPerLuong > 0
        ? (targetPerLuong - _currentPerLuong) / _currentPerLuong * 100
        : null;

    return _CalcPage(
      title: 'Giá chốt lời',
      subtitle: 'Giá mua vào phải lên bao nhiêu để lãi đúng mục tiêu',
      formula: 'Giá chốt lời = Tổng vốn × (1 + % lãi) ÷ Số lượng (lượng)\n'
          'Tiền lãi = Tổng vốn × % lãi',
      children: [
        if (store.activeHoldings.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _fillFromPortfolio(store),
              icon: const Icon(Icons.download, size: 18, color: AppColors.gold),
              label: const Text(
                'Lấy từ danh mục',
                style: TextStyle(color: AppColors.gold),
              ),
            ),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NumberField(
                label: 'Tổng vốn đã bỏ ra (VNĐ)',
                controller: _costCtrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _NumberField(
                label: 'Số lượng vàng',
                controller: _qtyCtrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 8),
              _UnitChips(unit: _unit, onChanged: (u) => setState(() => _unit = u)),
              const SizedBox(height: 12),
              _NumberField(
                label: 'Lãi mong muốn (%)',
                controller: _percentCtrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _NumberField(
                label: 'Giá mua vào hiện tại / ${GoldUnits.shortLabel(_unit)} (tùy chọn)',
                controller: _currentCtrl,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!ready)
          const _Placeholder('🎯', 'Nhập tổng vốn và số lượng để tính giá chốt lời')
        else ...[
          _Highlight(
            label: 'Giá mua vào cần đạt',
            value: '${Formatters.formatVnd(targetPerLuong)}/lượng',
            caption:
                '≈ ${Formatters.formatVnd(GoldUnits.priceFromLuong(targetPerLuong, _unit))}/${GoldUnits.shortLabel(_unit)}',
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _ResultRow('Tiền thu về khi bán', Formatters.formatVnd(targetValue)),
                _ResultRow(
                  'Tiền lãi',
                  Formatters.formatVnd(targetValue - _cost),
                  color: AppColors.profit,
                ),
                if (gapPercent != null)
                  _ResultRow(
                    gapPercent > 0 ? 'Giá cần tăng thêm' : 'Đã vượt mục tiêu',
                    Formatters.formatPercent(gapPercent),
                    color: gapPercent > 0 ? AppColors.warning : AppColors.profit,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =================== Average cost ===================

class _Lot {
  final qty = TextEditingController();
  final price = TextEditingController();

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

/// Weighted average buy price across several purchases.
class AverageCostTab extends StatefulWidget {
  const AverageCostTab({super.key});

  @override
  State<AverageCostTab> createState() => _AverageCostTabState();
}

class _AverageCostTabState extends State<AverageCostTab> {
  final List<_Lot> _lots = [_Lot(), _Lot()];
  String _unit = 'chi';

  @override
  void dispose() {
    for (final lot in _lots) {
      lot.dispose();
    }
    super.dispose();
  }

  void _fillFromPortfolio(AppStore store) {
    final holdings = store.activeHoldings;
    if (holdings.isEmpty) return;
    setState(() {
      _disposeLater(List.of(_lots));
      _lots
        ..clear()
        ..addAll(holdings.map((h) {
          final lot = _Lot();
          lot.qty.text = _qtyText(GoldUnits.fromLuong(h.quantityInLuong, _unit));
          _setMoney(lot.price, GoldUnits.priceFromLuong(h.buyPricePerLuong, _unit));
          return lot;
        }));
    });
  }

  /// Controllers are still attached to TextFields during this frame, so they
  /// are disposed only after the rebuild that removes those fields.
  void _disposeLater(List<_Lot> lots) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final lot in lots) {
        lot.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    double totalQty = 0;
    double totalCost = 0;
    for (final lot in _lots) {
      final q = Formatters.parseQuantity(lot.qty.text) ?? 0;
      final p = Formatters.parseMoney(lot.price.text) ?? 0;
      if (q > 0 && p > 0) {
        totalQty += q;
        totalCost += q * p;
      }
    }
    final avgPerUnit = totalQty > 0 ? totalCost / totalQty : 0.0;

    return _CalcPage(
      title: 'Giá mua bình quân',
      subtitle: 'Gộp nhiều lần mua để biết giá vốn trung bình',
      formula: 'Giá bình quân = Σ(Số lượng × Giá) ÷ Σ Số lượng',
      children: [
        if (store.activeHoldings.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _fillFromPortfolio(store),
              icon: const Icon(Icons.download, size: 18, color: AppColors.gold),
              label: const Text(
                'Lấy từ danh mục',
                style: TextStyle(color: AppColors.gold),
              ),
            ),
          ),
        _UnitChips(
          unit: _unit,
          onChanged: (u) => setState(() => _unit = u),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _lots.length; i++) ...[
          AppCard(
            key: ObjectKey(_lots[i]),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: _NumberField(
                    label: 'Lần ${i + 1}: số ${GoldUnits.shortLabel(_unit)}',
                    controller: _lots[i].qty,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _NumberField(
                    label: 'Giá / ${GoldUnits.shortLabel(_unit)}',
                    controller: _lots[i].price,
                    onChanged: () => setState(() {}),
                  ),
                ),
                if (_lots.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textHint),
                    onPressed: () => setState(() => _disposeLater([_lots.removeAt(i)])),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: () => setState(() => _lots.add(_Lot())),
          icon: const Icon(Icons.add, color: AppColors.gold),
          label: const Text('Thêm lần mua', style: TextStyle(color: AppColors.gold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.gold),
          ),
        ),
        const SizedBox(height: 16),
        if (totalQty <= 0)
          const _Placeholder('📊', 'Nhập số lượng và giá của từng lần mua')
        else ...[
          _Highlight(
            label: 'Giá bình quân',
            value: '${Formatters.formatVnd(avgPerUnit)}/${GoldUnits.shortLabel(_unit)}',
            caption:
                '≈ ${Formatters.formatVnd(GoldUnits.pricePerLuong(avgPerUnit, _unit))}/lượng',
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _ResultRow('Tổng số lượng', Formatters.formatQuantity(totalQty, _unit)),
                _ResultRow('Tổng tiền mua', Formatters.formatVnd(totalCost)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =================== Budget ===================

/// How much gold a given amount of money buys at the shop's sell price.
class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  final _budgetCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _goldTypeId;

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _selectType(AppStore store, String id) {
    setState(() {
      _goldTypeId = id;
      final price = _priceFor(store, id);
      if (price != null) {
        _setMoney(_priceCtrl, GoldUnits.priceFromLuong(price.sellPrice, 'chi'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final typeIds = store.prices.map((p) => p.goldTypeId).toList();
    if (_goldTypeId == null && typeIds.isNotEmpty) {
      final initial = _defaultGoldTypeId(store)!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _goldTypeId == null) _selectType(store, initial);
      });
    }

    final budget = Formatters.parseMoney(_budgetCtrl.text) ?? 0;
    final pricePerChi = Formatters.parseMoney(_priceCtrl.text) ?? 0;
    final ready = budget > 0 && pricePerChi > 0;
    final chi = ready ? budget / pricePerChi : 0.0;
    final wholeChi = chi.floor();
    final leftover = budget - wholeChi * pricePerChi;

    return _CalcPage(
      title: 'Mua được bao nhiêu?',
      subtitle: 'Có bao nhiêu tiền thì mua được bao nhiêu vàng (theo giá tiệm bán ra)',
      formula: 'Số chỉ = Số tiền ÷ Giá bán ra mỗi chỉ\n'
          'Tiền thừa = Số tiền - Số chỉ tròn × Giá mỗi chỉ',
      children: [
        if (typeIds.isNotEmpty) ...[
          _ChoiceRow<String>(
            values: typeIds,
            selected: _goldTypeId ?? typeIds.first,
            label: (id) => _goldTypeName(store, id),
            onSelected: (id) => _selectType(store, id),
          ),
          const SizedBox(height: 12),
        ],
        AppCard(
          child: Column(
            children: [
              _NumberField(
                label: 'Số tiền đang có (VNĐ)',
                controller: _budgetCtrl,
                hint: 'VD: 50.000.000',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _NumberField(
                label: 'Giá tiệm bán ra / chỉ',
                controller: _priceCtrl,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!ready)
          const _Placeholder('🛒', 'Nhập số tiền để xem mua được bao nhiêu vàng')
        else ...[
          _Highlight(
            label: 'Mua được',
            value: Formatters.formatQuantity(chi, 'chi'),
            caption:
                '= ${Formatters.formatQuantity(GoldUnits.convert(chi, 'chi', 'gram'), 'gram')}'
                ' = ${GoldUnits.toLuong(chi, 'chi').toStringAsFixed(3)} lượng',
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _ResultRow('Nếu mua tròn chỉ', '$wholeChi chỉ'),
                _ResultRow('Tiền thừa', Formatters.formatVnd(leftover)),
                if (wholeChi == 0)
                  _ResultRow(
                    'Còn thiếu cho 1 chỉ',
                    Formatters.formatVnd(pricePerChi - budget),
                    color: AppColors.warning,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =================== Gold vs savings ===================

/// Compares holding gold with a bank term deposit over the same period.
class SavingsCompareTab extends StatefulWidget {
  const SavingsCompareTab({super.key});

  @override
  State<SavingsCompareTab> createState() => _SavingsCompareTabState();
}

class _SavingsCompareTabState extends State<SavingsCompareTab> {
  final _costCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController(text: '12');
  final _rateCtrl = TextEditingController(text: '5');

  @override
  void dispose() {
    _costCtrl.dispose();
    _valueCtrl.dispose();
    _monthsCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _fillFromPortfolio(AppStore store) {
    final summary = store.portfolioSummary;
    final holdings = store.activeHoldings;
    if (summary == null || holdings.isEmpty) return;
    final firstBuy =
        holdings.map((h) => h.buyDate).reduce((a, b) => a.isBefore(b) ? a : b);
    final months = math.max(1, (DateTime.now().difference(firstBuy).inDays / 30.4).round());
    setState(() {
      _setMoney(_costCtrl, summary.totalCost);
      _setMoney(_valueCtrl, summary.totalCurrentValue);
      _monthsCtrl.text = '$months';
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cost = Formatters.parseMoney(_costCtrl.text) ?? 0;
    final goldValue = Formatters.parseMoney(_valueCtrl.text) ?? 0;
    final months = Formatters.parseQuantity(_monthsCtrl.text) ?? 0;
    final rate = Formatters.parseQuantity(_rateCtrl.text) ?? 0;
    final ready = cost > 0 && goldValue > 0 && months > 0;

    final savingsInterest = cost * rate / 100 * months / 12;
    final savingsValue = cost + savingsInterest;
    final goldProfit = goldValue - cost;
    final diff = goldValue - savingsValue;
    final goldWins = diff >= 0;

    return _CalcPage(
      title: 'Vàng hay gửi tiết kiệm?',
      subtitle: 'Nếu hồi đó đem tiền gửi ngân hàng thì giờ được bao nhiêu',
      formula: 'Lãi tiết kiệm = Vốn × Lãi suất/năm × Số tháng ÷ 12 (lãi đơn)\n'
          'Chênh lệch = Giá trị vàng hiện tại - (Vốn + Lãi tiết kiệm)',
      children: [
        if (store.activeHoldings.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _fillFromPortfolio(store),
              icon: const Icon(Icons.download, size: 18, color: AppColors.gold),
              label: const Text(
                'Lấy từ danh mục',
                style: TextStyle(color: AppColors.gold),
              ),
            ),
          ),
        AppCard(
          child: Column(
            children: [
              _NumberField(
                label: 'Tổng vốn mua vàng (VNĐ)',
                controller: _costCtrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _NumberField(
                label: 'Giá trị vàng nếu bán hôm nay (VNĐ)',
                controller: _valueCtrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      label: 'Số tháng',
                      controller: _monthsCtrl,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberField(
                      label: 'Lãi suất (%/năm)',
                      controller: _rateCtrl,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!ready)
          const _Placeholder('🏦', 'Nhập vốn, giá trị vàng hiện tại và số tháng')
        else ...[
          _Highlight(
            label: goldWins ? 'Vàng thắng ngân hàng 🎉' : 'Ngân hàng thắng vàng 🥲',
            value: '${diff >= 0 ? '+' : ''}${Formatters.formatVnd(diff)}',
            color: goldWins ? AppColors.profit : AppColors.loss,
            caption: goldWins
                ? 'Giữ vàng lời hơn gửi tiết kiệm'
                : 'Biết thế gửi ngân hàng cho lành',
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _ResultRow(
                  'Lãi/lỗ từ vàng',
                  Formatters.formatVnd(goldProfit),
                  color: goldProfit >= 0 ? AppColors.profit : AppColors.loss,
                ),
                _ResultRow('Lãi nếu gửi tiết kiệm', Formatters.formatVnd(savingsInterest)),
                _ResultRow('Tiền gửi + lãi', Formatters.formatVnd(savingsValue)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =================== Buy/sell spread ===================

/// Shows how much is lost instantly to the shop's buy/sell spread.
class SpreadTab extends StatefulWidget {
  const SpreadTab({super.key});

  @override
  State<SpreadTab> createState() => _SpreadTabState();
}

class _SpreadTabState extends State<SpreadTab> {
  final _qtyCtrl = TextEditingController(text: '1');
  String _unit = 'chi';

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final prices = store.prices;
    final qtyLuong =
        GoldUnits.toLuong(Formatters.parseQuantity(_qtyCtrl.text) ?? 0, _unit);

    return _CalcPage(
      title: 'Chênh lệch mua - bán',
      subtitle: 'Vừa mua xong bán ngay thì mất bao nhiêu',
      formula: 'Chênh lệch = Giá bán ra - Giá mua vào\n'
          'Giá cần tăng để hòa = Chênh lệch ÷ Giá mua vào',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NumberField(
                label: 'Số lượng',
                controller: _qtyCtrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 8),
              _UnitChips(unit: _unit, onChanged: (u) => setState(() => _unit = u)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (prices.isEmpty)
          const _Placeholder('↔️', 'Chưa có dữ liệu giá. Kéo xuống ở trang chủ để cập nhật.')
        else
          for (final p in prices) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _goldTypeName(store, p.goldTypeId),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ResultRow(
                    'Chênh lệch / lượng',
                    '${Formatters.formatVnd(p.spread)} '
                        '(${(p.buyPrice > 0 ? p.spread / p.buyPrice * 100 : 0).toStringAsFixed(2)}%)',
                    color: AppColors.warning,
                  ),
                  if (qtyLuong > 0)
                    _ResultRow(
                      'Mất ngay khi mua ${Formatters.formatQuantity(GoldUnits.fromLuong(qtyLuong, _unit), _unit)}',
                      Formatters.formatVnd(-p.spread * qtyLuong),
                      color: AppColors.loss,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
