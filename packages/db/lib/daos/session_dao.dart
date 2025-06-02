import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/sessions.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [Sessions])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(AppDatabase db) : super(db);

  Future<List<Session>> getAllSessions() => select(sessions).get();
  
  Stream<List<Session>> watchAllSessions() => select(sessions).watch();
  
  Future<Session?> getSession(String id) => 
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();
  
  Stream<Session?> watchSession(String id) => 
      (select(sessions)..where((s) => s.id.equals(id))).watchSingleOrNull();
  
  Future<Session?> getCurrentSession() => 
      (select(sessions)
        ..where((s) => s.endTime.isNull())
        ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
        ..limit(1))
      .getSingleOrNull();
  
  Stream<Session?> watchCurrentSession() => 
      (select(sessions)
        ..where((s) => s.endTime.isNull())
        ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
        ..limit(1))
      .watchSingleOrNull();
  
  Future<int> insertSession(SessionsCompanion session) => 
      into(sessions).insert(session);
  
  Future<bool> updateSession(SessionsCompanion session) => 
      update(sessions).replace(session);
  
  Future<int> deleteSession(String id) => 
      (delete(sessions)..where((s) => s.id.equals(id))).go();
}