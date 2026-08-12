import 'package:flutter_test/flutter_test.dart';
import 'package:guru_app/core/utils/validators.dart';

void main() {
  group('Validators.futureDateTime', () {
    test('returns error for past date', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final result = Validators.futureDateTime(past);
      expect(result, isNotNull);
    });

    test('returns null for future date', () {
      final future = DateTime.now().add(const Duration(hours: 2));
      final result = Validators.futureDateTime(future);
      expect(result, isNull);
    });

    test('returns error for null', () {
      final result = Validators.futureDateTime(null);
      expect(result, isNotNull);
    });
  });

  group('Validators.maxLength', () {
    test('returns error when over limit', () {
      final result = Validators.maxLength('a' * 141, 140);
      expect(result, isNotNull);
    });

    test('returns null when within limit', () {
      final result = Validators.maxLength('hello', 140);
      expect(result, isNull);
    });
  });
}
