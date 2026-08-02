import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/verify_otp_controller.dart';
import '../models/otp_flow.dart';
import '../theme/spark_colors.dart';
import '../widgets/spark_auth_scaffold.dart';
import '../widgets/spark_text_field.dart';
import 'login_view.dart';
import 'new_password_view.dart';

class VerifyOtpView extends StatefulWidget {
  const VerifyOtpView({
    super.key,
    required this.email,
    this.flow = OtpFlow.passwordReset,
  });

  final String email;
  final OtpFlow flow;

  @override
  State<VerifyOtpView> createState() => _VerifyOtpViewState();
}

class _VerifyOtpViewState extends State<VerifyOtpView> {
  late final VerifyOtpController _controller;
  final _otpFocus = FocusNode();
  final _otpTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = VerifyOtpController(email: widget.email, flow: widget.flow)
      ..addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onUpdate)
      ..dispose();
    _otpFocus.dispose();
    _otpTextController.dispose();
    super.dispose();
  }

  Future<void> _onVerify() async {
    if (_controller.isSubmitting) return;
    FocusScope.of(context).unfocus();
    final ok = await _controller.submit();
    if (!mounted || !ok) return;

    if (widget.flow == OtpFlow.signUp) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginView()),
        (_) => false,
      );
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: SparkColors.surfaceElevated,
          content: Text(
            'Account created. Please log in.',
            style: TextStyle(color: SparkColors.title),
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NewPasswordView(email: widget.email),
      ),
    );
  }

  Future<void> _onResend() async {
    if (_controller.isResending) return;
    final ok = await _controller.resend();
    if (!mounted || !ok) return;
    _otpTextController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: SparkColors.surfaceElevated,
        content: Text(
          'A new OTP was sent to your email.',
          style: TextStyle(color: SparkColors.title),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maskedEmail = _maskEmail(widget.email);

    return SparkAuthScaffold(
      title: 'Verify OTP',
      subtitle: 'Enter the 6-digit code we sent to $maskedEmail',
      primaryLabel: _controller.isSubmitting ? 'Verifying...' : 'Verify OTP',
      onPrimaryPressed: _onVerify,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: SparkColors.title,
          size: 20,
        ),
      ),
      footer: GestureDetector(
        onTap: _onResend,
        child: Text(
          _controller.isResending ? 'Sending...' : 'Resend OTP',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: SparkColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
        ),
      ),
      children: [
        SparkTextField(
          hint: 'OTP',
          controller: _otpTextController,
          focusNode: _otpFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          errorText: _controller.errors['otp'],
          onChanged: _controller.updateOtp,
          onSubmitted: (_) => _onVerify(),
        ),
      ],
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final name = parts[0];
    final visible = name.length <= 2 ? name[0] : name.substring(0, 2);
    return '$visible***@${parts[1]}';
  }
}
