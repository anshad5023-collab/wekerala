class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'login_invalid_phone';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'login_invalid_phone';
    return null;
  }
}
