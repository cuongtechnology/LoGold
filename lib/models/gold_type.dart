/// Gold Type model - represents different types of gold in the Vietnamese market.
/// Examples: SJC bars, 9999 ring gold, jewelry gold, custom types.
class GoldType {
  final String id;
  final String name; // Internal key e.g. "sjc", "ring_9999"
  final String displayName; // UI display name e.g. "Vàng miếng SJC"
  final String defaultUnit; // "luong", "chi", "gram"
  final String sourceKey; // which price source to use
  final bool isCustom;

  GoldType({
    required this.id,
    required this.name,
    required this.displayName,
    required this.defaultUnit,
    required this.sourceKey,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'defaultUnit': defaultUnit,
      'sourceKey': sourceKey,
      'isCustom': isCustom,
    };
  }

  factory GoldType.fromMap(Map<String, dynamic> map) {
    return GoldType(
      id: map['id'] as String,
      name: map['name'] as String,
      displayName: map['displayName'] as String,
      defaultUnit: map['defaultUnit'] as String? ?? 'luong',
      sourceKey: map['sourceKey'] as String? ?? 'mock',
      isCustom: map['isCustom'] as bool? ?? false,
    );
  }

  /// Predefined gold types in the Vietnamese market — khớp các mã loại vàng
  /// domestic mà `VangTodayPriceAdapter` fetch được (xem mapping trong
  /// `lib/api/vang_today_price_adapter.dart`). Không gồm XAUUSD (giá vàng thế
  /// giới, USD/oz) vì khác hệ đơn vị VND/lượng mà app dùng để tính lãi/lỗ.
  static List<GoldType> get defaults => [
        GoldType(
          id: 'sjc',
          name: 'sjc',
          displayName: 'Vàng miếng SJC',
          defaultUnit: 'luong',
          sourceKey: 'sjc',
        ),
        GoldType(
          id: 'ring_9999',
          name: 'ring_9999',
          displayName: 'Nhẫn SJC 9999',
          defaultUnit: 'chi',
          sourceKey: 'ring_9999',
        ),
        GoldType(
          id: 'gold_9999',
          name: 'gold_9999',
          displayName: 'Bảo Tín 9999',
          defaultUnit: 'luong',
          sourceKey: 'gold_9999',
        ),
        GoldType(
          id: 'jewelry',
          name: 'jewelry',
          displayName: 'DOJI Nữ trang',
          defaultUnit: 'gram',
          sourceKey: 'jewelry',
        ),
        GoldType(
          id: 'viettin_sjc',
          name: 'viettin_sjc',
          displayName: 'Viettin SJC',
          defaultUnit: 'luong',
          sourceKey: 'viettin_sjc',
        ),
        GoldType(
          id: 'pnj_hanoi',
          name: 'pnj_hanoi',
          displayName: 'PNJ Hà Nội',
          defaultUnit: 'luong',
          sourceKey: 'pnj_hanoi',
        ),
        GoldType(
          id: 'pnj_24k',
          name: 'pnj_24k',
          displayName: 'PNJ 24K',
          defaultUnit: 'gram',
          sourceKey: 'pnj_24k',
        ),
        GoldType(
          id: 'bao_tin_sjc',
          name: 'bao_tin_sjc',
          displayName: 'Bảo Tín SJC',
          defaultUnit: 'luong',
          sourceKey: 'bao_tin_sjc',
        ),
        GoldType(
          id: 'doji_hanoi',
          name: 'doji_hanoi',
          displayName: 'DOJI Hà Nội',
          defaultUnit: 'luong',
          sourceKey: 'doji_hanoi',
        ),
        GoldType(
          id: 'doji_hcm',
          name: 'doji_hcm',
          displayName: 'DOJI TP.HCM',
          defaultUnit: 'luong',
          sourceKey: 'doji_hcm',
        ),
        GoldType(
          id: 'vn_gold_sjc',
          name: 'vn_gold_sjc',
          displayName: 'VN Gold SJC',
          defaultUnit: 'luong',
          sourceKey: 'vn_gold_sjc',
        ),
      ];
}
