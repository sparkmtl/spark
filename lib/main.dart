import 'package:flutter/material.dart';

import 'models/otp_flow.dart';
import 'theme/spark_theme.dart';
import 'views/create_account_view.dart';
import 'views/forgot_password_view.dart';
import 'views/login_view.dart';
import 'views/main_shell_view.dart';
import 'views/new_password_view.dart';
import 'views/verify_otp_view.dart';
import 'views/welcome_view.dart';

/// Phone-sized layout width used across auth and post-login screens.
const double kSparkMobileMaxWidth = 430;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SparkApp());
}

class SparkApp extends StatelessWidget {
  const SparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spark',
      debugShowCheckedModeBanner: false,
      theme: buildSparkTheme(),
      builder: (context, child) => SparkMobileFrame(child: child),
      home: const LoginView(),
      routes: {
        '/login': (_) => const LoginView(),
        '/create-account': (_) => const CreateAccountView(),
        '/forgot-password': (_) => const ForgotPasswordView(),
        '/welcome': (_) => const WelcomeView(),
        '/home': (_) => const MainShellView(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name;
        final args = settings.arguments;

        if (name == '/verify-otp') {
          if (args is Map) {
            final email = args['email'] as String? ?? '';
            final flow = args['flow'] as OtpFlow? ?? OtpFlow.passwordReset;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => VerifyOtpView(email: email, flow: flow),
            );
          }
          final email = args is String ? args : '';
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => VerifyOtpView(email: email),
          );
        }

        if (name == '/new-password') {
          final email = args is String ? args : '';
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => NewPasswordView(email: email),
          );
        }

        return null;
      },
    );
  }
}

/// Centers the app in a mobile-width column on wide viewports (e.g. Chrome).
class SparkMobileFrame extends StatelessWidget {
  const SparkMobileFrame({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final content = child ?? const SizedBox.shrink();

    if (media.size.width <= kSparkMobileMaxWidth) {
      return content;
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: kSparkMobileMaxWidth,
          child: MediaQuery(
            data: media.copyWith(
              size: Size(kSparkMobileMaxWidth, media.size.height),
            ),
            child: ClipRect(child: content),
          ),
        ),
      ),
    );
  }
}
