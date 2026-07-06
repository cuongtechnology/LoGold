import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/gold_price.dart';
import 'price_adapter.dart';

/// SjcPriceAdapter — fetch giá vàng thật cho user Việt Nam.
///
/// **Nguồn**:
/// 1. Primary: `https://sjc.com.vn/xml/tygiavang.xml` (XML feed chính chủ).
///    → Có thể bị Cloudflare challenge chặn khi client fetch trực tiếp (đặc biệt
///    web browser hoặc datacenter IP). Mobile app trên carrier IP thường OK.
/// 2. Fallback: `https://giavang.doji.vn` scrape HTML.
///    → DOJI page hiển thị **bảng giá cả SJC**, ring 9999, jewelry — đủ 4 loại
///    app đang track. Ổn định hơn SJC XML.
///
/// **Khi nào không dùng adapter này**:
/// - Web build (CORS chặn cả 2 endpoint) → dùng `CloudflareWorkerPriceAdapter`
///   proxy qua CF Worker (xem `../worker/worker.ts`).
///
/// **Đơn vị chuẩn hoá**: giá trong app dùng VND/lượng. SJC trả VND/lượng sẵn;
/// DOJI trả "nghìn/chỉ" → nhân 1000 × 10 = VND/lượng.
class SjcPriceAdapter implements PriceAdapter {
  static const _sjcXmlUrl = 'https://sjc.com.vn/xml/tygiavang.xml';
  static const _dojiHtmlUrl = 'https://giavang.doji.vn';
  static const _timeout = Duration(seconds: 12);
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Lo-app/1.0';

  @override
  String get sourceKey => 'sjc';

  @override
  String get displayName => 'SJC + DOJI (nguồn chính thức)';

  final http.Client _client;

  SjcPriceAdapter({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<GoldPrice>> fetchPrices() async {
    // Thử SJC XML trước.
    try {
      final prices = await _fetchFromSjcXml();
      if (prices.isNotEmpty) return prices;
    } catch (_) {
      // Rơi xuống fallback DOJI.
    }
    return _fetchFromDojiHtml();
  }

  Future<List<GoldPrice>> _fetchFromSjcXml() async {
    final res = await _client
        .get(Uri.parse(_sjcXmlUrl), headers: {'User-Agent': _userAgent})
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw HttpException('SJC XML HTTP ${res.statusCode}');
    }
    // Cloudflare challenge trả HTML thay vì XML — detect và bỏ.
    final body = utf8.decode(res.bodyBytes);
    if (body.trimLeft().startsWith('<!DOCTYPE') ||
        body.contains('Just a moment')) {
      throw HttpException('SJC XML bị Cloudflare challenge');
    }

    final doc = XmlDocument.parse(body);
    final now = DateTime.now();
    final byGoldType = <String, _RawPrice>{};

    // Format SJC XML thay đổi theo thời gian; support cả 2 shape phổ biến:
    //   <row buy="..." sell="..." type_name="..."/>
    //   <Row><BuyPrice/><SellPrice/><TenLoai/></Row>
    for (final row in doc.descendants.whereType<XmlElement>()) {
      final name = row.name.local.toLowerCase();
      if (name != 'row') continue;

      final label = (row.getAttribute('type_name') ??
              row.getAttribute('TypeName') ??
              _childText(row, ['TenLoai', 'tenloai', 'type', 'Type']) ??
              '')
          .trim();
      final buyStr = row.getAttribute('buy') ??
          row.getAttribute('BuyPrice') ??
          _childText(row, ['BuyPrice', 'buy']);
      final sellStr = row.getAttribute('sell') ??
          row.getAttribute('SellPrice') ??
          _childText(row, ['SellPrice', 'sell']);

      final buy = _parseVnd(buyStr);
      final sell = _parseVnd(sellStr);
      if (buy == null || sell == null || label.isEmpty) continue;

      final goldTypeId = _mapLabelToGoldTypeId(label);
      if (goldTypeId == null) continue;

      // SJC trả VND/lượng — không cần scale.
      byGoldType.putIfAbsent(
        goldTypeId,
        () => _RawPrice(buy: buy, sell: sell),
      );
    }

    return byGoldType.entries
        .map((e) => GoldPrice(
              id: '${e.key}_${now.millisecondsSinceEpoch}',
              goldTypeId: e.key,
              buyPrice: e.value.buy,
              sellPrice: e.value.sell,
              source: sourceKey,
              updatedAt: now,
            ))
        .toList();
  }

  Future<List<GoldPrice>> _fetchFromDojiHtml() async {
    final res = await _client
        .get(Uri.parse(_dojiHtmlUrl), headers: {'User-Agent': _userAgent})
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw HttpException('DOJI HTML HTTP ${res.statusCode}');
    }
    final html = utf8.decode(res.bodyBytes);

    // DOJI có 2 bảng: bảng HCM (rows dạng span/div, có "nghìn/chỉ" note) và
    // bảng Hà Nội (rows tối giản `<td class="label">NAME</td><td>BUY</td><td>SELL</td>`).
    // Bảng Hà Nội format ổn định và dễ parse hơn.
    //
    // Ví dụ row: `<td class="label">SJC - Bán Lẻ</td><td>14800</td><td>15100</td>`
    // Giá trong bảng đơn vị **nghìn/chỉ** — nhân 10_000 = VND/lượng.
    final rowRegex = RegExp(
      r'<td class="label">\s*(.*?)\s*</td>\s*<td>\s*([\d,\.]+)\s*</td>\s*<td>\s*([\d,\.]+)\s*</td>',
      caseSensitive: false,
      dotAll: true,
    );

    final now = DateTime.now();
    final byGoldType = <String, _RawPrice>{};

    for (final m in rowRegex.allMatches(html)) {
      final label = m.group(1)!.trim();
      final buyThousandPerChi = _parseVnd(m.group(2));
      final sellThousandPerChi = _parseVnd(m.group(3));
      if (buyThousandPerChi == null || sellThousandPerChi == null) continue;

      final goldTypeId = _mapLabelToGoldTypeId(label);
      if (goldTypeId == null) continue;

      // nghìn/chỉ → VND/lượng: ×1000 (nghìn→VND) ×10 (chỉ→lượng) = ×10_000.
      final buy = buyThousandPerChi * 10000;
      final sell = sellThousandPerChi * 10000;

      byGoldType.putIfAbsent(
        goldTypeId,
        () => _RawPrice(buy: buy, sell: sell),
      );
    }

    if (byGoldType.isEmpty) {
      throw HttpException('Không parse được row nào từ DOJI HTML');
    }

    return byGoldType.entries
        .map((e) => GoldPrice(
              id: '${e.key}_${now.millisecondsSinceEpoch}',
              goldTypeId: e.key,
              buyPrice: e.value.buy,
              sellPrice: e.value.sell,
              source: 'doji_scrape',
              updatedAt: now,
            ))
        .toList();
  }

