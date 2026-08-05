import 'package:flutter/material.dart';

import '../controllers/login_controller.dart';
import '../theme/spark_colors.dart';
import '../widgets/spark_auth_scaffold.dart';
import '../widgets/spark_text_field.dart';
import 'create_account_view.dart';
import 'forgot_password_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final LoginController _controller;
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = LoginController()..addListener(_onUpdate);
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
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_controller.isSubmitting) return;
    FocusScope.of(context).unfocus();
    final ok = await _controller.submit();
    if (!mounted || !ok) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  void _goForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordView()),
    );
  }

  void _goCreateAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateAccountView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SparkAuthScaffold(
      title: 'Welcome Back',
      primaryLabel: _controller.isSubmitting ? 'Logging in...' : 'Log In',
      onPrimaryPressed: _onLogin,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: SparkColors.placeholder,
                  fontSize: 14,
                ),
          ),
          GestureDetector(
            onTap: _goCreateAccount,
            child: const Text(
              'Create Account',
              style: TextStyle(
                color: SparkColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      children: [
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
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          errorText: _controller.errors['password'],
          onChanged: _controller.updatePassword,
          onSubmitted: (_) => _onLogin(),
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _goForgotPassword,
            style: TextButton.styleFrom(
              foregroundColor: SparkColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
