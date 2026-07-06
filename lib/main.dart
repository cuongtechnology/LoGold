import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api/cloudflare_worker_price_adapter.dart';
import 'api/sjc_price_adapter.dart';
import 'constants/app_constants.dart';
import 'services/price_service.dart';
import 'services/storage_service.dart';
import 'stores/app_store.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/price_table_screen.dart';
import 'screens/top_lo_screen.dart';
import 'screens/settings_screen.dart';

/// URL của CF Worker proxy giá vàng. Truyền lúc build:
///   flutter build web --dart-define=LO_WORKER_URL=https://lo-gold-proxy.xxx.workers.dev
/// Nếu rỗng → web dùng Mock, mobile dùng SjcPriceAdapter fetch trực tiếp.
const _kWorkerUrl = String.fromEnvironment('LO_WORKER_URL', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  _configurePriceAdapters();
  runApp(const LoApp());
}

/// Ưu tiên adapter theo platform + config:
/// 1. Có `LO_WORKER_URL` → dùng CF Worker (cả web + mobile hưởng cache chung).
/// 2. Mobile không có Worker URL → `SjcPriceAdapter` fetch trực tiếp.
/// 3. Web không có Worker URL → giữ Mock (CORS chặn fetch trực tiếp).
void _configurePriceAdapters() {
  final price = PriceService.instance;

  if (_kWorkerUrl.isNotEmpty) {
    final worker = CloudflareWorkerPriceAdapter(baseUrl: _kWorkerUrl);
    price.registerAdapter(worker);
    price.setActiveAdapter(worker.sourceKey);
    return;
  }

  if (!kIsWeb) {
    final sjc = SjcPriceAdapter();
    price.registerAdapter(sjc);
    price.setActiveAdapter(sjc.sourceKey);
  }
}

class LoApp extends StatelessWidget {
  const LoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStore()..init(),
      child: Consumer<AppStore>(
        builder: (context, store, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: _buildDarkTheme(),
            home: store.isOnboarded
                ? const MainShell()
                : const OnboardingScreen(),
          );
        },
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
