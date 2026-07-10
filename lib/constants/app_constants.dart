import 'package:flutter/material.dart';

/// App-wide constants for Lỗ
class AppConstants {
  // App info
  static const String appName = 'Lỗ nhiều chưa?';
  static const String appFullName = 'Lỗ nhiều chưa?';
  static const String slogan = 'Hôm nay lỗ nhiều không?';
  static const String disclaimer =
      'Thông tin chỉ mang tính tham khảo, không phải khuyến nghị mua/bán vàng.';

  // Gold unit conversions (Vietnamese standard)
  // 1 lượng = 10 chỉ = 100 phân = 37.5 gram
  // 1 chỉ = 10 phân = 3.75 gram
  static const double gramsPerLuong = 37.5;
  static const double chiPerLuong = 10.0;
  static const double phanPerLuong = 100.0;
  static const double gramsPerChi = 3.75;

  // Price update interval (minutes)
  static const int priceUpdateIntervalMinutes = 30;

  // Hive box names
  static const String holdingsBox = 'holdings_box';
  static const String goldTypesBox = 'gold_types_box';
  static const String alertsBox = 'alerts_box';
  static const String settingsBox = 'settings_box';
  static const String priceHistoryBox = 'price_history_box';
}

/// App color palette - Dark theme with gold accents
class AppColors {
  // Primary
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFFC9A227);
  static const Color goldLight = Color(0xFFFFE55C);

  // Backgrounds (dark theme)
  static const Color bgPrimary = Color(0xFF121212);
  static const Color bgSecondary = Color(0xFF1E1E1E);
  static const Color bgCard = Color(0xFF242424);
  static const Color bgCardHighlight = Color(0xFF2D2D2D);

  // Status colors
  static const Color loss = Color(0xFFFF5252);
  static const Color lossDark = Color(0xFFD32F2F);
  static const Color lossBg = Color(0x33FF5252);
  static const Color profit = Color(0xFF4CAF50);
  static const Color profitDark = Color(0xFF388E3C);
  static const Color profitBg = Color(0x334CAF50);
  static const Color neutral = Color(0xFF9E9E9E);
  static const Color warning = Color(0xFFFFA726);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textHint = Color(0xFF707070);

  // Accent
  static const Color accent = Color(0xFFFFD700);
  static const Color divider = Color(0xFF333333);
}

/// Meme status labels with descriptions (for loss levels)
class MemeStatusLabels {
  static const Map<String, String> lossMinimal = {
    'label': 'Xước nhẹ ví tiền',
    'desc': 'Lỗ dưới 1%',
  };
  static const Map<String, String> lossLight = {
    'label': 'Bắt đầu thấy sai sai',
    'desc': 'Lỗ 1-3%',
  };
  static const Map<String, String> lossModerate = {
    'label': 'Tim hơi nhói',
    'desc': 'Lỗ 3-7%',
  };
  static const Map<String, String> lossHeavy = {
    'label': 'Cần người ôm',
    'desc': 'Lỗ 7-15%',
  };
  static const Map<String, String> lossSpiritual = {
    'label': 'Đầu tư dài hạn bất đắc dĩ',
    'desc': 'Lỗ trên 15%',
  };
  static const Map<String, String> breakeven = {
    'label': 'Về bờ',
    'desc': 'Hòa vốn',
  };
  static const Map<String, String> profitCautious = {
    'label': 'Lãi rồi nhưng chưa dám bán',
    'desc': 'Đang có lãi',
  };
}
