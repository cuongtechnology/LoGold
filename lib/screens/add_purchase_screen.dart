import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';
import '../utils/gold_units.dart';
import '../utils/formatters.dart';

/// Add Purchase screen - form to add a new gold purchase entry.
/// Supports gold type selection, unit conversion, fee input, and notes.
class AddPurchaseScreen extends StatefulWidget {
  final String? initialGoldTypeId;

  const AddPurchaseScreen({super.key, this.initialGoldTypeId});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedGoldTypeId;
  final _quantityController = TextEditingController();
  // Không đặt mặc định (vd 'luong') — bắt user luôn phải bấm chọn tường
  // minh để tránh nhầm đơn vị (lượng/chỉ/phân/gram) dẫn tới tính sai lãi/lỗ.
  String? _selectedUnit;
  final _priceController = TextEditingController();
  final _feeController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _buyDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialGoldTypeId != null) {
      _selectedGoldTypeId = widget.initialGoldTypeId;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onGoldTypeSelected(String goldTypeId) {
    setState(() {
      _selectedGoldTypeId = goldTypeId;
    });
  }

  double? get _quantity => double.tryParse(_quantityController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
  double? get _pricePerUnit => double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
  double? get _fee => double.tryParse(_feeController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  double? get _quantityInLuong {
    final q = _quantity;
    final unit = _selectedUnit;
    if (q == null || unit == null) return null;
    return GoldUnits.toLuong(q, unit);
  }

  double? get _pricePerLuong {
    final p = _pricePerUnit;
    final unit = _selectedUnit;
    if (p == null || unit == null) return null;
    return GoldUnits.pricePerLuong(p, unit);
  }

  double? get _totalCost {
    final luong = _quantityInLuong;
    final pricePerLuong = _pricePerLuong;
    final fee = _fee ?? 0;
    if (luong == null || pricePerLuong == null) return null;
    return (pricePerLuong * luong) + fee;
  }

  void _saveHolding() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGoldTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn loại vàng'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn đơn vị (lượng/chỉ/phân/gram)'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }
    if (_quantity == null || _quantity! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số lượng hợp lệ'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }
    if (_pricePerUnit == null || _pricePerUnit! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập giá mua hợp lệ'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }

    final store = context.read<AppStore>();

    store.addHolding(
      goldTypeId: _selectedGoldTypeId!,
      quantity: _quantity!,
      unit: _selectedUnit!,
      buyPricePerUnit: _pricePerUnit!,
      fee: _fee ?? 0,
      buyDate: _buyDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã thêm vàng thành công! 🎉'),
        backgroundColor: AppColors.profit,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final goldTypes = store.goldTypes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm vàng'),
        actions: [
          TextButton(
            onPressed: _saveHolding,
            child: const Text(
              'Lưu',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gold type selection
                const Text(
                  'Loại vàng',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: goldTypes.map((gt) {
                    final selected = _selectedGoldTypeId == gt.id;
                    return ChoiceChip(
                      label: Text(gt.displayName),
                      selected: selected,
                      onSelected: (val) {
                        if (val) _onGoldTypeSelected(gt.id);
                      },
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.bgPrimary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Quantity + Unit
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildField(
                        label: 'Số lượng',
                        controller: _quantityController,
                        hint: 'VD: 1',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildUnitSelector(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Show converted quantity in luong
                if (_quantity != null && _quantity! > 0 && _quantityInLuong != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '= ${_quantityInLuong?.toStringAsFixed(4)} lượng (${(_quantityInLuong! * AppConstants.gramsPerLuong).toStringAsFixed(2)} gram)',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Price per unit
                _buildField(
                  label: _selectedUnit == null
                      ? 'Giá mua / đơn vị (VNĐ)'
                      : 'Giá mua / ${GoldUnits.shortLabel(_selectedUnit!)} (VNĐ)',
                  controller: _priceController,
                  hint: 'VD: ${_getDefaultPriceHint()}',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),

                // Show price per luong
                if (_pricePerUnit != null && _pricePerUnit! > 0 && _pricePerLuong != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '= ${Formatters.formatVnd(_pricePerLuong ?? 0)}/lượng',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Fee
                _buildField(
                  label: 'Phí phát sinh (VNĐ) - tùy chọn',
                  controller: _feeController,
                  hint: 'VD: 100.000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Date picker
                _buildDateField(),
                const SizedBox(height: 20),

                // Note
                _buildField(
                  label: 'Ghi chú - tùy chọn',
                  controller: _noteController,
                  hint: 'VD: Mua ở tiệm vàng ABC',
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Summary card
                if (_totalCost != null && _totalCost! > 0)
                  AppCard(
                    color: AppColors.bgCardHighlight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tóm tắt',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _summaryRow('Tổng vốn', Formatters.formatVnd(_totalCost!)),
                        _summaryRow(
                          'Số lượng vàng',
                          '${_quantityInLuong?.toStringAsFixed(4)} lượng',
                        ),
                        _summaryRow(
                          'Giá mua/lượng',
                          Formatters.formatVnd(_pricePerLuong ?? 0),
                        ),
                        _summaryRow(
                          'Phí',
                          Formatters.formatVnd(_fee ?? 0),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveHolding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Lưu vàng',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const DisclaimerBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDefaultPriceHint() {
    if (_selectedGoldTypeId == null || _selectedUnit == null) return '116.000.000';
    final store = context.read<AppStore>();
    final buyPrice = store.getBuyPrice(_selectedGoldTypeId!);
    if (buyPrice != null) {
      final pricePerUnit = GoldUnits.priceFromLuong(buyPrice, _selectedUnit!);
      return pricePerUnit.round().toString();
    }
    return '116.000.000';
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSelector() {
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
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _selectedUnit,
            hint: const Text(
              'Chọn đơn vị',
              style: TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
            underline: const SizedBox(),
            isExpanded: true,
            dropdownColor: AppColors.bgCard,
            items: const [
              DropdownMenuItem(value: 'luong', child: Text('Lượng')),
              DropdownMenuItem(value: 'chi', child: Text('Chỉ')),
              DropdownMenuItem(value: 'phan', child: Text('Phân')),
              DropdownMenuItem(value: 'gram', child: Text('Gram')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedUnit = val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ngày mua',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _buyDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) setState(() => _buyDate = date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.gold, size: 20),
                const SizedBox(width: 12),
                Text(
                  Formatters.formatDate(_buyDate),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
