import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../api/vang_today_price_adapter.dart';
import '../models/historical_gold_price.dart';
import 'storage_service.dart';

/// HistoricalPriceService — lấy & cache series giá lịch sử (2009 → nay) theo
/// từng loại vàng (`goldTypeId`), dùng cho Bảng giá (lọc theo ngày) và phân
/// tích/so sánh + meme "so với quá khứ".
///
/// **Nguồn baseline** (chỉ 1 số loại có, xem [_baselineFileByGoldType] —
/// thử theo thứ tự, URL sau chỉ dùng khi URL trước lỗi):
/// 1. jsDelivr CDN trỏ vào repo `cuongmediatn/LoGold` — repo này chạy
///    GitHub Action cào lại `giavang.org` mỗi ngày (xem `scripts/scrape_*.py`
///    trong repo đó).
/// 2. `https://gold.cuong.io.vn/<file>` — bản mirror trực tiếp.
///
/// **Baseline offline** (chỉ SJC): cache Hive (`priceHistoryBox`) từ lần
/// fetch remote thành công gần nhất; nếu chưa từng fetch được thì dùng JSON
/// đóng gói sẵn trong app (`assets/data/sjc_history.json`).
///
/// **Backfill**: mọi loại vàng (kể cả loại không có baseline) đều thử bù
/// thêm dữ liệu gần đây từ `VangTodayPriceAdapter` (server này chỉ ghi lịch
/// sử từ ~23/11/2025). Loại nào không có baseline thì chuỗi lịch sử sẽ chỉ
/// bắt đầu từ đó.
class HistoricalPriceService {
  static HistoricalPriceService? _instance;
  static HistoricalPriceService get instance =>
      _instance ??= HistoricalPriceService._();

  HistoricalPriceService._();

  static const _jsDelivrBase =
      'https://cdn.jsdelivr.net/gh/cuongmediatn/LoGold@main';
  static const _mirrorBase = 'https://gold.cuong.io.vn';
  static const _timeout = Duration(seconds: 12);
  static const _backfillDays = 400; // vang.today thực tế chỉ giữ ~228 ngày.

  /// goldTypeId → tên file JSON baseline trên data repo. Loại không có trong
  /// map này chỉ dựa vào backfill (không có baseline dài hạn).
  static const _baselineFileByGoldType = {
    'sjc': 'sjc_history.json',
    'ring_9999': 'ring_9999_history.json',
    'jewelry': 'jewelry_history.json',
    'pnj_hanoi': 'pnj_hanoi_history.json',
    'pnj_24k': 'pnj_24k_history.json',
  };

  /// Chỉ SJC có JSON đóng gói sẵn trong app làm fallback offline lần đầu.
  static const _assetPathByGoldType = {
    'sjc': 'assets/data/sjc_history.json',
  };

  final http.Client _client = http.Client();
  final VangTodayPriceAdapter _vangToday = VangTodayPriceAdapter();

  final Map<String, List<HistoricalPricePoint>> _seriesByType = {};
  final Map<String, bool> _loadedByType = {};
  final Map<String, String> _statusByType = {};

  /// Series đã tải cho [goldTypeId] (rỗng nếu chưa `load()` hoặc không có dữ liệu).
  List<HistoricalPricePoint> seriesFor(String goldTypeId) =>
      _seriesByType[goldTypeId] ?? const [];

  String statusMessageFor(String goldTypeId) =>
      _statusByType[goldTypeId] ?? '';

  /// Tải series lịch sử cho 1 [goldTypeId]. An toàn gọi nhiều lần/song song
  /// cho nhiều loại khác nhau. `forceRefresh: true` để bỏ qua cache
  /// trong-memory và fetch lại remote + backfill.
  Future<List<HistoricalPricePoint>> load(
    String goldTypeId, {
    bool forceRefresh = false,
  }) async {
    if (_loadedByType[goldTypeId] == true && !forceRefresh) {
      return seriesFor(goldTypeId);
    }

    var series = _seriesByType[goldTypeId] ?? const <HistoricalPricePoint>[];
    if (series.isEmpty) {
      final cached = _readCache(goldTypeId);
      series =
          cached.isNotEmpty ? cached : await _loadBundledAsset(goldTypeId);
    }

    final remote = await _fetchRemoteBaseline(goldTypeId);
    if (remote.isNotEmpty) series = remote;

    final backfill = await _fetchBackfill(goldTypeId);
    if (backfill.isNotEmpty) series = _mergeSeries(series, backfill);

    _seriesByType[goldTypeId] = series;
    if (series.isNotEmpty) {
      try {
        await _writeCache(goldTypeId, series);
      } catch (_) {
        // Ghi cache lỗi không nên chặn việc trả dữ liệu vừa có.
      }
    }

    _statusByType[goldTypeId] = _composeStatusMessage(
      remoteOk: remote.isNotEmpty,
      backfillOk: backfill.isNotEmpty,
      hasData: series.isNotEmpty,
    );
    _loadedByType[goldTypeId] = true;
    return series;
  }

