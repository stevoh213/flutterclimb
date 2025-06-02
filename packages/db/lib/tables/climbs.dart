import 'package:drift/drift.dart';
import 'sessions.dart';

class Climbs extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get gradeValue => text()();
  TextColumn get gradeSystem => text()();
  IntColumn get gradeSortOrder => integer()();
  TextColumn get style => text()();
  TextColumn get result => text()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(1))();
  TextColumn get notes => text().nullable()();
  TextColumn get photos => text().withDefault(const Constant('[]'))(); // JSON array
  RealColumn get rating => real().nullable()();
  RealColumn get perceivedDifficulty => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {id};
}