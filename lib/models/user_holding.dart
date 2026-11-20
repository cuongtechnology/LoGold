/// UserHolding model - represents a single gold purchase entry by the user.
/// This is the core data model for tracking gold investments.
class UserHolding {
  final String id;
  final String goldTypeId; // references GoldType.id
  final double quantity; // quantity in the original unit
  final String unit; // "luong", "chi", "gram"
  final double quantityInLuong; // normalized to luong for calculations
  final double buyPricePerLuong; // buy price per luong (VND)
  final double totalCost; // total cost = buyPrice * quantity + fee
  final double fee; // additional fees
  final DateTime buyDate;
  final String? note;
  final String? invoiceImageUri;
  final String status; // "holding" or "sold"
  // Thông tin bán — chỉ có khi đã ghi nhận giao dịch bán. Holding cũ đã
  // 'sold' từ trước khi có các trường này sẽ để null.
  final double? sellPricePerLuong; // giá bán thực tế / lượng (VND)
  final DateTime? sellDate;
  final double? sellFee; // phí phát sinh khi bán (VND)
  final DateTime createdAt;
  final DateTime updatedAt;

  UserHolding({
    required this.id,
    required this.goldTypeId,
    required this.quantity,
    required this.unit,
    required this.quantityInLuong,
    required this.buyPricePerLuong,
    required this.totalCost,
    this.fee = 0,
    required this.buyDate,
    this.note,
    this.invoiceImageUri,
    this.status = 'holding',
    this.sellPricePerLuong,
    this.sellDate,
    this.sellFee,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Đã chốt bán và có ghi giá bán (đủ để tính lãi/lỗ thực hiện).
  bool get hasSellPrice => status == 'sold' && sellPricePerLuong != null;

  /// Create a copy with updated fields.
  /// [clearSale] = true sẽ xoá toàn bộ thông tin bán (dùng khi hoàn tác bán).
  UserHolding copyWith({
    String? id,
    String? goldTypeId,
    double? quantity,
    String? unit,
    double? quantityInLuong,
    double? buyPricePerLuong,
    double? totalCost,
    double? fee,
    DateTime? buyDate,
    String? note,
    String? invoiceImageUri,
    String? status,
    double? sellPricePerLuong,
    DateTime? sellDate,
    double? sellFee,
    bool clearSale = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserHolding(
      id: id ?? this.id,
      goldTypeId: goldTypeId ?? this.goldTypeId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      quantityInLuong: quantityInLuong ?? this.quantityInLuong,
      buyPricePerLuong: buyPricePerLuong ?? this.buyPricePerLuong,
      totalCost: totalCost ?? this.totalCost,
      fee: fee ?? this.fee,
      buyDate: buyDate ?? this.buyDate,
      note: note ?? this.note,
      invoiceImageUri: invoiceImageUri ?? this.invoiceImageUri,
      status: status ?? this.status,
      sellPricePerLuong:
          clearSale ? null : (sellPricePerLuong ?? this.sellPricePerLuong),
      sellDate: clearSale ? null : (sellDate ?? this.sellDate),
      sellFee: clearSale ? null : (sellFee ?? this.sellFee),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goldTypeId': goldTypeId,
      'quantity': quantity,
      'unit': unit,
      'quantityInLuong': quantityInLuong,
      'buyPricePerLuong': buyPricePerLuong,
      'totalCost': totalCost,
      'fee': fee,
      'buyDate': buyDate.toIso8601String(),
      'note': note,
      'invoiceImageUri': invoiceImageUri,
      'status': status,
      'sellPricePerLuong': sellPricePerLuong,
      'sellDate': sellDate?.toIso8601String(),
      'sellFee': sellFee,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserHolding.fromMap(Map<String, dynamic> map) {
    return UserHolding(
      id: map['id'] as String,
      goldTypeId: map['goldTypeId'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      quantityInLuong: (map['quantityInLuong'] as num).toDouble(),
      buyPricePerLuong: (map['buyPricePerLuong'] as num).toDouble(),
      totalCost: (map['totalCost'] as num).toDouble(),
      fee: (map['fee'] as num?)?.toDouble() ?? 0,
      buyDate: DateTime.parse(map['buyDate'] as String),
      note: map['note'] as String?,
      invoiceImageUri: map['invoiceImageUri'] as String?,
      status: map['status'] as String? ?? 'holding',
      sellPricePerLuong: (map['sellPricePerLuong'] as num?)?.toDouble(),
      sellDate: map['sellDate'] == null
          ? null
          : DateTime.parse(map['sellDate'] as String),
      sellFee: (map['sellFee'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
