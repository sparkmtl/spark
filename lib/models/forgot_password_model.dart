import 'spark_validators.dart';

class ForgotPasswordModel {
  const ForgotPasswordModel({this.email = ''});

  final String email;

  ForgotPasswordModel copyWith({String? email}) {
    return ForgotPasswordModel(email: email ?? this.email);
  }

  Map<String, String> validate() {
    final errors = <String, String>{};
    final emailError = SparkValidators.email(email);
    if (emailError != null) errors['email'] = emailError;
    return errors;
  }
}
