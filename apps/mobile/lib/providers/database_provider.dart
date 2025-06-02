import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:db/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final sessionDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).sessionDao;
});

final climbDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).climbDao;
});