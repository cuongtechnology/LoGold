import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';

/// Onboarding screen - introduces the app and lets user add their first gold purchase.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Form fields for first purchase
  String? _selectedGoldTypeId;
  final _quantityController = TextEditingController();
  // Không đặt mặc định — bắt user luôn phải bấm chọn tường minh để tránh
  // nhầm đơn vị (lượng/chỉ/phân/gram) dẫn tới tính sai lãi/lỗ.
  String? _selectedUnit;
  final _priceController = TextEditingController();
  DateTime _buyDate = DateTime.now();

  @override
  void dispose() {
    _pageController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    final store = context.read<AppStore>();
    // Add the first purchase if filled. Fallback về loại vàng đầu tiên nếu
    // user quên bấm chọn chip (vẫn có ý định thêm vì đã điền số lượng/giá) —
    // tránh trường hợp âm thầm bỏ qua vì thiếu mỗi bước chọn loại vàng.
    final goldTypeId = _selectedGoldTypeId ??
        (store.goldTypes.isNotEmpty ? store.goldTypes.first.id : null);
    final wantsToAdd = goldTypeId != null &&
        _quantityController.text.isNotEmpty &&
        _priceController.text.isNotEmpty;

    if (wantsToAdd) {
      // Đơn vị không có fallback tự động — bắt user chọn tường minh, khác
      // với loại vàng (đã fallback ở trên) vì nhầm đơn vị gây sai số tiền.
      if (_selectedUnit == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn đơn vị (lượng/chỉ/phân/gram)'),
            backgroundColor: AppColors.loss,
          ),
        );
        return;
      }
      // Await để đảm bảo holding đã lưu xong trước khi hoàn tất onboarding —
      // tránh trường hợp AppGate chuyển sang Home trước khi ghi xong dữ liệu.
      await store.addHolding(
        goldTypeId: goldTypeId,
        quantity: double.tryParse(_quantityController.text) ?? 0,
        unit: _selectedUnit!,
        buyPricePerUnit: double.tryParse(
              _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0,
        buyDate: _buyDate,
      );
    }
    await store.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildFeaturesPage(),
                  _buildFirstPurchasePage(),
                ],
              ),
            ),
            _buildBottomBar(),
            const DisclaimerBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon area
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Lỗ nhiều chưa?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chào mừng đến với Lỗ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ứng dụng theo dõi vàng cho người Việt.\n'
            'Mua cao? Lỗ nặng? Không sao,\nbạn không cô đơn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          // Feature highlights
          _featureRow('📊', 'Theo dõi lãi/lỗ', 'Tính toán tự động theo giá mua vào'),
          _featureRow('😂', 'Meme an ủi', 'Trạng thái hài hước theo mức lỗ'),
          _featureRow('🔔', 'Cảnh báo giá', 'Thông báo khi giá vàng biến động'),
        ],
      ),
    );
  }

  Widget _featureRow(String emoji, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Cách hoạt động',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 32),
          _stepCard('1', 'Nhập thông tin vàng', 'Loại vàng, số lượng, giá mua, ngày mua'),
          _stepCard('2', 'Giá tự động cập nhật', 'App lấy giá mua vào từ các tiệm vàng'),
          _stepCard('3', 'Xem lãi/lỗ tức thì', 'Tổng vốn, giá trị hiện tại, % lãi/lỗ'),
          _stepCard('4', 'Nhận meme an ủi', 'Tùy mức lỗ mà nhận câu nói phù hợp'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lossBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.loss, width: 1),
            ),
            child: const Row(
              children: [
                Text('⚠️', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'App chỉ theo dõi, không khuyến nghị mua/bán. Quyết định là của bạn!',
                    style: TextStyle(color: AppColors.loss, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(String num, String title, String desc) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: AppColors.bgPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstPurchasePage() {
    final store = context.watch<AppStore>();
    final goldTypes = store.goldTypes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thêm vàng đầu tiên',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bỏ qua nếu muốn, bạn có thể thêm sau.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Gold type selector
          const Text(
            'Loại vàng',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: goldTypes.map((gt) {
              final selected = _selectedGoldTypeId == gt.id;
              return ChoiceChip(
                label: Text(gt.displayName),
                selected: selected,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedGoldTypeId = gt.id;
                    });
                  }
                },
                selectedColor: AppColors.gold,
                labelStyle: TextStyle(
                  color: selected ? AppColors.bgPrimary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Quantity + Unit
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
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
          const SizedBox(height: 20),

          // Price per unit
          _buildTextField(
            label: _selectedUnit == null
                ? 'Giá mua / đơn vị (VNĐ)'
                : 'Giá mua / ${_unitLabel(_selectedUnit!)} (VNĐ)',
            controller: _priceController,
            hint: 'VD: 116.000.000',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          // Date picker
          _buildDateField(),
          const SizedBox(height: 32),

          // Skip or add button
          Row(
            children: [
              TextButton(
                onPressed: () {
                  store.completeOnboarding();
                },
                child: const Text(
                  'Bỏ qua',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
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
                  '${_buyDate.day}/${_buyDate.month}/${_buyDate.year}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isLastPage = _currentPage == 2;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Page indicators
          Row(
            children: List.generate(3, (i) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentPage ? AppColors.gold : AppColors.divider,
                ),
              );
            }),
          ),
          const Spacer(),
          if (!isLastPage)
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Tiếp tục'),
            )
          else
            ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Bắt đầu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  String _unitLabel(String unit) {
    switch (unit) {
      case 'luong':
        return 'lượng';
      case 'chi':
        return 'chỉ';
      case 'phan':
        return 'phân';
      case 'gram':
        return 'gram';
      default:
        return unit;
    }
  }
}
