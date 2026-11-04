# Hướng dẫn build – Lỗ (LoGold)

Tài liệu mô tả cách chạy test, build Android, iOS và Web cho app **Lỗ nhiều chưa?** (`vn.lo.app`), cách ký app, CI trên Codemagic và các lỗi hay gặp.

## 1. Phiên bản công cụ

| Thành phần | Phiên bản | Khai báo ở |
|---|---|---|
| Flutter | **≥ 3.44** (do `pubspec.lock` yêu cầu) | `pubspec.lock` → `sdks:` |
| Dart | ≥ 3.12 (`google_mobile_ads` 9.x cần ≥ 3.10) | `pubspec.lock` |
| JDK | 17 | `codemagic.yaml` |
| Gradle wrapper | 8.12 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | 8.9.1 | `android/settings.gradle.kts` |
| Kotlin | 2.3.0 (bắt buộc cho `google_mobile_ads`) | `android/settings.gradle.kts` |
| iOS | CocoaPods (`pod install` trên CI) | `ios/` |

> ⚠️ Trong `codemagic.yaml`, hai workflow iOS dùng Flutter 3.47.5, còn `web-android-workflow` vẫn ghim `flutter: 3.35.4` (Dart 3.9.2). Bản 3.35.4 **không** chạy được `pub get` với lock hiện tại, vì lock yêu cầu Flutter ≥ 3.44. Cần đổi sang đúng phiên bản Flutter đang dùng để tạo `pubspec.lock`.
>
> Flutter 3.47 trở lên yêu cầu AGP ≥ 8.11.1, trong khi project dùng 8.9.1. Có hai cách: nâng AGP trong `android/settings.gradle.kts`, hoặc build kèm cờ `--android-skip-build-dependency-validation`.
>
> Máy dev Windows hiện dùng `C:\flutter` (3.47.5) và cờ trên.

Trên **Windows** phải bật **Developer Mode** (`start ms-settings:developers`), vì Flutter cần tạo symlink cho plugin.

## 2. Thông tin app

| | Giá trị |
|---|---|
| Android `applicationId` / iOS bundle ID | `vn.lo.app` |
| Tên hiển thị | Lỗ nhiều chưa? |
| Phiên bản | `version:` trong `pubspec.yaml` (`0.1.0+2` = versionName `0.1.0`, versionCode `2`) |

Mỗi lần nộp Play Console phải **tăng số sau dấu `+`**, vì Play Console từ chối versionCode đã dùng.

## 3. Cấu hình ngoài code

| Thứ cần có | Dùng cho | Khi thiếu thì sao |
|---|---|---|
| `--dart-define=LO_WORKER_URL=https://lo-gold-proxy.webjscloud.workers.dev` | Proxy giá vàng, meme AI, đăng ký FCM token | App vẫn chạy nhưng push báo "chưa kết nối server gửi thông báo" |
| `android/app/google-services.json` (Firebase Console) | Push notification (FCM) | Plugin Google Services không được apply, build vẫn chạy nhưng không có push |
| `android/key.properties` + keystore | Ký bản release | Bản release được ký bằng **debug key** |

App ID AdMob của Android nằm trong `AndroidManifest.xml`. Trên iOS, `Info.plist` vẫn đang dùng **App ID mẫu của Google** (`ca-app-pub-3940256099942544~…`), phải thay bằng ID thật trước khi lên App Store.

## 4. Test

```bash
flutter pub get
flutter analyze
flutter test
```

| File | Kiểm tra |
|---|---|
| `test/gold_units_test.dart` | Quy đổi lượng/chỉ/phân/gram và giá theo đơn vị |
| `test/formatters_test.dart` | Parse số kiểu Việt Nam (`116.000.000`, `0,5`) |
| `test/profit_loss_calculator_test.dart` | Lãi/lỗ, giá hòa vốn, ngưỡng meme |
| `test/utilities_widget_test.dart` | Các màn tiện ích (chốt lời, bình quân, mua được bao nhiêu…) |

