import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local_storage.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/call_request_repository_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/session_log_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/call_request_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/session_log_repository.dart';

final localStorageProvider = Provider<LocalStorage>((ref) => LocalStorage());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.read(localStorageProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(ref.read(localStorageProvider)),
);

final callRequestRepositoryProvider = Provider<CallRequestRepository>(
  (ref) => CallRequestRepositoryImpl(ref.read(localStorageProvider)),
);

final sessionLogRepositoryProvider = Provider<SessionLogRepository>(
  (ref) => SessionLogRepositoryImpl(ref.read(localStorageProvider)),
);
