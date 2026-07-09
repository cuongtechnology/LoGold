import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/gold_price.dart';
import 'price_adapter.dart';

/// VangTodayPriceAdapter — fetch giá vàng từ API công khai `vang.today`.
///
/// **Vì sao dùng nguồn này**: miễn phí, không cần API key, bật CORS
/// (`Access-Control-Allow-Origin: *`) nên gọi được cả từ web build — không
/// cần proxy qua CF Worker như `SjcPriceAdapter` phải làm để né
/// Cloudflare-challenge/CORS. Giá trong nước trả sẵn VND/lượng, không cần
/// quy đổi như DOJI HTML ("nghìn/chỉ").
///
/// **Lưu ý quan trọng**: trang docs (`vang.today/vi/api`) ghi response shape
/// `{"success", "data": [{"type_code", ...}]}` nhưng response THỰC TẾ (đã
/// test trực tiếp) là `{"success", "prices": {CODE: {...}}}` — dict theo mã
/// loại, không phải mảng `data`. Code theo response thực tế, không theo docs.
///
/// **Endpoint lịch sử** (`?type=X&days=N`) cũng không giới hạn 1-30 ngày như
/// docs ghi — test `days=500` vẫn nhận và trả về toàn bộ dữ liệu server có
/// (server chỉ mới bắt đầu ghi từ ~23/11/2025, không phải kho lâu đời).
class VangTodayPriceAdapter implements PriceAdapter {
  static const _baseUrl = 'https://www.vang.today/api/prices';
  static const _timeout = Duration(seconds: 10);

  @override
  String get sourceKey => 'vang_today';

  @override
  String get displayName => 'vang.today';

  final http.Client _client;

  VangTodayPriceAdapter({http.Client? client})
      : _client = client ?? http.Client();

  /// Map mã loại vàng của vang.today → goldTypeId app đang track. Đủ toàn bộ
  /// mã domestic (VND/lượng) mà vang.today hỗ trợ — không gồm XAUUSD (giá
  /// vàng thế giới, USD/oz, khác hệ đơn vị).
  static const _typeCodeToGoldTypeId = {
    'SJL1L10': 'sjc',
    'SJ9999': 'ring_9999',
    'BT9999NTT': 'gold_9999',
    'DOJINHTV': 'jewelry',
    'VIETTINMSJC': 'viettin_sjc',
    'PQHNVM': 'pnj_hanoi',
    'PQHN24NTT': 'pnj_24k',
    'BTSJC': 'bao_tin_sjc',
    'DOHNL': 'doji_hanoi',
    'DOHCML': 'doji_hcm',
    'VNGSJC': 'vn_gold_sjc',
  };

  @override
  Future<List<GoldPrice>> fetchPrices() async {
    final res = await _client.get(Uri.parse(_baseUrl)).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('vang.today HTTP ${res.statusCode}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception('vang.today trả success=false');
    }

    final prices = (body['prices'] as Map?)?.cast<String, dynamic>() ?? {};
    final now = DateTime.now();
    final result = <GoldPrice>[];

    _typeCodeToGoldTypeId.forEach((code, goldTypeId) {
      final entry = prices[code] as Map<String, dynamic>?;
      if (entry == null) return;
      final buy = (entry['buy'] as num?)?.toDouble();
      final sell = (entry['sell'] as num?)?.toDouble();
      if (buy == null || sell == null || buy <= 0) return;
      result.add(GoldPrice(
        id: '${goldTypeId}_${now.millisecondsSinceEpoch}',
        goldTypeId: goldTypeId,
        buyPrice: buy,
        sellPrice: sell,
        source: sourceKey,
        updatedAt: now,
      ));
    });

    if (result.isEmpty) {
      throw Exception('vang.today không trả giá cho mã nào đang track');
    }
    return result;
  }

  @override
  Future<List<PriceHistoryEntry>> fetchPriceHistory(
    String goldTypeId, {
    int days = 30,
  }) async {
    final code = _typeCodeToGoldTypeId.entries
        .firstWhere(
          (e) => e.value == goldTypeId,
          orElse: () => const MapEntry('', ''),
        )
        .key;
    if (code.isEmpty) return const [];

    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl?type=$code&days=$days'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (body['success'] != true) return const [];

      final history = (body['history'] as List?) ?? const [];
      final entries = <PriceHistoryEntry>[];
      for (final item in history) {
        final map = item as Map<String, dynamic>;
        final date = DateTime.tryParse(map['date'] as String? ?? '');
        final priceData = (map['prices'] as Map?)?[code] as Map<String, dynamic>?;
        if (date == null || priceData == null) continue;
        final buy = (priceData['buy'] as num?)?.toDouble();
        final sell = (priceData['sell'] as num?)?.toDouble();
        if (buy == null || sell == null) continue;
        entries.add(PriceHistoryEntry(date: date, buyPrice: buy, sellPrice: sell));
      }
      // API trả mới → cũ; đảo lại để tăng dần theo thời gian.
      entries.sort((a, b) => a.date.compareTo(b.date));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> isAvailable() async {
    // Không probe thêm request — fetchPrices() throw thì PriceService tự
    // bắt và set status lỗi.
    return true;
  }
}
