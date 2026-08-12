import 'package:flutter_test/flutter_test.dart';
import 'package:guru_app/core/utils/extensions.dart';
import 'package:guru_app/domain/entities/session_log_entity.dart';

void main() {
  group('SessionLogEntity duration calculation', () {
    final start = DateTime(2026, 8, 11, 10, 0);
    final end = DateTime(2026, 8, 11, 10, 45, 30);
    final log = SessionLogEntity(
      id: 'log_001',
      memberId: 'member_dk',
      trainerId: 'trainer_aarav',
      startedAt: start,
      endedAt: end,
      durationSec: end.difference(start).inSeconds,
    );

    test('duration is correctly calculated', () {
      expect(log.durationSec, 45 * 60 + 30);
    });

    test('formattedDuration renders minutes and seconds', () {
      final formatted = log.durationSec.formattedDuration;
      expect(formatted, '45m 30s');
    });
  });

  group('DurationExt.formattedDuration', () {
    test('seconds only when under 60', () {
      expect(30.formattedDuration, '30s');
    });

    test('minutes only when exact', () {
      expect(120.formattedDuration, '2m');
    });

    test('minutes and seconds', () {
      expect(90.formattedDuration, '1m 30s');
    });
  });
}
