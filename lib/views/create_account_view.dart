import 'package:flutter/material.dart';

import '../controllers/create_account_controller.dart';
import '../models/otp_flow.dart';
import '../theme/spark_colors.dart';
import '../widgets/spark_auth_scaffold.dart';
import '../widgets/spark_text_field.dart';
import 'verify_otp_view.dart';

/// Mobile-first Create Account view (MVC View layer).
class CreateAccountView extends StatefulWidget {
  const CreateAccountView({super.key});

  @override
  State<CreateAccountView> createState() => _CreateAccountViewState();
}

class _CreateAccountViewState extends State<CreateAccountView> {
  late final CreateAccountController _controller;
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = CreateAccountController()..addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerUpdate)
      ..dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (_controller.isSubmitting) return;
    FocusScope.of(context).unfocus();
    final ok = await _controller.submit();
    if (!mounted || !ok) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifyOtpView(
          email: _controller.model.email.trim(),
          flow: OtpFlow.signUp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return SparkAuthScaffold(
      title: 'Create Account',
      subtitle:
          "Enter your details and we'll send a one-time password (OTP) to verify your email.",
      primaryLabel: _controller.isSubmitting ? 'Sending...' : 'Continue',
      onPrimaryPressed: _onContinue,
      leading: canPop
          ? IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: SparkColors.title,
                size: 20,
              ),
            )
          : null,
      footer: canPop
          ? GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Text(
                'Already have an account? Log In',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: SparkColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
              ),
            )
          : null,
      children: [
        SparkTextField(
          hint: 'Name',
          focusNode: _nameFocus,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          errorText: _controller.errors['name'],
          onChanged: _controller.updateName,
          onSubmitted: (_) => _emailFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        SparkTextField(
          hint: 'Email',
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          errorText: _controller.errors['email'],
          onChanged: _controller.updateEmail,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        SparkTextField(
          hint: 'Password',
          focusNode: _passwordFocus,
          obscureText: _controller.obscurePassword,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          errorText: _controller.errors['password'],
          onChanged: _controller.updatePassword,
          onSubmitted: (_) => _confirmFocus.requestFocus(),
          suffix: IconButton(
            onPressed: _controller.toggleObscurePassword,
            icon: Icon(
              _controller.obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: SparkColors.placeholder,
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SparkTextField(
          hint: 'Confirm Password',
          focusNode: _confirmFocus,
          obscureText: _controller.obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          errorText: _controller.errors['confirmPassword'],
          onChanged: _controller.updateConfirmPassword,
          onSubmitted: (_) => _onContinue(),
          suffix: IconButton(
            onPressed: _controller.toggleObscureConfirmPassword,
            icon: Icon(
              _controller.obscureConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: SparkColors.placeholder,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}