## 5. Android

### 5.1. Lệnh build

```bash
flutter build apk --release --dart-define=LO_WORKER_URL=$LO_WORKER_URL        # cài thử
flutter build appbundle --release --dart-define=LO_WORKER_URL=$LO_WORKER_URL  # nộp Play Store
flutter build apk --debug                                                     # debug nhanh
```

Kết quả:
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/mapping/release/mapping.txt` (dùng để giải mã crash, vì bản release có bật R8)

### 5.2. Ký app

`android/app/build.gradle.kts` đọc `android/key.properties`:

```properties
storeFile=lo-release.jks        # đường dẫn tính từ android/app/
storePassword=...
keyAlias=...
keyPassword=...
```

Keystore đặt tại `android/app/lo-release.jks`. Cả hai file đều bị git bỏ qua.

> ⚠️ App đã có trên Play Console. **Chỉ được ký bằng upload key gốc** (bản đang lưu base64 trong biến `CM_KEYSTORE_B64` trên Codemagic). Ký bằng key khác thì Play Console từ chối bản cập nhật. Phải sao lưu keystore và mật khẩu.

Kiểm tra chữ ký của APK:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\<version>\apksigner.bat" verify --print-certs app-release.apk
```

### 5.3. R8 – bắt buộc chạy thử bản release

Bản release bật `isMinifyEnabled` và `isShrinkResources`. R8 có thể xóa nhầm những class chỉ được gọi qua reflection (push, AdMob). Khi đó build vẫn thành công nhưng app **crash lúc chạy**. Luôn cài bản APK release lên máy thật hoặc emulator và thử push, quảng cáo trước khi nộp. Nếu cần giữ class nào, khai báo trong `android/app/proguard-rules.pro`.

### 5.4. Build trên máy dev khi ổ đĩa đầy

Trên máy dev hiện tại, ổ `E:` và ổ gắn tại `C:\Users\<user>\.gradle` gần đầy nên Gradle báo `There is not enough space on the disk`. Cách xử lý là build từ một bản sao trên ổ còn trống, với Gradle home riêng:

```powershell
$work = "C:\build\LoGold"; $env:GRADLE_USER_HOME = "C:\build\gradle-home"
robocopy E:\Lo $work /MIR /XD E:\Lo\build E:\Lo\.dart_tool E:\Lo\android\.gradle E:\Lo\.git `
  "$work\build" "$work\.dart_tool" "$work\android\.gradle" /XF local.properties
