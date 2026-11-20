/// Price Alert model - user-configured alerts for gold price movements.
class PriceAlert {
  final String id;
  final PriceAlertType type;
  final String? goldTypeId; // null = applies to all tracked gold types
  final double? targetPrice; // giá mục tiêu (đ/lượng) — so với giá tiệm thu mua
  final PriceAlertDirection direction; // chỉ dùng cho priceTarget
  final double? targetProfitLoss; // target profit/loss in VND
  final bool enabled;
  final DateTime createdAt;

  /// Điều kiện đã đúng ở lần kiểm tra trước (đã báo). Alert chỉ báo lại sau
  /// khi điều kiện sai trở lại (edge-triggered) — persist để restart app
  /// không báo lại.
  final bool triggered;

  PriceAlert({
    required this.id,
    required this.type,
    this.goldTypeId,
    this.targetPrice,
    this.direction = PriceAlertDirection.above,
    this.targetProfitLoss,
    this.enabled = true,
    required this.createdAt,
    this.triggered = false,
  });

  PriceAlert copyWith({
    String? id,
    PriceAlertType? type,
    String? goldTypeId,
    double? targetPrice,
    PriceAlertDirection? direction,
    double? targetProfitLoss,
    bool? enabled,
    DateTime? createdAt,
    bool? triggered,
  }) {
    return PriceAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      goldTypeId: goldTypeId ?? this.goldTypeId,
      targetPrice: targetPrice ?? this.targetPrice,
      direction: direction ?? this.direction,
      targetProfitLoss: targetProfitLoss ?? this.targetProfitLoss,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      triggered: triggered ?? this.triggered,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'goldTypeId': goldTypeId,
      'targetPrice': targetPrice,
      'direction': direction.name,
      'targetProfitLoss': targetProfitLoss,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'triggered': triggered,
    };
  }

  factory PriceAlert.fromMap(Map<String, dynamic> map) {
    return PriceAlert(
      id: map['id'] as String,
      type: PriceAlertType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PriceAlertType.priceTarget,
      ),
      goldTypeId: map['goldTypeId'] as String?,
      targetPrice: (map['targetPrice'] as num?)?.toDouble(),
      // Alert cũ chưa có field này → mặc định "chạm hoặc vượt mục tiêu".
      direction: PriceAlertDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => PriceAlertDirection.above,
      ),
      targetProfitLoss: (map['targetProfitLoss'] as num?)?.toDouble(),
      enabled: map['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      triggered: map['triggered'] as bool? ?? false,
    );
  }

  /// Returns a user-friendly description of this alert
  String get description {
    switch (type) {
      case PriceAlertType.breakeven:
        return 'Báo khi về bờ (hòa vốn)';
      case PriceAlertType.lossThreshold:
        return 'Báo khi lỗ vượt ${_formatVnd(targetProfitLoss)}';
      case PriceAlertType.profitThreshold:
        return 'Báo khi lãi vượt ${_formatVnd(targetProfitLoss)}';
      case PriceAlertType.priceTarget:
        final verb = direction == PriceAlertDirection.above ? 'lên tới' : 'xuống tới';
        return 'Báo khi giá tiệm thu mua $verb ${_formatVnd(targetPrice)}/lượng';
      case PriceAlertType.priceSurge:
        return 'Báo khi giá tăng/giảm mạnh';
    }
  }

  String _formatVnd(double? value) {
    if (value == null) return '---';
    return '${value.round().abs().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        )}đ';
  }
}

enum PriceAlertType {
  breakeven, // alert when breaking even
  lossThreshold, // alert when loss exceeds threshold
  profitThreshold, // alert when profit exceeds threshold
  priceTarget, // alert when shop buy price (giá thu mua) reaches a target
  priceSurge, // alert when price changes significantly
}

/// Hướng của cảnh báo giá mục tiêu.
enum PriceAlertDirection {
  above, // báo khi giá >= mục tiêu
  below, // báo khi giá <= mục tiêu
}