  @override
  Future<List<PriceHistoryEntry>> fetchPriceHistory(
    String goldTypeId, {
    int days = 30,
  }) async {
    // SJC/DOJI không expose lịch sử qua endpoint public — trả rỗng.
    // Muốn có history: cache mỗi lần fetchPrices vào Hive priceHistoryBox.
    return const [];
  }

  @override
  Future<bool> isAvailable() async {
    // Không probe endpoint (tốn 1 request thêm). Trả true; fetchPrices sẽ
    // throw nếu cả 2 nguồn đều fail — PriceService bắt được và set status error.
    return true;
  }

  static String? _childText(XmlElement el, List<String> names) {
    for (final n in names) {
      final child = el.findElements(n).firstOrNull;
      if (child != null) return child.innerText;
    }
    return null;
  }

  /// Parse chuỗi số có dấu phẩy/chấm phân cách nghìn thành double.
  /// Trả null nếu không parse được.
  static double? _parseVnd(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[,\.\s]'), '');
    return double.tryParse(cleaned);
  }

  /// Map nhãn tiếng Việt của SJC/DOJI về `goldTypeId` app đang track.
  /// Trả null nếu không match loại nào — bỏ row.
  static String? _mapLabelToGoldTypeId(String label) {
    final lower = label.toLowerCase();

    // SJC vàng miếng
    if (lower.contains('sjc')) return 'sjc';

    // Nhẫn tròn 9999 (DOJI: "NHẪN TRÒN 9999 HƯNG THỊNH VƯỢNG")
    if (lower.contains('nhẫn') || lower.contains('nhan')) {
      return 'ring_9999';
    }

    // Nguyên liệu 9999 / AVPL / Kim TT (vàng nguyên liệu 4 số 9)
    if (lower.contains('nguyên liệu') ||
        lower.contains('nguyen lieu') ||
        lower.contains('avpl') ||
        lower.contains('kim tt')) {
      return 'gold_9999';
    }

    // Nữ trang / jewelry
    if (lower.contains('nữ trang') ||
        lower.contains('nu trang') ||
        lower.contains('trang sức')) {
      return 'jewelry';
    }

    return null;
  }
}

class _RawPrice {
  final double buy;
  final double sell;
  const _RawPrice({required this.buy, required this.sell});
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}
