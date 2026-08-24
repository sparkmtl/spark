import 'package:flutter/material.dart';

/// Default lifetime for all in-app toast notifications.
const Duration kSparkNotificationDuration = Duration(seconds: 5);

/// Shows a SnackBar that always dismisses after [kSparkNotificationDuration].
void showSparkSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  TextStyle? textStyle,
}) {
  showSparkSnackBarOn(
    ScaffoldMessenger.of(context),
    message,
    backgroundColor: backgroundColor,
    textStyle: textStyle,
  );
}

/// Same as [showSparkSnackBar], but uses a messenger captured before navigation.
void showSparkSnackBarOn(
  ScaffoldMessengerState messenger,
  String message, {
  Color? backgroundColor,
  TextStyle? textStyle,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: textStyle),
        backgroundColor: backgroundColor,
        duration: kSparkNotificationDuration,
      ),
    );
}
