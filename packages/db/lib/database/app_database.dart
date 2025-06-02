import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../tables/sessions.dart';
import '../tables/climbs.dart';
import '../daos/session_dao.dart';
import '../daos/climb_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Sessions, Climbs], daos: [SessionDao, ClimbDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'climbing_logbook_db');
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Handle future migrations here
    },
  );
}