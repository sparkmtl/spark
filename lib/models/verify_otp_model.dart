import 'spark_validators.dart';

class VerifyOtpModel {
  const VerifyOtpModel({
    this.email = '',
    this.otp = '',
  });

  final String email;
  final String otp;

  VerifyOtpModel copyWith({
    String? email,
    String? otp,
  }) {
    return VerifyOtpModel(
      email: email ?? this.email,
      otp: otp ?? this.otp,
    );
  }

  Map<String, String> validate() {
    final errors = <String, String>{};
    final otpError = SparkValidators.otp(otp);
    if (otpError != null) errors['otp'] = otpError;
    return errors;
  }
}
