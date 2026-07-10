import '../constants/app_constants.dart';

/// Gold unit conversion utilities.
/// Vietnamese gold units: lượng, chỉ, phân, gram
/// 1 lượng = 10 chỉ = 100 phân = 37.5 gram
/// 1 chỉ = 10 phân = 3.75 gram
class GoldUnits {
  /// Convert any quantity to lượng (tael) - the base unit for calculations.
  static double toLuong(double quantity, String unit) {
    switch (unit) {
      case 'luong':
        return quantity;
      case 'chi':
        return quantity / AppConstants.chiPerLuong;
      case 'phan':
        return quantity / AppConstants.phanPerLuong;
      case 'gram':
        return quantity / AppConstants.gramsPerLuong;
      default:
        return quantity;
    }
  }

  /// Convert from lượng to a target unit.
  static double fromLuong(double luong, String unit) {
    switch (unit) {
      case 'luong':
        return luong;
      case 'chi':
        return luong * AppConstants.chiPerLuong;
      case 'phan':
        return luong * AppConstants.phanPerLuong;
      case 'gram':
        return luong * AppConstants.gramsPerLuong;
      default:
        return luong;
    }
  }

  /// Convert directly between any two units.
  static double convert(double quantity, String fromUnit, String toUnit) {
    final inLuong = toLuong(quantity, fromUnit);
    return fromLuong(inLuong, toUnit);
  }

  /// Get all supported unit labels.
  static List<String> get units => ['luong', 'chi', 'phan', 'gram'];

  /// Get display label for a unit.
  static String label(String unit) {
    switch (unit) {
      case 'luong':
        return 'Lượng';
      case 'chi':
        return 'Chỉ';
      case 'phan':
        return 'Phân';
      case 'gram':
        return 'Gram';
      default:
        return unit;
    }
  }

  /// Get short label for a unit (for compact display).
  static String shortLabel(String unit) {
    switch (unit) {
      case 'luong':
        return 'lượng';
      case 'chi':
        return 'chỉ';
      case 'phan':
        return 'phân';
      case 'gram':
        return 'g';
      default:
        return unit;
    }
  }

  /// Calculate price per luong from a given unit price.
  /// e.g. if user bought 5 chi at 12,000,000/chỉ,
  /// price per luong = 12,000,000 * 10 = 120,000,000/lượng
  static double pricePerLuong(double pricePerUnit, String unit) {
    final unitsPerLuong = fromLuong(1, unit);
    return pricePerUnit * unitsPerLuong;
  }

  /// Calculate price per a specific unit from price per luong.
  static double priceFromLuong(double pricePerLuong, String unit) {
    final unitsPerLuong = fromLuong(1, unit);
    return pricePerLuong / unitsPerLuong;
  }
}
