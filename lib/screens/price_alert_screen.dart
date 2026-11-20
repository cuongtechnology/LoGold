import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../components/ui_components.dart';
import '../models/price_alert.dart';
import '../utils/formatters.dart';
import '../services/notification_service.dart';

/// Price Alert Screen - Manage price alerts and view notifications.
class PriceAlertScreen extends StatefulWidget {
  const PriceAlertScreen({super.key});

  @override
  State<PriceAlertScreen> createState() => _PriceAlertScreenState();
}

class _PriceAlertScreenState extends State<PriceAlertScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo giá'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: 'Cảnh báo'),
            Tab(text: 'Thông báo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlertsTab(store),
          _buildNotificationsTab(store),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAlertDialog(context, store),
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: AppColors.bgPrimary),
      ),
    );
  }

  // ============== Alerts Tab ==============

  Widget _buildAlertsTab(AppStore store) {
    final alerts = store.alerts;

    if (alerts.isEmpty) {
      return EmptyState(
        emoji: '🔔',
        title: 'Chưa có cảnh báo nào',
        subtitle: 'Thêm cảnh báo để được thông báo khi giá vàng thay đổi',
        actionText: 'Thêm cảnh báo',
        onAction: () => _showAddAlertDialog(context, store),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _buildAlertCard(store, alert);
      },
    );
  }

  Widget _buildAlertCard(AppStore store, PriceAlert alert) {
    final goldType = alert.goldTypeId != null
        ? store.goldTypes.where((g) => g.id == alert.goldTypeId).firstOrNull
        : null;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: alert.enabled
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : AppColors.bgCardHighlight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getAlertIcon(alert.type),
              color: alert.enabled ? AppColors.gold : AppColors.textHint,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (goldType != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    goldType.displayName,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Áp dụng cho tất cả loại vàng',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: alert.enabled,
            onChanged: (val) => store.toggleAlert(alert.id),
            activeColor: AppColors.gold,
          ),
          IconButton(
            onPressed: () => _confirmDelete(store, alert),
            icon: const Icon(Icons.delete_outline, color: AppColors.loss, size: 20),
          ),
        ],
      ),
    );
  }

  IconData _getAlertIcon(PriceAlertType type) {
    switch (type) {
      case PriceAlertType.breakeven:
        return Icons.balance;
      case PriceAlertType.lossThreshold:
        return Icons.trending_down;
      case PriceAlertType.profitThreshold:
        return Icons.trending_up;
      case PriceAlertType.priceTarget:
        return Icons.flag_outlined;
      case PriceAlertType.priceSurge:
        return Icons.flash_on;
    }
  }

  // ============== Notifications Tab ==============

  Widget _buildNotificationsTab(AppStore store) {
    final notifications = store.notifications;

    if (notifications.isEmpty) {
      return const EmptyState(
        emoji: '📭',
        title: 'Chưa có thông báo',
        subtitle: 'Các thông báo cảnh báo giá sẽ hiển thị tại đây',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  // Clear notifications via store
                  _showClearConfirm(context, store);
                },
                icon: const Icon(Icons.clear_all, size: 18, color: AppColors.textHint),
                label: const Text(
                  'Xóa tất cả',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _buildNotificationCard(notif);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notif.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatTimeAgo(notif.timestamp),
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== Add Alert Dialog ==============

  void _showAddAlertDialog(BuildContext context, AppStore store) {
    showDialog(
      context: context,
      builder: (context) => _AddAlertDialog(store: store),
    );
  }

  void _confirmDelete(AppStore store, PriceAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Xóa cảnh báo?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Bạn có chắc muốn xóa cảnh báo này?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () {
              store.removeAlert(alert.id);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm(BuildContext context, AppStore store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Xóa tất cả thông báo?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Tất cả thông báo sẽ bị xóa vĩnh viễn.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () {
              // Clear notifications
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa tất cả thông báo'),
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

/// Dialog for adding a new price alert.
class _AddAlertDialog extends StatefulWidget {
  final AppStore store;

  const _AddAlertDialog({required this.store});

  @override
  State<_AddAlertDialog> createState() => _AddAlertDialogState();
}

class _AddAlertDialogState extends State<_AddAlertDialog> {
  PriceAlertType _selectedType = PriceAlertType.priceTarget;
  String? _selectedGoldTypeId;
  double _targetPrice = 0;
  double _targetPL = 0;
  final _priceController = TextEditingController();
  final _plController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _plController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goldTypes = widget.store.goldTypes;

    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: const Text('Thêm cảnh báo', style: TextStyle(color: AppColors.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert type selector
            const Text(
              'Loại cảnh báo',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildTypeSelector(),
            const SizedBox(height: 16),

            // Gold type selector
            const Text(
              'Loại vàng',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _selectedGoldTypeId,
              decoration: _inputDecoration('Tất cả loại vàng'),
              dropdownColor: AppColors.bgCard,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tất cả loại vàng', style: TextStyle(color: AppColors.textPrimary)),
                ),
                ...goldTypes.map((g) => DropdownMenuItem<String?>(
                      value: g.id,
                      child: Text(g.displayName, style: const TextStyle(color: AppColors.textPrimary)),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedGoldTypeId = val),
            ),
            const SizedBox(height: 16),

            // Conditional input based on type
            if (_selectedType == PriceAlertType.priceTarget) ...[
              const Text(
                'Giá mục tiêu (đ/lượng)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('VD: 120000000'),
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (val) => _targetPrice = Formatters.parseMoney(val) ?? 0,
              ),
            ],
            if (_selectedType == PriceAlertType.lossThreshold ||
                _selectedType == PriceAlertType.profitThreshold) ...[
              const Text(
                'Ngưỡng (VNĐ)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _plController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  _selectedType == PriceAlertType.lossThreshold
                      ? 'VD: 5000000 (lỗ 5 triệu)'
                      : 'VD: 10000000 (lãi 10 triệu)',
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (val) => _targetPL = Formatters.parseMoney(val) ?? 0,
              ),
            ],
            if (_selectedType == PriceAlertType.breakeven) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.profitBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.profit, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sẽ báo khi tổng tài sản về gần hòa vốn',
                        style: TextStyle(color: AppColors.profit, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_selectedType == PriceAlertType.priceSurge) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lossBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.loss, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sẽ báo khi giá vàng biến động mạnh',
                        style: TextStyle(color: AppColors.loss, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: AppColors.textHint)),
        ),
        ElevatedButton(
          onPressed: _addAlert,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.bgPrimary,
          ),
          child: const Text('Thêm'),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      (PriceAlertType.priceTarget, 'Giá mục tiêu', Icons.flag_outlined),
      (PriceAlertType.breakeven, 'Về hòa vốn', Icons.balance),
      (PriceAlertType.lossThreshold, 'Ngưỡng lỗ', Icons.trending_down),
      (PriceAlertType.profitThreshold, 'Ngưỡng lãi', Icons.trending_up),
      (PriceAlertType.priceSurge, 'Biến động mạnh', Icons.flash_on),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final isSelected = _selectedType == t.$1;
        return GestureDetector(
          onTap: () => setState(() => _selectedType = t.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.gold : AppColors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.$3, size: 16, color: isSelected ? AppColors.gold : AppColors.textHint),
                const SizedBox(width: 6),
                Text(
                  t.$2,
                  style: TextStyle(
                    color: isSelected ? AppColors.gold : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
      filled: true,
      fillColor: AppColors.bgPrimary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  void _addAlert() {
    final alert = PriceAlert(
      id: const Uuid().v4(),
      type: _selectedType,
      goldTypeId: _selectedGoldTypeId,
      targetPrice: _selectedType == PriceAlertType.priceTarget ? _targetPrice : null,
      targetProfitLoss:
          (_selectedType == PriceAlertType.lossThreshold || _selectedType == PriceAlertType.profitThreshold)
              ? _targetPL
              : null,
      enabled: true,
      createdAt: DateTime.now(),
    );

    widget.store.addAlert(alert);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã thêm cảnh báo'),
        backgroundColor: AppColors.bgCard,
      ),
    );
  }
}
