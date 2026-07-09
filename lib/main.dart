import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api/cloudflare_worker_price_adapter.dart';
import 'api/sjc_price_adapter.dart';
import 'api/vang_today_price_adapter.dart';
import 'constants/app_constants.dart';
import 'services/ad_service.dart';
import 'services/price_service.dart';
import 'services/push_notification_service.dart';
import 'services/storage_service.dart';
import 'stores/app_store.dart';
import 'screens/onboarding_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/price_table_screen.dart';
import 'screens/top_lo_screen.dart';
import 'screens/settings_screen.dart';

/// URL của CF Worker (đăng ký push token + KV cache dự phòng). Truyền lúc build:
///   flutter build apk --dart-define=LO_WORKER_URL=https://lo-gold-proxy.xxx.workers.dev
/// Rỗng → app vẫn chạy bình thường, chỉ tự tắt tính năng đăng ký push token
/// (xem `_configurePriceAdapters` — worker KHÔNG tự động thành nguồn giá
/// chính, `VangTodayPriceAdapter` mới là nguồn giá mặc định).
const _kWorkerUrl = String.fromEnvironment('LO_WORKER_URL', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  _configurePriceAdapters();
  runApp(const LoApp());

  // Không chặn màn hình đầu tiên vẽ — ads/push đều tự no-op êm nếu chưa
  // cấu hình (chưa có AdMob App ID thật / chưa có Firebase project).
  unawaited(AdService.instance.init());
  unawaited(
    PushNotificationService.instance.init(
      registerEndpoint: _kWorkerUrl.isEmpty ? '' : '$_kWorkerUrl/register-token',
    ),
  );
}

/// `VangTodayPriceAdapter` luôn là nguồn giá mặc định (API miễn phí, bật
/// CORS, chạy được cả web lẫn mobile không cần proxy) — set `LO_WORKER_URL`
/// KHÔNG đổi nguồn giá, chỉ bật tính năng push (xem `main()`).
/// `SjcPriceAdapter`/`CloudflareWorkerPriceAdapter` vẫn đăng ký làm nguồn dự
/// phòng (mobile) nếu sau này cần chuyển tay qua `PriceService.setActiveAdapter`.
void _configurePriceAdapters() {
  final price = PriceService.instance;

  final vangToday = VangTodayPriceAdapter();
  price.registerAdapter(vangToday);
  price.setActiveAdapter(vangToday.sourceKey);

  if (!kIsWeb) {
    price.registerAdapter(SjcPriceAdapter());
  }

  if (_kWorkerUrl.isNotEmpty) {
    price.registerAdapter(CloudflareWorkerPriceAdapter(baseUrl: _kWorkerUrl));
  }
}

class LoApp extends StatelessWidget {
  const LoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStore()..init(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: _buildDarkTheme(),
        home: const _AppGate(),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.goldDark,
        surface: AppColors.bgCard,
        error: AppColors.loss,
      ),
      textTheme: GoogleFonts.beVietnamProTextTheme(
        const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          bodySmall: TextStyle(color: AppColors.textHint),
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgSecondary,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bgPrimary,
      ),
      dividerColor: AppColors.divider,
    );
  }
}

/// Gate màn hình đầu vào: Onboarding → (khoá PIN nếu bật) → MainShell.
/// Tự khoá lại mỗi khi app quay về từ nền (không chỉ lúc cold start) — bảo
/// vệ thật sự chứ không phải chỉ hỏi PIN 1 lần lúc mở app.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> with WidgetsBindingObserver {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final store = context.read<AppStore>();
      if (store.pinEnabled && _unlocked) {
        setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    if (!store.isOnboarded) return const OnboardingScreen();
    if (store.pinEnabled && !_unlocked) {
      return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
    }
    return const MainShell();
  }
}

/// Main app shell with bottom navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    PortfolioScreen(),
    PriceTableScreen(),
    TopLoScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Danh mục',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_outlined),
            activeIcon: Icon(Icons.trending_up),
            label: 'Giá vàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Top Lỗ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
