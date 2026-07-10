import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdService — khởi tạo Google Mobile Ads SDK và cấp phát banner ad.
///
/// Android dùng Ad Unit ID thật (app "Lỗ" trên AdMob Console). iOS chưa có
/// app/Ad Unit riêng nên tạm giữ Test Ad Unit ID của Google — KHÔNG dùng
/// chung ID Android cho iOS vì AdMob gắn app/ad unit theo platform, dùng
/// sai platform dễ bị tính là invalid traffic.
class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();

  AdService._();

  bool _initialized = false;
  Future<void>? _initFuture;

  /// Banner ad unit ID theo platform.
  /// TODO: thay ID iOS bằng Ad Unit thật khi có app iOS riêng trên AdMob Console.
  static String get bannerAdUnitId {
    if (kIsWeb) return ''; // AdMob web cần setup riêng, chưa hỗ trợ ở đây.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-8197625767029457/4645135209';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Test ID của Google.
    }
    return '';
  }

  /// Khởi tạo SDK. An toàn gọi nhiều lần/đồng thời — dùng chung 1 Future nên
  /// `main()` (fire-and-forget) và `BannerAdWidget` (await để biết khi nào
  /// gọi `createBanner`) luôn thấy cùng 1 kết quả, không lệch thứ tự.
  Future<void> init() {
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    if (bannerAdUnitId.isEmpty) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('AdService init lỗi: $e');
    }
  }

  /// Tạo 1 banner ad mới đã gọi `load()`. Mỗi vị trí hiển thị cần 1 instance
  /// riêng (không share instance giữa nhiều widget). Trả null nếu SDK chưa
  /// init được hoặc platform không hỗ trợ.
  ///
  /// Dùng Adaptive Banner (co giãn hết [width], Google tự chọn chiều cao tối
  /// ưu) thay vì `AdSize.banner` cố định 320×50 — Google khuyến nghị format
  /// này để tăng fill rate/doanh thu trên mọi kích thước màn hình.
  Future<BannerAd?> createBanner({
    required int width,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    if (!_initialized || bannerAdUnitId.isEmpty) {
      return null;
    }
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null) return null;
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed();
        },
      ),
    )..load();
  }
}
