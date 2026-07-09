import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// Banner ad tự quản lý vòng đời (load/dispose). Ẩn hoàn toàn
/// (`SizedBox.shrink`) nếu ads đang tắt (Pro user) hoặc load lỗi — không
/// chiếm chỗ layout khi không có gì để hiện.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    // AdService.instance.init() có thể đang chạy (gọi từ main()) hoặc chưa
    // bắt đầu — await ở đây để không tạo banner trước khi SDK sẵn sàng.
    await AdService.instance.init();
    if (!mounted) return;
    setState(() {
      _ad = AdService.instance.createBanner(
        onLoaded: () {
          if (mounted) setState(() => _loaded = true);
        },
        onFailed: () {
          if (mounted) setState(() => _ad = null);
        },
      );
    });
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: ad.size.height.toDouble(),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
