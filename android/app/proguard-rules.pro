# Firebase Cloud Messaging, Google Mobile Ads (AdMob), in_app_review, và các
# plugin AndroidX khác đều tự bundle "consumer proguard rules" trong AAR của
# họ — AGP tự merge vào, nên phần lớn không cần khai thêm ở đây.
#
# flutter_local_notifications: giữ nguyên các class model dùng qua
# reflection/serialization khi lên lịch/hiển thị notification.
-keep class com.dexterous.** { *; }

# Gson (dùng gián tiếp bởi vài plugin để (de)serialize) — giữ nguyên field
# generic signature, tránh lỗi mất field lúc runtime.
-keepattributes Signature
-keepattributes *Annotation*
