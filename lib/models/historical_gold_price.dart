/// Điểm giá SJC lịch sử theo ngày (nguồn giavang.org, xem
/// `HistoricalPriceService` + repo `cuongmediatn/LoGold`).
///
/// `buyPrice`/`sellPrice` luôn ở đơn vị **VND/lượng** (khớp convention chung
/// của app) — dữ liệu gốc từ nguồn là nghìn đồng/lượng nên `fromJson` nhân
/// 1000 khi parse; `fromMap`/`toMap` (cache local) đã ở VND/lượng nên không
/// nhân lại.
class HistoricalPricePoint {
  final DateTime date;
  final double buyPrice;
  final double sellPrice;

  HistoricalPricePoint({
    required this.date,
    required this.buyPrice,
    required this.sellPrice,
  });

  /// Parse 1 phần tử trong `series` của `sjc_history.json`: `{"d","buy","sell"}`.
  factory HistoricalPricePoint.fromJson(Map<String, dynamic> json) {
    return HistoricalPricePoint(
      date: DateTime.parse(json['d'] as String),
      buyPrice: (json['buy'] as num).toDouble() * 1000,
      sellPrice: (json['sell'] as num).toDouble() * 1000,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'buyPrice': buyPrice,
      'sellPrice': sellPrice,
    };
  }

  factory HistoricalPricePoint.fromMap(Map<String, dynamic> map) {
    return HistoricalPricePoint(
      date: DateTime.parse(map['date'] as String),
      buyPrice: (map['buyPrice'] as num).toDouble(),
      sellPrice: (map['sellPrice'] as num).toDouble(),
    );
  }
}
