import '../models/price_alert.dart';

/// Dữ liệu đầu vào để đánh giá alert — gom lại để hàm đánh giá thuần (pure),
/// test được mà không cần Hive/PriceService.
class AlertContext {
  final double totalProfitLoss;
  final bool hasHoldings;

  /// goldTypeId -> giá tiệm thu mua (đ/lượng) hiện tại.
  final Map<String, double> buyPrices;

  /// goldTypeId -> chênh lệch giá thu mua so với lần trước (đ/lượng).
  final Map<String, double> priceChanges;

  const AlertContext({
    required this.totalProfitLoss,
    required this.hasHoldings,
    this.buyPrices = const {},
    this.priceChanges = const {},
  });
}

/// Kết quả đánh giá 1 alert.
class AlertDecision {
  /// Có cần báo ngay lúc này không.
  final bool fire;

  /// Giá trị `triggered` mới cần lưu lại cho alert.
  final bool triggered;

  final String title;
  final String body;

  const AlertDecision({
    required this.fire,
    required this.triggered,
    this.title = '',
    this.body = '',
  });
}

/// Ngưỡng biến động giá (đ/lượng) để coi là "biến động mạnh".
const double kPriceSurgeThreshold = 1000000;

/// Ngưỡng hòa vốn: 0 ≤ lãi/lỗ < 100.000đ.
const double kBreakevenBand = 100000;

/// Điều kiện của alert đang đúng (true), sai (false) hay chưa đánh giá được
/// (null — vd: chưa có giá của loại vàng đó; khi đó giữ nguyên trạng thái).
bool? isAlertConditionMet(PriceAlert alert, AlertContext ctx) {
  switch (alert.type) {
    case PriceAlertType.breakeven:
      // Chưa có vị thế thì P/L = 0 không có nghĩa là "về bờ".
      if (!ctx.hasHoldings) return false;
      return ctx.totalProfitLoss >= 0 && ctx.totalProfitLoss < kBreakevenBand;

    case PriceAlertType.lossThreshold:
      final t = alert.targetProfitLoss;
      if (t == null || t == 0) return null;
      return ctx.totalProfitLoss <= -t.abs();

    case PriceAlertType.profitThreshold:
      final t = alert.targetProfitLoss;
      if (t == null || t == 0) return null;
      return ctx.totalProfitLoss >= t.abs();

    case PriceAlertType.priceTarget:
      final id = alert.goldTypeId;
      final target = alert.targetPrice;
      if (id == null || target == null) return null;
      final price = ctx.buyPrices[id];
      if (price == null) return null;
      return alert.direction == PriceAlertDirection.above
          ? price >= target
          : price <= target;

    case PriceAlertType.priceSurge:
      if (ctx.priceChanges.isEmpty) return null;
      final Iterable<double> changes = alert.goldTypeId != null
          ? [ctx.priceChanges[alert.goldTypeId]].whereType<double>()
          : ctx.priceChanges.values;
      return changes.any((c) => c.abs() > kPriceSurgeThreshold);
  }
}

/// Quyết định có báo alert hay không (edge-triggered): chỉ báo khi điều kiện
/// chuyển từ sai → đúng; chỉ được báo lại sau khi điều kiện đã sai trở lại.
/// [formatVnd] để message có định dạng tiền tệ mà không phụ thuộc UI.
AlertDecision evaluateAlert(
  PriceAlert alert,
  AlertContext ctx, {
  String Function(double)? formatVnd,
  String? goldTypeName,
}) {
  final fmt = formatVnd ?? (v) => v.round().toString();
  if (!alert.enabled) {
    return AlertDecision(fire: false, triggered: alert.triggered);
  }

  final met = isAlertConditionMet(alert, ctx);
  if (met == null) {
    return AlertDecision(fire: false, triggered: alert.triggered);
  }
  if (!met) return const AlertDecision(fire: false, triggered: false);
  if (alert.triggered) return const AlertDecision(fire: false, triggered: true);

  late String title;
  late String body;
  switch (alert.type) {
    case PriceAlertType.breakeven:
      title = 'Tin vui: Bạn sắp nhìn thấy bờ';
      body = 'Tổng tài sản đã gần hòa vốn!';
    case PriceAlertType.lossThreshold:
      title = 'Cảnh báo: mức lỗ đã vượt ngưỡng chịu đựng';
      body = 'Tổng lỗ hiện tại: ${_signed(ctx.totalProfitLoss, fmt)}';
    case PriceAlertType.profitThreshold:
      title = 'Chúc mừng: Lãi đã đạt mục tiêu!';
      body = 'Tổng lãi hiện tại: ${_signed(ctx.totalProfitLoss, fmt)}';
    case PriceAlertType.priceTarget:
      final up = alert.direction == PriceAlertDirection.above;
      final price = ctx.buyPrices[alert.goldTypeId] ?? 0;
      title = up ? 'Giá vàng đã lên tới mục tiêu' : 'Giá vàng đã xuống tới mục tiêu';
      body = '${goldTypeName ?? 'Vàng'}: tiệm thu mua ${fmt(price)}/lượng '
          '(mục tiêu ${fmt(alert.targetPrice ?? 0)}).';
    case PriceAlertType.priceSurge:
      title = 'Giá vàng biến động mạnh!';
      body = 'Thay đổi lớn vừa xảy ra, kiểm tra ngay.';
  }
  return AlertDecision(fire: true, triggered: true, title: title, body: body);
}

String _signed(double v, String Function(double) fmt) =>
    v < 0 ? '-${fmt(v.abs())}' : fmt(v);
