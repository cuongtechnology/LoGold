import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/user_holding.dart';
import '../services/profit_loss_calculator.dart';
import '../stores/app_store.dart';
import '../utils/formatters.dart';
import '../utils/gold_units.dart';

/// Mở sheet ghi nhận bán vàng cho [holding]. Trả `true` nếu đã lưu.
/// Dùng cả khi đánh dấu đã bán lần đầu lẫn khi bổ sung giá bán cho mục cũ.
Future<bool> showSellHoldingSheet(
  BuildContext context,
  UserHolding holding,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SellHoldingSheet(holding: holding),
  );
  return saved ?? false;
}

class _SellHoldingSheet extends StatefulWidget {
  final UserHolding holding;

  const _SellHoldingSheet({required this.holding});

  @override
  State<_SellHoldingSheet> createState() => _SellHoldingSheetState();
}

class _SellHoldingSheetState extends State<_SellHoldingSheet> {
  final _priceController = TextEditingController();
  final _feeController = TextEditingController();
  late String _unit;
  late DateTime _sellDate;
  String? _error;

  // Giá/lượng gốc khi ô giá do app điền sẵn (chưa bị user sửa) — tránh sai số
  // làm tròn khi quy đổi qua lại giữa lượng/gram.
  double? _autoPerLuong;

  DateTime get _buyDay => DateUtils.dateOnly(widget.holding.buyDate);

  @override
  void initState() {
    super.initState();
    final h = widget.holding;
    _unit = h.unit;

    final today = DateUtils.dateOnly(DateTime.now());
    final existing = h.sellDate;
    _sellDate = existing != null
        ? DateUtils.dateOnly(existing)
        : (today.isBefore(_buyDay) ? _buyDay : today);

    // Ưu tiên giá bán đã ghi (khi sửa), không có thì lấy giá shop đang mua vào.
    final store = context.read<AppStore>();
    final pricePerLuong =
        h.sellPricePerLuong ?? store.getBuyPrice(h.goldTypeId);
    if (pricePerLuong != null) {
      _autoPerLuong = pricePerLuong;
      _priceController.text = _formatInput(
        GoldUnits.priceFromLuong(pricePerLuong, _unit),
      );
    }
    if ((h.sellFee ?? 0) > 0) {
      _feeController.text = _formatInput(h.sellFee!);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  String _formatInput(double value) =>
      Formatters.formatVnd(value.roundToDouble(), withSymbol: false);

  double? get _pricePerUnit => Formatters.parseMoney(_priceController.text);
  double get _fee => Formatters.parseMoney(_feeController.text) ?? 0;

  double? get _pricePerLuong {
    if (_autoPerLuong != null) return _autoPerLuong;
    final p = _pricePerUnit;
    if (p == null) return null;
    return GoldUnits.pricePerLuong(p, _unit);
  }

  /// Lãi/lỗ dự kiến theo giá đang nhập (để xem trước khi lưu).
  RealizedResult? get _preview {
    final p = _pricePerLuong;
    if (p == null || p <= 0) return null;
    return ProfitLossCalculator.calculateRealized(
      widget.holding.copyWith(
        status: 'sold',
        sellPricePerLuong: p,
        sellDate: _sellDate,
        sellFee: _fee,
      ),
    );
  }

  void _onUnitChanged(String unit) {
    // Quy đổi giá đang nhập sang đơn vị mới để giá/lượng không đổi.
    final perLuong = _pricePerLuong;
    setState(() {
      _unit = unit;
      if (perLuong != null) {
        if (_autoPerLuong != null) _autoPerLuong = perLuong;
        _priceController.text =
            _formatInput(GoldUnits.priceFromLuong(perLuong, unit));
      }
    });
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _sellDate,
      firstDate: _buyDay,
      lastDate: today.isBefore(_buyDay) ? _buyDay : today,
    );
    if (date != null) setState(() => _sellDate = date);
  }

  Future<void> _save() async {
    final price = _pricePerLuong;
    if (price == null || price <= 0) {
      setState(() => _error = 'Vui lòng nhập giá bán hợp lệ');
      return;
    }
    if (_feeController.text.trim().isNotEmpty &&
        Formatters.parseMoney(_feeController.text) == null) {
      setState(() => _error = 'Phí bán không hợp lệ');
      return;
    }
    if (_sellDate.isBefore(_buyDay)) {
      setState(() => _error = 'Ngày bán không được trước ngày mua');
      return;
    }

    final store = context.read<AppStore>();
    final navigator = Navigator.of(context);
    await store.markAsSold(
      widget.holding.id,
      sellPricePerLuong: price,
      sellDate: _sellDate,
      sellFee: _fee,
    );
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final holding = widget.holding;
    final privacyMode = context.watch<AppStore>().privacyMode;
    final preview = _preview;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ghi nhận bán vàng',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bán toàn bộ ${Formatters.formatQuantity(holding.quantity, holding.unit)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // Giá bán + đơn vị
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _field(
                    label: 'Giá bán / ${GoldUnits.shortLabel(_unit)} (VNĐ)',
                    controller: _priceController,
                    hint: 'VD: 116.000.000',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _unitSelector()),
              ],
            ),
            if (_pricePerLuong != null && _pricePerLuong! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '= ${Formatters.formatVnd(_pricePerLuong!)}/lượng',
                  style: const TextStyle(color: AppColors.gold, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),

            // Ngày bán
            const Text(
              'Ngày bán',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgCardHighlight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppColors.gold, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      Formatters.formatDate(_sellDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _field(
              label: 'Phí bán (VNĐ) - tùy chọn',
              controller: _feeController,
              hint: 'VD: 100.000',
            ),

            // Xem trước lãi/lỗ
            if (preview != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: preview.isProfit
                      ? AppColors.profitBg
                      : AppColors.lossBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  privacyMode
                      ? 'Lãi/lỗ thực hiện: ••••••'
                      : 'Lãi/lỗ thực hiện: ${Formatters.formatVnd(preview.profitLoss)} (${Formatters.formatPercent(preview.profitLossPercent)})',
                  style: TextStyle(
                    color:
                        preview.isProfit ? AppColors.profit : AppColors.loss,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.loss, fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgPrimary,
                    ),
                    child: const Text('Xác nhận bán'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {
            _error = null;
            // User tự gõ giá → bỏ giá điền sẵn, dùng đúng số đã nhập.
            if (identical(controller, _priceController)) _autoPerLuong = null;
          }),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.bgCardHighlight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _unitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đơn vị',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.bgCardHighlight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _unit,
            underline: const SizedBox(),
            isExpanded: true,
            dropdownColor: AppColors.bgCard,
            items: [
              for (final u in GoldUnits.units)
                DropdownMenuItem(value: u, child: Text(GoldUnits.label(u))),
            ],
            onChanged: (val) {
              if (val != null) _onUnitChanged(val);
            },
          ),
        ),
      ],
    );
  }
}
