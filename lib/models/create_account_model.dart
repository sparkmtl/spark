import 'spark_validators.dart';

class CreateAccountModel {
  const CreateAccountModel({
    this.name = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
  });

  final String name;
  final String email;
  final String password;
  final String confirmPassword;

  CreateAccountModel copyWith({
    String? name,
    String? email,
    String? password,
    String? confirmPassword,
  }) {
    return CreateAccountModel(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
    );
  }

  Map<String, String> validate() {
    final errors = <String, String>{};

    if (name.trim().isEmpty) {
      errors['name'] = 'Name is required';
    } else if (name.trim().length < 3) {
      errors['name'] = 'Name must be at least 3 characters';
    } else if (name.trim().length > 50) {
      errors['name'] = 'Name must be at most 50 characters';
    }

    final emailError = SparkValidators.email(email);
    if (emailError != null) errors['email'] = emailError;

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
