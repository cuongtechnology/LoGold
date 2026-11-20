import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/gold_price.dart';
import 'price_adapter.dart';

/// CafefPriceAdapter — giá vàng miếng SJC niêm yết, lấy qua trang dữ liệu
/// của CafeF (nguồn dự phòng cho loại `sjc`).
///
/// **Vì sao không gọi thẳng SJC**: `sjc.com.vn` đứng sau Cloudflare chống
/// bot, trả HTTP 403 cho HTTP client của Dart; feed XML cũ
/// (`/xml/tygiavang.xml`) đã bị gỡ và trang `giavang.doji.vn` đã đóng.
///
/// **Endpoint**: `GET https://cafef.vn/du-lieu/Ajax/ajaxgoldpricehistory.ashx?index=1m`
/// → `{Data: {goldPriceWorldHistories: [{name: "SJC", buyPrice, sellPrice,
/// createdAt}, ...]}}`, mỗi ngày 1 dòng, mới nhất trước. Bật CORS nên chạy
/// được cả trên web. Đây là API nội bộ của trang CafeF, không có cam kết ổn
/// định — chỉ dùng làm dự phòng.
///
/// **Đơn vị**: triệu đồng/lượng → ×1.000.000 = VND/lượng.
class CafefPriceAdapter implements PriceAdapter {
  static const _url =
      'https://cafef.vn/du-lieu/Ajax/ajaxgoldpricehistory.ashx?index=1m';
  static const _timeout = Duration(seconds: 10);
  static const _millionToVnd = 1000000;

  /// Dòng mới nhất cũ hơn mức này thì coi như nguồn đã ngừng cập nhật.
  static const _maxAge = Duration(days: 4);

  @override
  String get sourceKey => 'cafef';

  @override
  String get displayName => 'SJC (qua CafeF)';

  final http.Client _client;
  final DateTime Function() _now;

  CafefPriceAdapter({http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  @override
  Future<List<GoldPrice>> fetchPrices() async {
    final res = await _client.get(Uri.parse(_url)).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('CafeF HTTP ${res.statusCode}');
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final rows = ((json['Data'] as Map?)?['goldPriceWorldHistories'] as List?) ??
        const [];
    final now = _now();

    for (final raw in rows.whereType<Map>()) {
      if (raw['name'] != 'SJC') continue;
      final buy = raw['buyPrice'];
      final sell = raw['sellPrice'];
      final createdAt = DateTime.tryParse(raw['createdAt'] as String? ?? '');
      if (buy is! num || sell is! num || buy <= 0 || sell <= 0) continue;
      if (createdAt == null || now.difference(createdAt) > _maxAge) break;
      return [
        GoldPrice(
          id: 'sjc_${now.millisecondsSinceEpoch}',
          goldTypeId: 'sjc',
          buyPrice: (buy * _millionToVnd).roundToDouble(),
          sellPrice: (sell * _millionToVnd).roundToDouble(),
          source: sourceKey,
          updatedAt: now,
        ),
      ];
    }
    throw Exception('CafeF không có giá SJC mới');
  }

  @override
  Future<List<PriceHistoryEntry>> fetchPriceHistory(
    String goldTypeId, {
    int days = 30,
  }) async =>
      const [];

  @override
  Future<bool> isAvailable() async => true;
}
