import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _msg(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_emailForm.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.forgotPassword(_email.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => _codeSent = true);
      _msg('Nếu email đã đăng ký, mã sẽ được gửi (có hiệu lực 10 phút)');
    } else {
      _msg(auth.errorMessage ?? 'Gửi mã thất bại');
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(
        _email.text.trim(), _otp.text.trim(), _newPass.text);
    if (!mounted) return;
    if (ok) {
      _msg('Đổi mật khẩu thành công, hãy đăng nhập lại');
      context.pop();
    } else {
      _msg(auth.errorMessage ?? 'Đổi mật khẩu thất bại');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _codeSent ? _buildResetStep(loading) : _buildEmailStep(loading),
        ),
      ),
    );
  }

  Widget _buildEmailStep(bool loading) => Form(
        key: _emailForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nhập email đã đăng ký, chúng tôi sẽ gửi mã xác nhận 6 số.'),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : _sendCode,
              child: const Text('Gửi mã'),
            ),
          ],
        ),
      );

  Widget _buildResetStep(bool loading) => Form(
        key: _resetForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mã đã gửi tới ${_email.text.trim()}'),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Mã xác nhận (6 số)',
              controller: _otp,
              keyboardType: TextInputType.number,
              validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())
                  ? null
                  : 'Mã gồm đúng 6 chữ số',
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Mật khẩu mới',
              controller: _newPass,
              obscureText: true,
              validator: Validators.password,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Nhập lại mật khẩu mới',
              controller: _confirm,
              obscureText: true,
              validator: (v) => v == _newPass.text ? null : 'Mật khẩu không khớp',
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : _reset,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white))
                  : const Text('Đổi mật khẩu'),
            ),
            TextButton(
              onPressed: loading ? null : () => _sendCode(resend: true),
              child: const Text('Gửi lại mã'),
            ),
            TextButton(
              onPressed: () => setState(() => _codeSent = false),
              child: const Text('Đổi email'),
            ),
          ],
        ),
      );
}
