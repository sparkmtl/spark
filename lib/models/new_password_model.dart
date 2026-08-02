import 'spark_validators.dart';

class NewPasswordModel {
  const NewPasswordModel({
    this.password = '',
    this.confirmPassword = '',
  });

  final String password;
  final String confirmPassword;

  NewPasswordModel copyWith({
    String? password,
    String? confirmPassword,
  }) {
    return NewPasswordModel(
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
    );
  }

  Map<String, String> validate() {
    final errors = <String, String>{};

    final passwordError = SparkValidators.password(password);
    if (passwordError != null) errors['password'] = passwordError;

    if (confirmPassword.isEmpty) {
      errors['confirmPassword'] = 'Confirm your password';
    } else if (confirmPassword != password) {
      errors['confirmPassword'] = 'Passwords do not match';
    }

    return errors;
  }
}
