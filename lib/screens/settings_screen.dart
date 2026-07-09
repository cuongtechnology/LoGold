import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';
import '../services/export_service.dart';
import '../services/review_service.dart';
import '../components/ui_components.dart';
import 'author_info_screen.dart';
import 'price_alert_screen.dart';

/// Settings screen - app settings, privacy, export, and about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActionTile(
                icon: Icons.person_outline,
                title: 'Thông tin tác giả',
                subtitle: 'Tạ Tiến Cường - liên hệ & dịch vụ',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthorInfoScreen()),
                ),
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('Bảo mật'),
              _buildToggleTile(
                icon: Icons.visibility_off,
                title: 'Chế độ ẩn số',
                subtitle: 'Che giấu các số tiền trong ứng dụng',
                value: store.privacyMode,
                onChanged: (_) => store.togglePrivacyMode(),
              ),
              _buildToggleTile(
                icon: Icons.lock_outline,
                title: 'Mã PIN',
                subtitle: 'Yêu cầu mã PIN khi mở ứng dụng',
                value: store.pinEnabled,
                onChanged: (val) => _handlePinToggle(val, store),
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('Thông báo'),
              _buildActionTile(
                icon: Icons.notifications_active_outlined,
                title: 'Cảnh báo giá',
                subtitle: 'Đặt ngưỡng lãi/lỗ hoặc giá để nhận thông báo',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PriceAlertScreen()),
                ),
              ),
              _buildInfoTile(
                icon: Icons.campaign_outlined,
                title: 'Thông báo đẩy',
                subtitle: store.pushNotificationStatusMessage,
                onTap: () => _showPushInfoDialog(context, store),
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('Dữ liệu'),
              _buildActionTile(
                icon: Icons.file_download,
                title: 'Xuất CSV',
                subtitle: 'Xuất danh mục vàng ra file CSV',
                onTap: () => _exportData(context, 'csv'),
              ),
              _buildActionTile(
                icon: Icons.code,
                title: 'Xuất JSON',
                subtitle: 'Xuất dữ liệu ra file JSON (backup)',
                onTap: () => _exportData(context, 'json'),
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('Thông tin & Pháp lý'),
              _buildActionTile(
                icon: Icons.info_outline,
                title: 'Miễn trừ trách nhiệm',
                subtitle: 'Thông tin chỉ mang tính tham khảo',
                onTap: () => _showDisclaimerDialog(context),
              ),
              _buildActionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Chính sách bảo mật',
                subtitle: 'Dữ liệu của bạn được lưu trên thiết bị',
                onTap: () => _showPrivacyDialog(context),
              ),
              _buildActionTile(
                icon: Icons.star_outline,
                title: 'Về ứng dụng Lỗ',
                subtitle: 'Phiên bản 1.0.0 - Gold Loss Tracker',
                onTap: () => _showAboutDialog(context),
              ),
              _buildActionTile(
                icon: Icons.thumb_up_outlined,
                title: 'Đánh giá ứng dụng',
                subtitle: 'Ủng hộ Lỗ nhiều chưa? trên Play Store',
                onTap: () => ReviewService.instance.openStoreListing(),
              ),
              const SizedBox(height: 16),

              // Disclaimer bar at bottom
              _buildDisclaimerBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? AppColors.loss : AppColors.gold;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDanger ? AppColors.loss : AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
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
          Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppConstants.disclaimer,
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _handlePinToggle(bool enable, AppStore store) {
    if (enable) {
      _showPinEntryDialog(context, store);
    } else {
      store.setPinEnabled(false);
    }
  }

  void _showPinEntryDialog(BuildContext context, AppStore store) {
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: AppColors.bgCard,
              title: const Text(
                'Đặt mã PIN',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl1,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Mã PIN (4-6 số)',
                      labelStyle: TextStyle(color: AppColors.textHint),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.gold),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  TextField(
                    controller: ctrl2,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mã PIN',
                      labelStyle: TextStyle(color: AppColors.textHint),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.gold),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: AppColors.loss, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final pin1 = ctrl1.text.trim();
                    final pin2 = ctrl2.text.trim();
                    if (pin1.length < 4) {
                      setState(() => error = 'PIN phải có 4-6 số');
                      return;
                    }
                    if (pin1 != pin2) {
                      setState(() => error = 'Mã PIN không khớp');
                      return;
                    }
                    store.setPinEnabled(true, pin: pin1);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã bật mã PIN'),
                        backgroundColor: AppColors.profit,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgPrimary,
                  ),
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportData(BuildContext context, String format) async {
    final export = ExportService.instance;
    final String data;
    final String fileName;

    if (format == 'csv') {
      data = export.exportToCSV();
      fileName = 'lo_holdings.csv';
    } else {
      data = export.exportToJSON();
      fileName = 'lo_backup.json';
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(data);

      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Xuất dữ liệu từ Lỗ nhiều chưa?',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xuất file thất bại: $e'),
          backgroundColor: AppColors.loss,
        ),
      );
    }
  }

  void _showPushInfoDialog(BuildContext context, AppStore store) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text(
            'Thông báo đẩy',
            style: TextStyle(color: AppColors.gold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trạng thái: ${store.pushNotificationStatusMessage}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Khi giá SJC biến động mạnh, Lỗ nhiều chưa? có thể gửi thông báo '
                'đẩy tới điện thoại kể cả khi bạn không mở app. Nếu trạng thái '
                'trên báo chưa hoạt động, kiểm tra lại quyền thông báo cho app '
                'trong Cài đặt hệ thống của điện thoại.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgPrimary,
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  void _showDisclaimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text(
            'Miễn trừ trách nhiệm',
            style: TextStyle(color: AppColors.gold),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Ứng dụng "Lỗ" - Lỗ nhiều chưa? - là công cụ theo dõi danh mục vàng cá nhân.\n\n'
              '• Thông tin về giá vàng chỉ mang tính tham khảo\n'
              '• Không phải là khuyến nghị mua/bán vàng\n'
              '• Người dùng tự chịu trách nhiệm về quyết định đầu tư\n'
              '• Giá vàng thực tế có thể chênh lệch tùy tiệm vàng\n'
              '• Dữ liệu có thể không cập nhật theo thời gian thực\n\n'
              'Hãy luôn tham khảo giá từ tiệm vàng hoặc nguồn uy tín '
              'trước khi thực hiện giao dịch.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgPrimary,
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text(
            'Chính sách bảo mật',
            style: TextStyle(color: AppColors.gold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ứng dụng "Lỗ nhiều chưa?" tôn trọng quyền riêng tư của bạn:\n\n'
                  '• Danh mục vàng, giá mua, ghi chú, mã PIN (nếu bật) chỉ lưu '
                  'cục bộ trên thiết bị — không tài khoản, không đồng bộ lên '
                  'server nào của chúng tôi\n'
                  '• App hiển thị quảng cáo qua Google AdMob — AdMob có thể '
                  'thu thập Advertising ID và dữ liệu thiết bị để cá nhân hoá '
                  'quảng cáo\n'
                  '• App gửi thông báo đẩy qua Firebase Cloud Messaging — cần '
                  'gửi 1 mã định danh thiết bị (không phải thông tin cá nhân) '
                  'để biết gửi thông báo tới đúng máy\n'
                  '• Giá vàng lấy từ API công khai, không gắn với thông tin cá '
                  'nhân nào\n'
                  '• Gỡ app khỏi máy sẽ xoá toàn bộ dữ liệu cục bộ ngay lập tức\n\n'
                  'Chi tiết đầy đủ tại:',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'https://cuongtechnology.github.io/LoGold/',
                  style: const TextStyle(
                    color: AppColors.gold,
                    height: 1.5,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgPrimary,
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Row(
            children: [
              const Text(
                'Lỗ',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'v1.0.0',
                  style: TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gold Loss Tracker',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Ứng dụng theo dõi lãi/lỗ vàng với phong cách meme '
                'dành cho người Việt mua vàng ở giá cao.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              SizedBox(height: 12),
              Text(
                '"Bạn không cô đơn, cả làng đang lỗ."',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgPrimary,
              ),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

}
