import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../stores/app_store.dart';

/// Màn khoá PIN — chặn truy cập app khi user đã bật "Mã PIN" trong Cài đặt.
/// Hiện lúc mở app lần đầu (cold start) và mỗi khi app quay lại từ nền
/// (xem `_AppGate` trong `main.dart`). Nếu bật mở khoá sinh trắc thì tự hiện
/// hộp thoại vân tay / Face ID (đúng 1 lần mỗi lần khoá); PIN luôn dùng được.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;
  bool _biometricBusy = false;
  bool _autoPrompted = false;
  Duration _blocked = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncBlock();
    // Chờ frame đầu để context/Provider sẵn sàng.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPrompt());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Màn khoá được dựng lúc app còn ở nền (`paused`) → chưa thể hiện hộp
    // thoại sinh trắc; đợi app thật sự quay lại rồi mới tự hiện.
    if (state == AppLifecycleState.resumed) _autoPrompt();
  }

  /// Tự hiện sinh trắc tối đa 1 lần mỗi lần màn khoá xuất hiện — huỷ thì
  /// không tự hiện lại (tránh vòng lặp), user bấm nút để thử lại.
  void _autoPrompt() {
    if (!mounted || _autoPrompted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (!context.read<AppStore>().biometricEnabled) return;
    _autoPrompted = true;
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_biometricBusy) return;
    final store = context.read<AppStore>();
    setState(() => _biometricBusy = true);
    final ok = await store.unlockWithBiometric();
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    setState(() => _biometricBusy = false);
  }

  /// Cập nhật thời gian còn bị khoá và bật/tắt đồng hồ đếm ngược 1s.
  void _syncBlock() {
    final remaining = context.read<AppStore>().pinBlockRemaining;
    setState(() => _blocked = remaining);
    _ticker?.cancel();
    if (remaining > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final left = context.read<AppStore>().pinBlockRemaining;
        setState(() => _blocked = left);
        if (left <= Duration.zero) {
          _ticker?.cancel();
          setState(() => _error = null);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_checking || _blocked > Duration.zero) return;
    final store = context.read<AppStore>();
    setState(() => _checking = true);
    final ok = await store.verifyPin(_controller.text.trim());
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    _controller.clear();
    setState(() {
      _checking = false;
      _error = 'Mã PIN không đúng';
    });
    _syncBlock();
  }

  String _blockText() {
    final s = _blocked.inSeconds + (_blocked.inMilliseconds % 1000 > 0 ? 1 : 0);
    final mm = (s ~/ 60).toString();
    final ss = (s % 60).toString().padLeft(2, '0');
    return 'Nhập sai quá nhiều lần. Thử lại sau $mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isBlocked = _blocked > Duration.zero;
    final showBiometric = context.select<AppStore, bool>(
      (s) => s.biometricEnabled,
    );
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, color: AppColors.gold, size: 56),
                const SizedBox(height: 24),
                const Text(
                  'Nhập mã PIN để mở Lỗ nhiều chưa?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: !showBiometric,
                  enabled: !isBlocked,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    errorText: isBlocked ? _blockText() : _error,
                    errorMaxLines: 2,
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isBlocked || _checking) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Mở khoá'),
                  ),
                ),
                if (showBiometric) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _biometricBusy ? null : _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Dùng vân tay / Face ID'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
