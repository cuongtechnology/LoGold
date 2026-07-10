import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/meme_template.dart';

/// AiMemeService — tải batch meme do Cloudflare Worker sinh (qua Workers AI,
/// cache theo tuần ở phía server) để **bổ sung**, không thay thế, kho meme
/// tĩnh trong `MemeDatabase`. Fetch lỗi/rỗng/chưa cấu hình worker thì
/// `MemeEngine` vẫn hoạt động bình thường chỉ với dữ liệu tĩnh.
class AiMemeService {
  static AiMemeService? _instance;
  static AiMemeService get instance => _instance ??= AiMemeService._();

  AiMemeService._();

  List<MemeTemplate> _memes = [];

  /// Batch meme AI đã tải (rỗng nếu chưa gọi [load] hoặc fetch thất bại).
  List<MemeTemplate> get memes => _memes;

  /// [workerBaseUrl] rỗng → no-op êm (worker chưa cấu hình lúc build).
  Future<void> load(String workerBaseUrl) async {
    if (workerBaseUrl.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse('$workerBaseUrl/memes'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return;
      _memes = decoded
          .whereType<Map<String, dynamic>>()
          .map(MemeTemplate.fromMap)
          .toList();
    } catch (_) {
      // Mất mạng/worker chưa sinh xong batch nào — bỏ qua êm, dùng kho tĩnh.
    }
  }
}
