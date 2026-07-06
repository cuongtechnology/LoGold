import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/gold_price.dart';
import 'price_adapter.dart';

/// CloudflareWorkerPriceAdapter — fetch giá vàng qua CF Worker proxy.
///
/// Endpoint: `<workerBaseUrl>/prices` → JSON bundle
/// `{ prices: [...], fetchedAt: ..., upstream: ... }` (xem `worker/src/index.ts`).
///
/// Dùng adapter này cho **cả web + mobile** khi Worker đã deploy:
/// - Web: thoát CORS (Worker set `Access-Control-Allow-Origin: *`).
/// - Mobile: giảm hit trực tiếp SJC → tránh Cloudflare challenge, tiết kiệm
///   pin/data user, và mọi user share cùng cache 5 phút.
class CloudflareWorkerPriceAdapter implements PriceAdapter {
  final String baseUrl;
  final http.Client _client;

  CloudflareWorkerPriceAdapter({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get sourceKey => 'cf_worker';

  @override
  String get displayName => 'Nguồn giá qua CF Worker';

  @override
  Future<List<GoldPrice>> fetchPrices() async {
    final uri = Uri.parse('$baseUrl/prices');
    final res = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('CF Worker HTTP ${res.statusCode}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final list = (body['prices'] as List?) ?? const [];
    return list.map((raw) {
      final m = raw as Map<String, dynamic>;
      final updatedAt = DateTime.tryParse(m['updatedAt'] as String? ?? '') ??
          DateTime.now();
      return GoldPrice(
        id: '${m['goldTypeId']}_${updatedAt.millisecondsSinceEpoch}',
        goldTypeId: m['goldTypeId'] as String,
        buyPrice: (m['buyPrice'] as num).toDouble(),
        sellPrice: (m['sellPrice'] as num).toDouble(),
        source: m['source'] as String? ?? sourceKey,
        updatedAt: updatedAt,
      );
    }).toList();
  }

  @override
  Future<List<PriceHistoryEntry>> fetchPriceHistory(
    String goldTypeId, {
    int days = 30,
  }) async {
    // Chưa có endpoint history — Worker chỉ cache snapshot hiện tại.
    // Sau này thêm KV list `prices:snap:<timestamp>` rồi expose `/history`.
    return const [];
  }

  @override
  Future<bool> isAvailable() async {
    return baseUrl.isNotEmpty;
  }
}
