import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/spark_colors.dart';
import '../widgets/spark_logo.dart';

/// Temporary post-login demo screen.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final textTheme = Theme.of(context).textTheme;
    final horizontal = media.size.width >= 480 ? 40.0 : 24.0;
    final compact = media.size.height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: SparkColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SparkLogo(size: compact ? 88 : 112),
                    SizedBox(height: compact ? 28 : 36),
                    Text(
                      'Welcome to Spark',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineLarge?.copyWith(
                        fontSize: media.size.width < 360 ? 28 : 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are signed in. More is on the way.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: SparkColors.placeholder,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
