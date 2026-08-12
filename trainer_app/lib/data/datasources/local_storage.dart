import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static const String _messagesBox = 'messages';
  static const String _callRequestsBox = 'call_requests';
  static const String _sessionLogsBox = 'session_logs';
  static const String _roomMetaBox = 'room_meta';
  static const String _userBox = 'user';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_messagesBox);
    await Hive.openBox<String>(_callRequestsBox);
    await Hive.openBox<String>(_sessionLogsBox);
    await Hive.openBox<String>(_roomMetaBox);
    await Hive.openBox<String>(_userBox);
  }

  Box<String> get messages => Hive.box<String>(_messagesBox);
  Box<String> get callRequests => Hive.box<String>(_callRequestsBox);
  Box<String> get sessionLogs => Hive.box<String>(_sessionLogsBox);
  Box<String> get roomMeta => Hive.box<String>(_roomMetaBox);
  Box<String> get user => Hive.box<String>(_userBox);

  Future<void> put(Box<String> box, String key, Map<String, dynamic> value) async {
    await box.put(key, jsonEncode(value));
  }

  Map<String, dynamic>? get(Box<String> box, String key) {
    final raw = box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> getAll(Box<String> box) {
    return box.values.map((v) => jsonDecode(v) as Map<String, dynamic>).toList();
  }
}
