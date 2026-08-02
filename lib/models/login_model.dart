import 'spark_validators.dart';

class LoginModel {
  const LoginModel({
    this.email = '',
    this.password = '',
  });

  final String email;
  final String password;

  LoginModel copyWith({
    String? email,
    String? password,
  }) {
    return LoginModel(
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  Map<String, String> validate() {
    final errors = <String, String>{};
    final emailError = SparkValidators.email(email);
    final passwordError = SparkValidators.password(password);
    if (emailError != null) errors['email'] = emailError;
    if (passwordError != null) errors['password'] = passwordError;
    return errors;
  }
}
