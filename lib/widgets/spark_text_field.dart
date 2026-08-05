import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/spark_colors.dart';

class SparkTextField extends StatelessWidget {
  const SparkTextField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onSubmitted,
    this.suffix,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      style: Theme.of(context).textTheme.bodyLarge,
      cursorColor: SparkColors.accent,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        suffixIcon: suffix,
        counterText: '',
        alignLabelWithHint: (maxLines ?? 1) > 1,
      ),
    );
  }
}
