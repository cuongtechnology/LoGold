import 'dart:convert';

import '../models/gold_type.dart';
import '../models/user_holding.dart';
import 'profit_loss_calculator.dart';

/// Lỗi định dạng file sao lưu — `message` là câu tiếng Việt hiển thị thẳng cho
/// người dùng.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// Cách nhập dữ liệu từ file sao lưu.
enum ImportMode {
  /// Thêm các mục có id chưa tồn tại, giữ nguyên dữ liệu hiện có.
  merge,

  /// Thay toàn bộ danh mục hiện tại bằng nội dung file.
  replace,
}

/// Nội dung file sao lưu đã parse + validate.
class BackupData {
  final int version;
  final DateTime? exportedAt;
  final List<UserHolding> holdings;
  final List<GoldType> customGoldTypes;

  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.holdings,
    required this.customGoldTypes,
  });
}

/// Kế hoạch nhập đã tính xong (chưa áp dụng) — state cuối cùng nếu nhập.
class ImportPlan {
  final List<UserHolding> holdings;
  final List<GoldType> goldTypes;
  final int addedCount;
  final int skippedCount; // mục bị bỏ qua vì id đã tồn tại (chỉ khi merge)

  const ImportPlan({
    required this.holdings,
    required this.goldTypes,
    required this.addedCount,
    required this.skippedCount,
  });
}

/// Preview hiển thị trong hộp thoại xác nhận.
class ImportPreview {
  final int totalInFile;
  final int newCount; // chưa có trên máy
  final int existingCount; // id đã có trên máy
  final int currentCount; // số mục hiện có trên máy

  const ImportPreview({
    required this.totalInFile,
    required this.newCount,
    required this.existingCount,
    required this.currentCount,
  });
}

/// BackupCodec - Mã hoá/giải mã file sao lưu JSON và xuất CSV.
///
/// Thuần (không Hive, không file picker, không singleton) để unit test được.
///
/// Định dạng JSON (version 1):
/// ```
/// {
///   "format": "lo-backup",
///   "version": 1,
///   "exportedAt": "2026-01-31T09:00:00.000",
///   "holdings": [ { ...UserHolding.toMap(), "goldTypeName": "..." } ],
///   "goldTypes": [ { ...GoldType.toMap() } ]   // chỉ loại vàng tự tạo
/// }
/// ```
class BackupCodec {
  static const formatId = 'lo-backup';
  static const currentVersion = 1;

  /// Giới hạn kích thước file nhập (ký tự) để tránh file rác quá lớn.
  static const maxInputLength = 10 * 1024 * 1024;

  static const _validUnits = {'luong', 'chi', 'phan', 'gram'};
  static const _validStatuses = {'holding', 'sold'};

  // ---------------------------------------------------------------- JSON --

