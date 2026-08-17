/// Service abstractions used by both apps (implemented in each app's data layer).
abstract class AuthService {
  Future<dynamic> getCurrentUser();
  Future<void> saveUser(dynamic user);
  Future<void> clearUser();
}

abstract class ChatService {
  Stream<List<dynamic>> watchMessages(String chatId);
  Future<void> sendMessage(dynamic message);
  Future<void> markAsRead(String chatId, String currentUserId);
}

abstract class CallService {
  Future<void> joinRoom({required String callRequestId, bool micEnabled, bool camEnabled});
  Future<void> toggleMute();
  Future<void> toggleVideo();
  Future<void> switchCamera();
  Future<void> endCall(String callRequestId);
}

abstract class LogService {
  Future<void> saveLog(dynamic log);
  Future<List<dynamic>> getLogs(String userId);
  Future<void> updateLog(dynamic log);
}
