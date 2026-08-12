class Validators {
  Validators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? maxLength(String? value, int max) {
    if (value != null && value.length > max) return 'Max $max characters allowed.';
    return null;
  }

  static String? futureDateTime(DateTime? value) {
    if (value == null) return 'Please select a date and time.';
    if (value.isBefore(DateTime.now())) return 'Cannot select a past time.';
    return null;
  }
}
