/// In-memory signup draft until register completes.
class SignupSession {
  SignupSession._();
  static final SignupSession instance = SignupSession._();

  String? name;
  String? email;
  String? password;
  bool verified = false;

  bool get hasDraft =>
      name != null && email != null && password != null;

  void start({
    required String name,
    required String email,
    required String password,
  }) {
    this.name = name.trim();
    this.email = email.trim();
    this.password = password;
    verified = false;
  }

  void clear() {
    name = null;
    email = null;
    password = null;
    verified = false;
  }
}
