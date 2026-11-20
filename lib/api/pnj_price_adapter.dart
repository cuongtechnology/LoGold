import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/gold_price.dart';
import 'price_adapter.dart';

/// PnjPriceAdapter — giá chính chủ từ API website PNJ (nguồn dự phòng).
///
/// **Endpoint**: `GET https://edge-api.pnj.io/ecom-frontend/v1/get-gold-price?zone=11`
/// (zone 11 = Hà Nội) → JSON `{chinhanh, updateDate, data: [{masp, tensp,
/// giamua, giaban}]}`. Bật CORS nên gọi được cả từ web build.
///
/// **Đơn vị**: PNJ trả **nghìn đồng/chỉ** → ×10.000 = VND/lượng. Một số dòng
/// (vàng nguyên liệu) có `giaban` là chuỗi rỗng — bỏ qua.
class PnjPriceAdapter implements PriceAdapter {
  static const _url =
      'https://edge-api.pnj.io/ecom-frontend/v1/get-gold-price?zone=11';
  static const _timeout = Duration(seconds: 10);
  static const _thousandPerChiToVndPerLuong = 10000;

  /// Mã sản phẩm PNJ → goldTypeId app đang track.
  static const _codeToGoldTypeId = {
    'SJC': 'pnj_hanoi', // vàng miếng SJC bán tại PNJ
    'N24K': 'pnj_24k', // nhẫn trơn PNJ 999.9
  };

  @override
  String get sourceKey => 'pnj';

  @override
  String get displayName => 'PNJ (chính chủ)';

  final http.Client _client;

  PnjPriceAdapter({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<GoldPrice>> fetchPrices() async {
    final res = await _client.get(Uri.parse(_url)).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('PNJ HTTP ${res.statusCode}');
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final rows = (json['data'] as List?) ?? const [];
    final now = DateTime.now();
    final result = <GoldPrice>[];

    for (final raw in rows.whereType<Map>()) {
      final goldTypeId = _codeToGoldTypeId[raw['masp']];
      if (goldTypeId == null) continue;
      final buy = raw['giamua'];
      final sell = raw['giaban'];
      if (buy is! num || sell is! num || buy <= 0 || sell <= 0) continue;
      result.add(GoldPrice(
        id: '${goldTypeId}_${now.millisecondsSinceEpoch}',
        goldTypeId: goldTypeId,
        buyPrice: buy.toDouble() * _thousandPerChiToVndPerLuong,
        sellPrice: sell.toDouble() * _thousandPerChiToVndPerLuong,
        source: sourceKey,
        updatedAt: now,
      ));
    }

    if (result.isEmpty) {
      throw Exception('PNJ không trả loại vàng nào đang track');
    }
    return result;
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
