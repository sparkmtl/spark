import 'package:flutter/material.dart';

import '../controllers/forgot_password_controller.dart';
import '../models/otp_flow.dart';
import '../theme/spark_colors.dart';
import '../widgets/spark_auth_scaffold.dart';
import '../widgets/spark_text_field.dart';
import 'verify_otp_view.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  late final ForgotPasswordController _controller;
  final _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = ForgotPasswordController()..addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onUpdate)
      ..dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_controller.isSubmitting) return;
    FocusScope.of(context).unfocus();
    final ok = await _controller.submit();
    if (!mounted || !ok) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifyOtpView(
          email: _controller.model.email.trim(),
          flow: OtpFlow.passwordReset,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SparkAuthScaffold(
      title: 'Forgot Password',
      subtitle:
          "Enter your email and we'll send you a one-time password (OTP).",
      primaryLabel:
          _controller.isSubmitting ? 'Sending...' : 'Send Reset Link',
      onPrimaryPressed: _onSubmit,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: SparkColors.title,
          size: 20,
        ),
      ),
      footer: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Text(
          'Back to Log In',
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
          hint: 'Email',
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          errorText: _controller.errors['email'],
          onChanged: _controller.updateEmail,
          onSubmitted: (_) => _onSubmit(),
        ),
      ],
    );
  }
}
