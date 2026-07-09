import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../components/ui_components.dart';

/// Màn "Thông tin tác giả" — giới thiệu tác giả app + dịch vụ liên quan,
/// truy cập từ Cài đặt → Thông tin & Pháp lý.
class AuthorInfoScreen extends StatelessWidget {
  const AuthorInfoScreen({super.key});

  static const _services = [
    'Thiết kế website',
    'Thiết kế phần mềm',
    'Thiết kế App Mobile',
    'Giải pháp CNTT & Bảo mật',
    'Chạy quảng cáo Facebook/Google',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin tác giả')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/author.jpg',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tạ Tiến Cường',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tác giả ứng dụng Lỗ nhiều chưa?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _contactRow(Icons.email_outlined, 'Email', 'cuongtechnology@gmail.com'),
                    const SizedBox(height: 16),
                    _contactRow(Icons.chat_bubble_outline, 'Zalo', '0943.847.333'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, top: 8),
                  child: Text(
                    'Dịch vụ',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._services.map(_serviceTile),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Liên hệ qua email hoặc Zalo ở trên để trao đổi chi tiết.',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _serviceTile(String text) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
