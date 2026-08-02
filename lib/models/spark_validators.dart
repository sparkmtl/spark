abstract final class SparkValidators {
  static final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp otpPattern = RegExp(r'^\d{6}$');

  static String? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email is required';
    if (!emailPattern.hasMatch(trimmed)) return 'Enter a valid email';
    return null;
  }

  static String? password(String value, {int minLength = 8}) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < minLength) {
      return 'Use at least $minLength characters';
    }
    return null;
  }

  static String? otp(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'OTP is required';
    if (!otpPattern.hasMatch(trimmed)) return 'Enter the 6-digit OTP';
    return null;
  }
}
