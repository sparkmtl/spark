import 'package:flutter/material.dart';

import 'models/otp_flow.dart';
import 'theme/spark_theme.dart';
import 'views/create_account_view.dart';
import 'views/forgot_password_view.dart';
import 'views/login_view.dart';
import 'views/new_password_view.dart';
import 'views/verify_otp_view.dart';
import 'views/welcome_view.dart';

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
      home: const LoginView(),
      routes: {
        '/login': (_) => const LoginView(),
        '/create-account': (_) => const CreateAccountView(),
        '/forgot-password': (_) => const ForgotPasswordView(),
        '/welcome': (_) => const WelcomeView(),
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
