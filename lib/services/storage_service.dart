import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// StorageService - Wrapper mỏng quanh Hive.
///
/// Dùng `Box<String>` với giá trị JSON để tránh phải chạy code generation
/// (`hive_generator`) — code gen làm chậm iteration và tăng phức tạp build.
/// Với volume dữ liệu app Lỗ (< 1000 rows), overhead JSON không đáng kể.
///
/// Init 1 lần trong `main()` trước `runApp`.
class StorageService {
  static bool _initialized = false;

  static late Box<String> _holdings;
  static late Box<String> _goldTypes;
  static late Box<String> _alerts;
  static late Box<String> _settings;
  static late Box<String> _priceHistory;

  static Box<String> get holdings => _holdings;
  static Box<String> get goldTypes => _goldTypes;
  static Box<String> get alerts => _alerts;
  static Box<String> get settings => _settings;
  static Box<String> get priceHistory => _priceHistory;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    _holdings = await Hive.openBox<String>(AppConstants.holdingsBox);
    _goldTypes = await Hive.openBox<String>(AppConstants.goldTypesBox);
    _alerts = await Hive.openBox<String>(AppConstants.alertsBox);
    _settings = await Hive.openBox<String>(AppConstants.settingsBox);
    _priceHistory = await Hive.openBox<String>(AppConstants.priceHistoryBox);

    _initialized = true;
  }

  /// Ghi list of map vào box: xoá sạch → ghi mới. Dùng khi cần đảm bảo
  /// box khớp state trong memory (post-mutate save).
  static Future<void> writeMapList(
    Box<String> box,
    Iterable<Map<String, dynamic>> items, {
    required String Function(Map<String, dynamic>) keyOf,
  }) async {
    await box.clear();
    final entries = <String, String>{};
    for (final item in items) {
      entries[keyOf(item)] = jsonEncode(item);
    }
    await box.putAll(entries);
  }

  /// Đọc toàn bộ giá trị box thành list map.
  static List<Map<String, dynamic>> readMapList(Box<String> box) {
    return box.values
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .toList();
  }

  /// Ghi 1 map vào box với key cho trước.
  static Future<void> putMap(
    Box<String> box,
    String key,
    Map<String, dynamic> value,
  ) async {
    await box.put(key, jsonEncode(value));
  }

  /// Ghi giá trị vào settings box (tự stringify các kiểu cơ bản).
  static Future<void> putSetting(String key, Object? value) async {
    if (value == null) {
      await _settings.delete(key);
    } else {
      await _settings.put(key, jsonEncode(value));
    }
  }

  /// Đọc setting đã lưu; trả null nếu không có.
  static T? getSetting<T>(String key) {
    final raw = _settings.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as T?;
  }
}
