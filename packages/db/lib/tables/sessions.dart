import 'package:drift/drift.dart';

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get location => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  BoolColumn get isOutdoor => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get climbCount => integer().withDefault(const Constant(0))();
  IntColumn get completedCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {id};
}