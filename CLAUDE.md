# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Ngôn ngữ / Language

Dự án hướng đến người dùng Việt Nam. Toàn bộ UI, meme, thông báo lỗi cho user đều bằng tiếng Việt. Code, comment kỹ thuật, tên biến giữ tiếng Anh. Khi trả lời user, dùng tiếng Việt.

## Lệnh thường dùng

```bash
flutter pub get                      # Cài dependencies
flutter run                          # Chạy app (chọn device khi được hỏi)
flutter run -d chrome                # Chạy trên web
flutter analyze                      # Lint (dùng flutter_lints)
flutter test                         # Chạy toàn bộ test
flutter test test/widget_test.dart   # Chạy 1 file test
flutter build apk                    # Build Android release
flutter build ios                    # Build iOS release

# Nếu có model dùng Hive cần code generation:
dart run build_runner build --delete-conflicting-outputs
```

Yêu cầu SDK: Dart `^3.9.2` (xem `pubspec.yaml`).

## Kiến trúc

App Flutter tên **Lỗ** ("Lỗ nhiều chưa?") — theo dõi lãi/lỗ đầu tư vàng cho user Việt Nam, kèm meme "hỏi đểu đểu" theo mức lỗ. Dark theme + màu vàng làm chủ đạo, font `Be Vietnam Pro` qua `google_fonts`.

### Luồng dữ liệu

```
UI (screens/)
   │ đọc/ghi qua Provider
   ▼
AppStore (stores/app_store.dart)  ← ChangeNotifier duy nhất, root của Provider
   │ delegate tới services (singleton)
   ▼
PortfolioService    PriceService     NotificationService
   │                    │
   │                    ├─ PriceAdapter (interface)
   │                    │     ├─ MockPriceAdapter (mặc định, dev)
   │                    │     └─ [adapter thật thêm sau]
   │
   └─ ProfitLossCalculator (pure, stateless)
   └─ GoldUnits (utils, quy đổi lượng/chỉ/phân/gram)
```

Điểm mấu chốt:

- **`AppStore` là mặt tiền duy nhất cho UI.** UI không gọi service trực tiếp. Mọi mutation gọi qua store để `notifyListeners()` bắn đúng.
- **Services là singleton** truy cập qua `.instance` (pattern `_instance ??= _()`). Không dùng DI framework.
- **`PriceService` dùng adapter pattern** — thêm nguồn giá mới bằng cách implement `PriceAdapter` (`lib/api/price_adapter.dart`) rồi `PriceService.instance.registerAdapter(...)`. Không sửa `PriceService`.
- **`ProfitLossCalculator` là pure functions** — không state, dễ test riêng. Là nơi định nghĩa công thức nghiệp vụ và bảng ánh xạ P/L% → `MemeCondition` / `EmotionalStatus`.
- **Đơn vị chuẩn hóa: `lượng`.** Mọi holding lưu cả `quantity` (đơn vị gốc user nhập) lẫn `quantityInLuong` + `buyPricePerLuong` để tính toán nhất quán. Chuyển đổi qua `GoldUnits` (1 lượng = 10 chỉ = 100 phân = 37.5 gram, hằng số ở `AppConstants`).

### Persistence

- `pubspec.yaml` khai báo `hive` + `hive_flutter` + `shared_preferences`, và `hive_generator` + `build_runner` cho code gen.
- Tên box đã chuẩn hoá ở `AppConstants` (`holdingsBox`, `goldTypesBox`, `alertsBox`, `settingsBox`, `priceHistoryBox`).
- **Trạng thái hiện tại:** `PortfolioService`/`AppStore` đang giữ dữ liệu in-memory (`List<UserHolding>`), chưa persist thật. Khi wire Hive vào phải khởi tạo trong `main.dart` (`Hive.initFlutter()`, register adapters) trước `runApp`, đồng thời đổ dữ liệu vào `PortfolioService.init(holdings: ..., goldTypes: ...)`.

### Meme engine

- `MemeEngine.getMeme(pl%)` trả về meme **deterministic theo ngày** (dùng `dayOfYear % templates.length`) — cùng 1 meme trong cả ngày. `getRandomMeme` cho biến động khi refresh.
- Ngưỡng P/L → điều kiện meme định nghĩa ở `ProfitLossCalculator.getMemeCondition`:
  `≥10% profitHigh · ≥3% profitMedium · ≥0 profitLow · ≥−1 lossMinimal · ≥−3 lossLight · ≥−7 lossModerate · ≥−15 lossHeavy · <−15 lossSpiritual`.
- Ngưỡng cho `EmotionalStatus` **khác** một chút (không có `profitHigh`/`Medium`, chỉ `profitCautious`). Khi sửa 1 trong 2 phải cân nhắc cái còn lại.

### Free tier / monetization

`AppStore.isFreeTierLimitReached` bật khi có ≥ `AppConstants.freeTierMaxHoldings` (=3) active holding và **không** ở `kDebugMode`. `AppConstants.isPro` là feature flag tĩnh — tra cứu khi thêm tính năng Pro.

### Navigation

Không dùng router. `main.dart` gate bằng `AppStore.isOnboarded` → `OnboardingScreen` hoặc `MainShell`. `MainShell` là `IndexedStack` 5 tab (Home / Portfolio / Price Table / Meme / Settings) qua `BottomNavigationBar`. Screen mới thêm vào list `_screens` + `items` trong `_MainShellState`.

### Theme & màu

Chỉnh sửa màu tại `AppColors` trong `lib/constants/app_constants.dart` (gold accents, dark bg, profit/loss/warning). Theme build tại `LoApp._buildDarkTheme()` — không tạo `ThemeData` rời rạc trong screen.

## Tests

Hiện chỉ có `test/widget_test.dart` là placeholder (`expect(true, isTrue)`) vì app cần init Hive. Khi viết test thật: mock adapter qua `PriceService.instance.registerAdapter` + `setActiveAdapter('mock')`, hoặc test trực tiếp `ProfitLossCalculator` (đã pure, dễ nhất).
