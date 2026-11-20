# Lỗ – Lỗ nhiều chưa?

App Flutter theo dõi lãi/lỗ vàng cho người Việt, kèm meme "hỏi đểu" xen kẽ khắp app theo mức lỗ.

## Tính năng
- Ghi lại các lần mua vàng (SJC, nhẫn 9999, vàng 9999, trang sức) theo lượng, chỉ, phân hoặc gram. Dữ liệu lưu trên máy bằng Hive.
- Giá SJC/DOJI thật qua Cloudflare Worker. Tính lãi/lỗ, giá hòa vốn, so sánh với giá trong quá khứ.
- Meme theo mức lỗ ở Trang chủ, Danh mục, Bảng giá, Chi tiết giao dịch, Top Lỗ. Có meme sinh bằng AI (Workers AI).
- Tiện ích: đổi đơn vị, tính mua/bán, giá hòa vốn, giá chốt lời, giá bình quân, mua được bao nhiêu, so sánh vàng với gửi tiết kiệm, chênh lệch mua/bán.
- Cảnh báo giá, push notification, khóa PIN, xuất CSV/JSON, AdMob.

## Chạy nhanh

```bash
flutter pub get
flutter test
flutter run --dart-define=LO_WORKER_URL=https://lo-gold-proxy.webjscloud.workers.dev
```

## Tài liệu
- **[docs/BUILD.md](docs/BUILD.md)**: build Android, iOS và Web, ký app, Codemagic, xử lý lỗi.
- **[CLAUDE.md](CLAUDE.md)**: kiến trúc và quy ước code.
- `docs/index.html`: chính sách bảo mật.
- `worker/`: Cloudflare Worker (proxy giá, push, meme AI).