  static String encodeJson({
    required List<UserHolding> holdings,
    required List<GoldType> goldTypes,
    DateTime? exportedAt,
  }) {
    final defaultIds = GoldType.defaults.map((g) => g.id).toSet();
    final namesById = {for (final g in goldTypes) g.id: g.displayName};
    final custom = goldTypes.where((g) => !defaultIds.contains(g.id));

    final map = <String, dynamic>{
      'format': formatId,
      'version': currentVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'holdings': [
        for (final h in holdings)
          {
            ...h.toMap(),
            // Chỉ để người đọc file dễ hiểu; khi nhập dùng goldTypeId.
            'goldTypeName': namesById[h.goldTypeId] ?? h.goldTypeId,
          },
      ],
      'goldTypes': [for (final g in custom) g.toMap()],
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Parse + validate toàn bộ file trước khi trả về; ném
  /// [BackupFormatException] (thông báo tiếng Việt) nếu có bất kỳ lỗi nào.
  static BackupData parse(String raw) {
    if (raw.length > maxInputLength) {
      throw const BackupFormatException(
          'File quá lớn, không phải file sao lưu hợp lệ.');
    }
    // Bỏ BOM nếu có
    final text = raw.startsWith('﻿') ? raw.substring(1) : raw;

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const BackupFormatException(
        'File không đọc được. Hãy chọn file .json được xuất từ ứng dụng.',
      );
    }

    if (decoded is! Map || decoded['format'] != formatId) {
      throw const BackupFormatException(
        'Đây không phải file sao lưu của Lỗ nhiều chưa?',
      );
    }

    final version = decoded['version'];
    if (version is! int || version < 1) {
      throw const BackupFormatException(
          'File sao lưu thiếu thông tin phiên bản.');
    }
    if (version > currentVersion) {
      throw const BackupFormatException(
        'File sao lưu được tạo bởi phiên bản app mới hơn. Hãy cập nhật app rồi thử lại.',
      );
    }

    final rawHoldings = decoded['holdings'];
    if (rawHoldings is! List) {
      throw const BackupFormatException(
          'File sao lưu bị thiếu danh sách vàng.');
    }
    final rawTypes = decoded['goldTypes'] ?? const [];
    if (rawTypes is! List) {
      throw const BackupFormatException(
          'File sao lưu có danh sách loại vàng không hợp lệ.');
    }

    final holdings = <UserHolding>[];
    final seenIds = <String>{};
    for (var i = 0; i < rawHoldings.length; i++) {
      final holding = _parseHolding(rawHoldings[i], i + 1);
      if (!seenIds.add(holding.id)) {
        throw BackupFormatException(
            'Mục số ${i + 1} bị trùng mã với mục khác trong file.');
      }
      holdings.add(holding);
    }

    final types = <GoldType>[];
    final seenTypeIds = <String>{};
    for (var i = 0; i < rawTypes.length; i++) {
      final item = rawTypes[i];
      try {
        if (item is! Map) throw const FormatException();
        final type = GoldType.fromMap(Map<String, dynamic>.from(item));
        if (type.id.isEmpty) throw const FormatException();
        if (seenTypeIds.add(type.id)) types.add(type);
      } catch (_) {
        throw BackupFormatException(
            'Loại vàng số ${i + 1} trong file không hợp lệ.');
      }
    }

    DateTime? exportedAt;
    final rawDate = decoded['exportedAt'];
    if (rawDate is String) exportedAt = DateTime.tryParse(rawDate);

    return BackupData(
      version: version,
      exportedAt: exportedAt,
      holdings: holdings,
      customGoldTypes: types,
    );
  }

  static UserHolding _parseHolding(Object? item, int position) {
    final error =
        BackupFormatException('Mục số $position trong file không hợp lệ.');
    if (item is! Map) throw error;

    final UserHolding h;
    try {
      h = UserHolding.fromMap(Map<String, dynamic>.from(item));
    } catch (_) {
      throw error;
    }

    final numbers = <double>[
      h.quantity,
      h.quantityInLuong,
      h.buyPricePerLuong,
      h.totalCost,
      h.fee,
      if (h.sellPricePerLuong != null) h.sellPricePerLuong!,
      if (h.sellFee != null) h.sellFee!,
    ];
    final valid = h.id.isNotEmpty &&
        h.goldTypeId.isNotEmpty &&
        _validUnits.contains(h.unit) &&
        _validStatuses.contains(h.status) &&
        numbers.every((n) => n.isFinite && n >= 0) &&
        h.quantityInLuong > 0;
    if (!valid) throw error;
    return h;
  }

  // ------------------------------------------------------- merge/replace --

  /// Tính state sau khi nhập — thuần, không đụng dữ liệu hiện có.
  /// Loại vàng: luôn hợp nhất (thêm loại tự tạo chưa có), kể cả khi replace.
  static ImportPlan plan({
    required List<UserHolding> existingHoldings,
    required List<GoldType> existingGoldTypes,
    required BackupData data,
    required ImportMode mode,
  }) {
    final knownTypeIds = existingGoldTypes.map((g) => g.id).toSet();
    final goldTypes = [
      ...existingGoldTypes,
      ...data.customGoldTypes.where((g) => !knownTypeIds.contains(g.id)),
    ];

    if (mode == ImportMode.replace) {
      return ImportPlan(
        holdings: List.of(data.holdings),
        goldTypes: goldTypes,
        addedCount: data.holdings.length,
        skippedCount: 0,
      );
    }

    final existingIds = existingHoldings.map((h) => h.id).toSet();
    final incoming =
        data.holdings.where((h) => !existingIds.contains(h.id)).toList();
    return ImportPlan(
      holdings: [...existingHoldings, ...incoming],
      goldTypes: goldTypes,
      addedCount: incoming.length,
      skippedCount: data.holdings.length - incoming.length,
    );
  }

  static ImportPreview preview({
    required List<UserHolding> existingHoldings,
    required BackupData data,
  }) {
    final existingIds = existingHoldings.map((h) => h.id).toSet();
    final existing =
        data.holdings.where((h) => existingIds.contains(h.id)).length;
    return ImportPreview(
      totalInFile: data.holdings.length,
      newCount: data.holdings.length - existing,
      existingCount: existing,
      currentCount: existingHoldings.length,
    );
  }

  // ----------------------------------------------------------------- CSV --

  /// Dấu BOM UTF-8 — Excel trên Windows tiếng Việt cần để hiện đúng dấu.
  static const utf8Bom = '﻿';

  static const csvHeader = [
    'Loại Vàng',
    'Mã Loại Vàng',
    'Số Lượng',
    'Đơn Vị',
    'Tương Đương (Lượng)',
    'Giá Mua/Lượng (VNĐ)',
    'Phí Mua (VNĐ)',
    'Tổng Vốn (VNĐ)',
    'Ngày Mua',
    'Trạng Thái',
    'Giá Bán/Lượng (VNĐ)',
    'Ngày Bán',
    'Phí Bán (VNĐ)',
    'Lãi/Lỗ Đã Chốt (VNĐ)',
    'Ghi Chú',
  ];

  /// Escape 1 ô CSV theo RFC 4180: bọc nháy kép nếu chứa dấu phẩy, nháy kép
  /// hoặc xuống dòng; nháy kép bên trong được nhân đôi.
  static String csvField(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String encodeCsv({
    required List<UserHolding> holdings,
    required List<GoldType> goldTypes,
    bool withBom = false,
  }) {
    final namesById = {for (final g in goldTypes) g.id: g.displayName};
    String date(DateTime d) => d.toIso8601String().split('T').first;

    final rows = <List<String>>[csvHeader];
    for (final h in holdings) {
      final realized = ProfitLossCalculator.calculateRealized(h);
      rows.add([
        namesById[h.goldTypeId] ?? h.goldTypeId,
        h.goldTypeId,
        '${h.quantity}',
        h.unit,
        h.quantityInLuong.toStringAsFixed(4),
        '${h.buyPricePerLuong.round()}',
        '${h.fee.round()}',
        '${h.totalCost.round()}',
        date(h.buyDate),
        h.status,
        h.sellPricePerLuong == null ? '' : '${h.sellPricePerLuong!.round()}',
        h.sellDate == null ? '' : date(h.sellDate!),
        h.sellFee == null ? '' : '${h.sellFee!.round()}',
        realized == null ? '' : '${realized.profitLoss.round()}',
        h.note ?? '',
      ]);
    }
    // RFC 4180 dùng CRLF làm ngắt dòng.
    final body = '${rows.map((r) => r.map(csvField).join(',')).join('\r\n')}\r\n';
    return withBom ? '$utf8Bom$body' : body;
  }
}
