import 'package:intl/intl.dart';

/// Utility functions for formatting Vietnamese currency and numbers.
class Formatters {
  /// Format VND with thousand separators and "đ" suffix.
  /// Example: 1234567 -> "1.234.567đ" (Vietnamese uses dots as separators)
  static String formatVnd(double value, {bool withSymbol = true}) {
    final absValue = value.abs();
    final formatted = NumberFormat('#,###', 'vi_VN').format(absValue);
    final symbol = withSymbol ? 'đ' : '';
    if (value < 0) {
      return '-$formatted$symbol';
    }
    return '$formatted$symbol';
  }

  /// Parse a VND amount typed by the user.
  /// VND has no fractional part, so every non-digit is treated as a separator:
  /// "116.000.000", "116,000,000", "116 000 000đ" -> 116000000.
  /// Returns null when no digits are present.
  static double? parseMoney(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  /// Parse a gold quantity typed by the user, accepting "," or "." as the
  /// decimal separator: "0,5" and "0.5" -> 0.5.
  /// Returns null for empty or malformed input.
  static double? parseQuantity(String input) {
    final normalized = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  /// Format VND in compact form for large numbers
  /// Example: 1230000 -> "1.23tr", 500000 -> "500k"
  static String formatVndCompact(double value) {
    final absValue = value.abs();
    String formatted;
    if (absValue >= 1000000000) {
      formatted = '${(absValue / 1000000000).toStringAsFixed(1)} tỷ';
    } else if (absValue >= 1000000) {
      formatted = '${(absValue / 1000000).toStringAsFixed(0)} triệu';
    } else if (absValue >= 1000) {
      formatted = '${(absValue / 1000).toStringAsFixed(0)}k';
    } else {
      formatted = absValue.round().toString();
    }
    return value < 0 ? '-$formatted' : formatted;
  }

  /// Format percentage with sign
  /// Example: 8.5 -> "+8.50%", -3.2 -> "-3.20%"
  static String formatPercent(double value, {int decimals = 2}) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimals)}%';
  }

  /// Format gold quantity with unit
  /// Example: 2.5 luong -> "2.5 lượng", 5 chi -> "5 chỉ"
  static String formatQuantity(double quantity, String unit) {
    final unitLabel = _unitLabel(unit);
    // Remove trailing zeros
    String qtyStr = quantity.toStringAsFixed(2);
    if (qtyStr.contains('.')) {
      qtyStr = qtyStr.replaceAll(RegExp(r'0+$'), '');
      qtyStr = qtyStr.replaceAll(RegExp(r'\.$'), '');
    }
    return '$qtyStr $unitLabel';
  }

  /// Format date as dd/MM/yyyy
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format date and time as dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  /// Format time ago in Vietnamese
  /// Example: "5 phút trước", "2 giờ trước", "3 ngày trước"
  static String formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    return formatDate(dateTime);
  }

  /// Check if price data is stale (older than threshold)
  static bool isStale(DateTime updatedAt, {int thresholdMinutes = 60}) {
    return DateTime.now().difference(updatedAt).inMinutes > thresholdMinutes;
  }

  static String _unitLabel(String unit) {
    switch (unit) {
      case 'luong':
        return 'lượng';
      case 'chi':
        return 'chỉ';
      case 'gram':
        return 'gram';
      default:
        return unit;
    }
  }
}
