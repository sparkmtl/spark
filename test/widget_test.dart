import 'package:flutter_test/flutter_test.dart';

import 'package:spark/main.dart';

void main() {
  testWidgets('Login screen renders and links to auth flows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SparkApp());
    await tester.pump();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
