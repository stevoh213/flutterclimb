import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:db/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'database_provider.dart';

part 'session_provider.g.dart';

final currentSessionProvider = StreamProvider<Session?>((ref) {
  final dao = ref.watch(sessionDaoProvider);
  return dao.watchCurrentSession();
});

final sessionListProvider = StreamProvider<List<Session>>((ref) {
  final dao = ref.watch(sessionDaoProvider);
  return dao.watchAllSessions();
});

@riverpod
class SessionController extends _$SessionController {
  @override
  FutureOr<void> build() async {
    // Initial state
  }

  Future<Session> startSession({
    required String location,
    bool isOutdoor = false,
    double? latitude,
    double? longitude,
  }) async {
    final dao = ref.read(sessionDaoProvider);
    final uuid = const Uuid();
    
    final companion = SessionsCompanion(
      id: Value(uuid.v4()),
      location: Value(location),
      startTime: Value(DateTime.now()),
      isOutdoor: Value(isOutdoor),
      latitude: Value(latitude),
      longitude: Value(longitude),
    );
    
    await dao.insertSession(companion);
    final session = await dao.getSession(companion.id.value);
    
    if (session == null) {
      throw Exception('Failed to create session');
    }
    
    // Update state to indicate operation completed
    state = const AsyncData(null);
    
    return session;
  }
  
  Future<void> endSession(String sessionId) async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      final dao = ref.read(sessionDaoProvider);
      final session = await dao.getSession(sessionId);
      
      if (session == null) {
        throw Exception('Session not found');
      }
      
      await dao.updateSession(
        session.toCompanion(true).copyWith(
          endTime: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }
}