  String _composeStatusMessage({
    required bool remoteOk,
    required bool backfillOk,
    required bool hasData,
  }) {
    if (remoteOk && backfillOk) {
      return 'Đã cập nhật từ máy chủ + bù dữ liệu gần đây';
    }
    if (remoteOk) return 'Đã cập nhật từ máy chủ';
    if (backfillOk) {
      return 'Dùng dữ liệu đã lưu, đã bù thêm dữ liệu gần đây';
    }
    return hasData
        ? 'Dùng dữ liệu lịch sử đã lưu (chưa cập nhật được bản mới)'
        : 'Không có dữ liệu lịch sử cho loại này';
  }

  /// Bù dữ liệu gần đây từ `vang.today` — áp dụng cho MỌI loại vàng
  /// (`VangTodayPriceAdapter` map đủ 11 mã), không chỉ loại có baseline.
  Future<List<HistoricalPricePoint>> _fetchBackfill(String goldTypeId) async {
    try {
      final entries = await _vangToday.fetchPriceHistory(
        goldTypeId,
        days: _backfillDays,
      );
      return entries
          .map((e) => HistoricalPricePoint(
                date: e.date,
                buyPrice: e.buyPrice,
                sellPrice: e.sellPrice,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Gộp [base] (baseline giavang.org, nếu có) với [backfill] (vang.today),
  /// khử trùng theo ngày — ngày trùng thì ưu tiên bản backfill (gần thời
  /// gian thực hơn).
  List<HistoricalPricePoint> _mergeSeries(
    List<HistoricalPricePoint> base,
    List<HistoricalPricePoint> backfill,
  ) {
    if (backfill.isEmpty) return base;
    final byDate = <DateTime, HistoricalPricePoint>{
      for (final p in base) p.date: p,
    };
    for (final p in backfill) {
      byDate[p.date] = p;
    }
    final merged = byDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return merged;
  }

  Future<List<HistoricalPricePoint>> _fetchRemoteBaseline(
    String goldTypeId,
  ) async {
    final filename = _baselineFileByGoldType[goldTypeId];
    if (filename == null) return const [];

    for (final base in [_jsDelivrBase, _mirrorBase]) {
      try {
        final res = await _client
            .get(Uri.parse('$base/$filename'))
            .timeout(_timeout);
        if (res.statusCode != 200) continue;

        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final rawSeries = (body['series'] as List?) ?? const [];
        final points = rawSeries
            .map((e) => HistoricalPricePoint.fromJson(e as Map<String, dynamic>))
            .toList();
        if (points.isNotEmpty) return points;
      } catch (_) {
        // Thử URL kế tiếp.
      }
    }
    return const [];
  }

  Future<List<HistoricalPricePoint>> _loadBundledAsset(
    String goldTypeId,
  ) async {
    final assetPath = _assetPathByGoldType[goldTypeId];
    if (assetPath == null) return const [];
    try {
      final raw = await rootBundle.loadString(assetPath);
      final body = jsonDecode(raw) as Map<String, dynamic>;
      final rawSeries = (body['series'] as List?) ?? const [];
      return rawSeries
          .map((e) => HistoricalPricePoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<HistoricalPricePoint> _readCache(String goldTypeId) {
    try {
      final raw = StorageService.priceHistory.get(_cacheKey(goldTypeId));
      if (raw == null) return const [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => HistoricalPricePoint.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeCache(
    String goldTypeId,
    List<HistoricalPricePoint> points,
  ) async {
    final raw = jsonEncode(points.map((p) => p.toMap()).toList());
    await StorageService.priceHistory.put(_cacheKey(goldTypeId), raw);
  }

  String _cacheKey(String goldTypeId) => 'history_cache_$goldTypeId';
}
