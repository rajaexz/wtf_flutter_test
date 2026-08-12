import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }

  String get chatTimestamp {
    if (isToday) return DateFormat('HH:mm').format(this);
    if (isTomorrow) return 'Tomorrow';
    return DateFormat('MMM d').format(this);
  }

  String get fullDateTime => DateFormat('MMM d, yyyy • HH:mm').format(this);
  String get shortDate => DateFormat('MMM d').format(this);
  String get timeOnly => DateFormat('HH:mm').format(this);
  String get dayName => DateFormat('EEEE').format(this);
}

extension StringExt on String {
  bool get isBlank => trim().isEmpty;
  String get capitalised => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension DurationExt on int {
  String get formattedDuration {
    final m = this ~/ 60;
    final s = this % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }
}
