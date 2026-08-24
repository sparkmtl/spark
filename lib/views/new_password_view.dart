import 'package:flutter/material.dart';

import '../controllers/new_password_controller.dart';
import '../theme/spark_colors.dart';
import '../widgets/spark_auth_scaffold.dart';
import '../widgets/spark_snackbar.dart';
import '../widgets/spark_text_field.dart';
import 'login_view.dart';

class NewPasswordView extends StatefulWidget {
  const NewPasswordView({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<NewPasswordView> createState() => _NewPasswordViewState();
}

class _NewPasswordViewState extends State<NewPasswordView> {
  late final NewPasswordController _controller;
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = NewPasswordController(email: widget.email)..addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onUpdate)
      ..dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_controller.isSubmitting) return;
    FocusScope.of(context).unfocus();
    final ok = await _controller.submit();
    if (!mounted || !ok) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginView()),
      (_) => false,
    );

    showSparkSnackBarOn(
      messenger,
      'Password updated. Please log in.',
      backgroundColor: SparkColors.surfaceElevated,
      textStyle: const TextStyle(color: SparkColors.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SparkAuthScaffold(
      title: 'New Password',
      subtitle: 'Create a new password for ${widget.email}',
      primaryLabel:
          _controller.isSubmitting ? 'Saving...' : 'Update Password',
      onPrimaryPressed: _onSave,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: SparkColors.title,
          size: 20,
        ),
      ),
      children: [
        SparkTextField(
          hint: 'New Password',
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
          onSubmitted: (_) => _onSave(),
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