Set-Location $work
C:\flutter\bin\flutter.bat build apk --release --android-skip-build-dependency-validation
```

## 6. Web

```bash
flutter build web --release --no-wasm-dry-run --dart-define=LO_WORKER_URL=$LO_WORKER_URL
```

Kết quả nằm ở `build/web/`. Trên web, giá vàng phải đi qua Cloudflare Worker do CORS.

## 7. iOS

Build iOS bắt buộc có macOS và Xcode. Máy dev chạy Windows nên build trên Codemagic. Tất cả các bước dưới đây làm được bằng trình duyệt trên Windows.

| Workflow | Chạy khi | Kết quả |
|---|---|---|
| `ios-workflow` | Tag `v*` | IPA **chưa ký**, chỉ để kiểm tra build |
| `ios-testflight-workflow` | Chạy tay | IPA đã ký, tự upload lên **TestFlight** |

Cấu hình iOS trong project: bundle ID `vn.lo.app`, iOS tối thiểu **15.0** (Firebase 12 yêu cầu, khai báo ở `ios/Podfile` và `project.pbxproj`), `ITSAppUsesNonExemptEncryption = false` để App Store Connect không hỏi Export Compliance mỗi build.

### 7.1. Thiết lập một lần

**Bước 1. Tạo app trên App Store Connect.** Vào [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Apps → **+** → New App:
- Platform: iOS. Name: tên hiển thị trên App Store (phải chưa ai dùng, ví dụ "Lỗ nhiều chưa?").
- Bundle ID: chọn **`vn.lo.app`**. Nếu chưa có trong danh sách, vào [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** → App IDs → App, điền Bundle ID `vn.lo.app` (Explicit), rồi quay lại.
- SKU: chuỗi bất kỳ, ví dụ `lo-gold`.

**Bước 2. Tạo App Store Connect API key.** App Store Connect → Users and Access → **Integrations** → App Store Connect API → Team Keys → **+**:
- Tên: `Codemagic`. Access: **App Manager**.
- Tải file `AuthKey_XXXXXXXXXX.p8`. Apple **chỉ cho tải một lần**, phải cất kỹ.
- Ghi lại **Issuer ID** (đầu trang) và **Key ID** (cột của key vừa tạo).

**Bước 3. Tạo private key cho chứng chỉ ký app.** Chạy trong PowerShell (Windows 10/11 có sẵn `ssh-keygen`):

```powershell
ssh-keygen -t rsa -b 2048 -m PEM -f "$HOME\keystores\ios_distribution_private_key" -q -N '""'
```

Codemagic dùng key này để tạo chứng chỉ Apple Distribution ở lần build đầu, rồi dùng lại ở các lần sau. **Không** commit file này vào git; cất cùng chỗ với keystore Android.

**Bước 4. Khai báo biến trên Codemagic.** Codemagic → Team settings → **Environment variables**, tạo group **`ios_release`** gồm 4 biến, đều đánh dấu **Secure**:

| Biến | Giá trị |
|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (bước 2) |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Key ID (bước 2) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Toàn bộ nội dung file `.p8`, kể cả dòng `-----BEGIN PRIVATE KEY-----` và `-----END...` |
| `CERTIFICATE_PRIVATE_KEY` | Toàn bộ nội dung file `ios_distribution_private_key` (bước 3), không phải file `.pub` |

### 7.2. Build và đẩy lên TestFlight

1. Push code lên GitHub (Codemagic đọc `codemagic.yaml` trên nhánh được chọn).
2. Codemagic → app LoGold → **Start new build** → chọn nhánh, workflow **iOS TestFlight** → Start.
3. Khoảng 15–25 phút sau, build xuất hiện trong App Store Connect → TestFlight. Apple cần thêm 5–30 phút để xử lý build ("Processing").
4. Thêm người test: TestFlight → **Internal Testing** → tạo nhóm, thêm Apple ID (tối đa 100 người, không cần Apple duyệt). Người test cài app **TestFlight** trên iPhone rồi nhận lời mời.

Build number lấy từ số build của Codemagic (`$BUILD_NUMBER`), tự tăng. Version name (`0.1.0`) lấy từ `pubspec.yaml`.

### 7.3. Việc cần làm trước khi nộp App Store (chưa bắt buộc cho TestFlight)

- **AdMob:** `ios/Runner/Info.plist` (`GADApplicationIdentifier`) và `lib/services/ad_service.dart` đang dùng **ID test của Google**. Tạo app iOS trên AdMob Console rồi thay bằng ID thật. Quảng cáo test vẫn hiện bình thường trên TestFlight.
- **Push notification:** trên iOS hiện **chưa hoạt động** (app tự bỏ qua, không crash). Để bật cần:
  1. Firebase Console → thêm app iOS `vn.lo.app` → tải `GoogleService-Info.plist`. File này đang bị git bỏ qua, nên lưu base64 vào Codemagic và giải mã ra `ios/Runner/` trong một bước script.
  2. developer.apple.com → Keys → tạo **APNs key** → upload lên Firebase (Project settings → Cloud Messaging → Apple app configuration).
  3. Bật capability Push Notifications cho App ID `vn.lo.app`, thêm `ios/Runner/Runner.entitlements` (`aps-environment = production`) và `CODE_SIGN_ENTITLEMENTS` vào project.
- **App Store listing:** ảnh chụp màn hình iPhone 6.9" và 6.5", mô tả, chính sách bảo mật (`docs/index.html`), khai báo App Privacy (AdMob thu thập dữ liệu quảng cáo).

### 7.4. Lỗi iOS thường gặp

| Lỗi | Cách xử lý |
|---|---|
| `No matching profiles found` / `Cannot save Signing Certificates without certificate private key` | Thiếu hoặc sai `CERTIFICATE_PRIVATE_KEY` (bước 3–4) |
| `There is a problem with the request entity ... maximum number of certificates` | Tài khoản đã có 3 chứng chỉ Distribution. Thu hồi bớt một cái ở developer.apple.com → Certificates |
| `Unable to find a bundle identifier vn.lo.app` | Chưa tạo App ID (bước 1) |
| `required a higher minimum deployment target` | Một pod yêu cầu iOS cao hơn 15.0. Nâng `platform :ios` trong `ios/Podfile` và `IPHONEOS_DEPLOYMENT_TARGET` trong `project.pbxproj` |
| Upload báo `bundle version must be higher` | Build number trùng với một build đã upload. Chạy lại workflow để có `$BUILD_NUMBER` lớn hơn |
| Email Apple "ITMS-90078: Missing Push Notification Entitlement" | Chỉ là cảnh báo, do `UIBackgroundModes` có `remote-notification`. Hết khi làm xong phần push ở 7.3 |

## 8. Cloudflare Worker

Mã nguồn ở `worker/`. Deploy bằng:

```bash
cd worker && bash DEPLOY.sh
```

Yêu cầu Node ≥ 18 và tài khoản Cloudflare. Xem phần đầu `worker/DEPLOY.sh` để biết cách dùng API token khi chạy trên máy không có trình duyệt.

## 9. CI/CD – Codemagic (`codemagic.yaml`)

| Workflow | Chạy khi | Các bước | Kết quả |
|---|---|---|---|
| `web-android-workflow` (Linux) | Push lên `main`, tag `v*` | pub get → analyze → **test** → build web, APK debug/release, AAB | `lo-web.zip`, APK, AAB, `mapping.txt`; tag `v*` tạo GitHub Release |
| `ios-workflow` (Mac mini M2) | Tag `v*` | pub get → build iOS không ký | `lo-ios-unsigned.ipa` |
| `ios-testflight-workflow` (Mac mini M2) | Chạy tay | pub get → lấy/tạo chứng chỉ + profile → build IPA | IPA đã ký, upload TestFlight |

Bí mật iOS nằm trong group **`ios_release`** (xem mục 7.1). Bí mật Android lưu ở Codemagic → Team settings → Environment variables, group **`android_release`**: `CM_KEYSTORE_B64` (keystore mã hóa base64), `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD`. Bước "Setup Android signing" sẽ giải mã keystore thành `android/app/lo-release.jks` và tạo `android/key.properties`.

## 10. Lỗi thường gặp

| Lỗi | Cách xử lý |
|---|---|
| `Building with plugins requires symlink support` | Bật Developer Mode trên Windows |
| `Android Gradle Plugin version ... is lower than Flutter's minimum` | Thêm `--android-skip-build-dependency-validation` hoặc nâng AGP (mục 1) |
| `google_mobile_ads ... requires SDK version >=3.10.0` | Flutter quá cũ (vd. 3.35.4). Dùng Flutter ≥ 3.44 |
| `There is not enough space on the disk` | Ổ chứa project hoặc Gradle home bị đầy. Xem mục 5.4 |
| `Timeout ... waiting for exclusive access to file ... gradle-*.zip` | Có một Gradle khác đang tải cùng file. Tắt các tiến trình `java.exe` của Gradle rồi build lại |
| Play Console: "mã phiên bản đã được sử dụng" | Tăng số sau `+` trong `version:` |
| Push báo "chưa kết nối server" | Build thiếu `--dart-define=LO_WORKER_URL=...` hoặc thiếu `google-services.json` |
| App release crash, debug thì chạy bình thường | Do R8. Xem mục 5.3 |
