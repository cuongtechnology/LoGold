import 'package:in_app_review/in_app_review.dart';

import 'storage_service.dart';

/// ReviewService — xin đánh giá app qua Google Play In-App Review API (modal
/// native, không rời khỏi app). Play Store tự quyết định có thực sự hiện
/// modal hay không (có quota/throttle riêng phía Google) — mình chỉ kiểm
/// soát "khi nào NÊN xin", không đảm bảo modal chắc chắn hiện ra.
///
/// Điều kiện xin (chỉ 1 lần, đúng lúc trải nghiệm tích cực thay vì ngay khi
/// mở app lần đầu — theo khuyến nghị của Google):
/// - Đã dùng app ít nhất [_minDaysSinceFirstOpen] ngày kể từ lần mở đầu tiên.
/// - Đang có ít nhất [_minActiveHoldings] vị thế vàng đang theo dõi.
/// - Chưa từng xin thành công trước đó.
class ReviewService {
  static ReviewService? _instance;
  static ReviewService get instance => _instance ??= ReviewService._();

  ReviewService._();

  static const _kFirstOpenDate = 'reviewFirstOpenDate';
  static const _kRequested = 'reviewRequested';
  static const _minDaysSinceFirstOpen = 3;
  static const _minActiveHoldings = 2;

  final _inAppReview = InAppReview.instance;

  /// Gọi lúc app khởi động để ghi nhận "lần mở đầu tiên" nếu chưa có — làm
  /// mốc tính đủ [_minDaysSinceFirstOpen] ngày.
  Future<void> recordFirstOpenIfNeeded() async {
    if (StorageService.getSetting<String>(_kFirstOpenDate) == null) {
      await StorageService.putSetting(
        _kFirstOpenDate,
        DateTime.now().toIso8601String(),
      );
    }
  }

  /// Kiểm tra điều kiện, xin đánh giá nếu phù hợp. An toàn gọi nhiều lần —
  /// tự bỏ qua nếu đã xin thành công rồi hoặc chưa đủ điều kiện.
  Future<void> maybeRequestReview({required int activeHoldingCount}) async {
    if (StorageService.getSetting<bool>(_kRequested) == true) return;
    if (activeHoldingCount < _minActiveHoldings) return;

    final firstOpenRaw = StorageService.getSetting<String>(_kFirstOpenDate);
    if (firstOpenRaw == null) return;
    final firstOpen = DateTime.tryParse(firstOpenRaw);
    if (firstOpen == null) return;
    if (DateTime.now().difference(firstOpen).inDays < _minDaysSinceFirstOpen) {
      return;
    }

    try {
      if (!await _inAppReview.isAvailable()) return;
      await _inAppReview.requestReview();
      // Đánh dấu đã xin ngay khi gọi API thành công — không phụ thuộc việc
      // modal có thực sự hiện hay không (Google khuyến nghị không gọi lại
      // liên tục dù modal không hiện).
      await StorageService.putSetting(_kRequested, true);
    } catch (_) {
      // Không khả dụng (không cài từ Play Store, lỗi platform...) — bỏ qua
      // êm, thử lại ở lần mở app sau.
    }
  }

  /// Mở thẳng trang app trên Play Store — dùng cho nút "Đánh giá ứng dụng"
  /// trong Cài đặt (user tự bấm, bỏ qua mọi điều kiện tự động ở trên).
  Future<void> openStoreListing() => _inAppReview.openStoreListing();
}
