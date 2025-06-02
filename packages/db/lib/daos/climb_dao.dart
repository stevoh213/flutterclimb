import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../tables/climbs.dart';
import '../tables/sessions.dart';

part 'climb_dao.g.dart';

@DriftAccessor(tables: [Climbs, Sessions])
class ClimbDao extends DatabaseAccessor<AppDatabase> with _$ClimbDaoMixin {
  ClimbDao(AppDatabase db) : super(db);

  Future<List<Climb>> getClimbsForSession(String sessionId) =>
      (select(climbs)..where((c) => c.sessionId.equals(sessionId))).get();

  Stream<List<Climb>> watchClimbsForSession(String sessionId) =>
      (select(climbs)..where((c) => c.sessionId.equals(sessionId))).watch();

  Future<List<Climb>> getRecentClimbs({int limit = 20}) =>
      (select(climbs)
            ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
            ..limit(limit))
          .get();

  Stream<List<Climb>> watchRecentClimbs({int limit = 20}) =>
      (select(climbs)
            ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
            ..limit(limit))
          .watch();

  Future<int> insertClimb(ClimbsCompanion climb) => into(climbs).insert(climb);

  Future<bool> updateClimb(ClimbsCompanion climb) =>
      update(climbs).replace(climb);

  Future<int> deleteClimb(String id) =>
      (delete(climbs)..where((c) => c.id.equals(id))).go();

  Future<void> incrementSessionClimbCount(String sessionId) async {
    final session = await db.sessionDao.getSession(sessionId);
    if (session != null) {
      await db.sessionDao.updateSession(
        session.toCompanion(true).copyWith(
          climbCount: Value(session.climbCount + 1),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> incrementSessionCompletedCount(String sessionId) async {
    final session = await db.sessionDao.getSession(sessionId);
    if (session != null) {
      await db.sessionDao.updateSession(
        session.toCompanion(true).copyWith(
          completedCount: Value(session.completedCount + 1),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}