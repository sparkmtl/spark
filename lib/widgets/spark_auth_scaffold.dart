import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/spark_colors.dart';
import 'spark_logo.dart';

/// Shared mobile auth chrome: logo, title, scrollable body, bottom CTA.
class SparkAuthScaffold extends StatelessWidget {
  const SparkAuthScaffold({
    super.key,
    required this.title,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.subtitle,
    this.footer,
    this.leading,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final Widget? footer;
  final Widget? leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = media.viewInsets.bottom;
    final horizontal = media.size.width >= 480 ? 40.0 : 24.0;
    final compact = media.size.height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: SparkColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 16),
                child: Column(
                  children: [
                    if (leading != null) ...[
                      Align(alignment: Alignment.centerLeft, child: leading!),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: bottomInset > 0 ? 12 : 0,
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: compact ? 16 : 36),
                            SparkLogo(size: compact ? 72 : 88),
                            const SizedBox(height: 28),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineLarge?.copyWith(
                                fontSize: media.size.width < 360 ? 28 : 32,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: SparkColors.placeholder,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            ...children,
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onPrimaryPressed,
                        child: Text(primaryLabel),
                      ),
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: 16),
                      footer!,
                    ],
                    SizedBox(height: media.padding.bottom > 0 ? 8 : 16),
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
