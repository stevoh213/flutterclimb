import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:db/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:core/models/grade.dart';
import 'package:core/models/climb.dart' as core;
import 'database_provider.dart';

part 'climb_provider.g.dart';

final sessionClimbsProvider = StreamProvider.family<List<Climb>, String>((ref, sessionId) {
  final dao = ref.watch(climbDaoProvider);
  return dao.watchClimbsForSession(sessionId);
});

final recentClimbsProvider = StreamProvider<List<Climb>>((ref) {
  final dao = ref.watch(climbDaoProvider);
  return dao.watchRecentClimbs();
});

@riverpod
class ClimbController extends _$ClimbController {
  @override
  FutureOr<void> build() async {
    // Initial state
  }

  Future<Climb> logClimb({
    required String sessionId,
    required Grade grade,
    required core.ClimbStyle style,
    required core.ClimbResult result,
    int attempts = 1,
    String? notes,
    double? rating,
    double? perceivedDifficulty,
  }) async {
    final dao = ref.read(climbDaoProvider);
    final uuid = const Uuid();
    
    final companion = ClimbsCompanion(
      id: Value(uuid.v4()),
      sessionId: Value(sessionId),
      gradeValue: Value(grade.value),
      gradeSystem: Value(grade.system.name),
      gradeSortOrder: Value(grade.sortOrder),
      style: Value(style.name),
      result: Value(result.name),
      timestamp: Value(DateTime.now()),
      attempts: Value(attempts),
      notes: Value(notes),
      rating: Value(rating),
      perceivedDifficulty: Value(perceivedDifficulty),
    );
    
    await dao.insertClimb(companion);
    
    // Update session counts
    await dao.incrementSessionClimbCount(sessionId);
    if (result == core.ClimbResult.flash || 
        result == core.ClimbResult.redpoint || 
        result == core.ClimbResult.onsight) {
      await dao.incrementSessionCompletedCount(sessionId);
    }
    
    // Create a Climb object from the companion data
    final climb = Climb(
      id: companion.id.value,
      sessionId: sessionId,
      gradeValue: grade.value,
      gradeSystem: grade.system.name,
      gradeSortOrder: grade.sortOrder,
      style: style.name,
      result: result.name,
      timestamp: DateTime.now(),
      attempts: attempts,
      notes: notes,
      photos: '[]',
      rating: rating,
      perceivedDifficulty: perceivedDifficulty,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // Update state to indicate operation completed
    state = const AsyncData(null);
    
    return climb;
  }
  
  Future<void> updateClimb(String climbId, {
    Grade? grade,
    core.ClimbStyle? style,
    core.ClimbResult? result,
    int? attempts,
    String? notes,
    double? rating,
    double? perceivedDifficulty,
  }) async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      final dao = ref.read(climbDaoProvider);
      final climb = await (dao.select(dao.climbs)..where((c) => c.id.equals(climbId))).getSingleOrNull();
      
      if (climb == null) {
        throw Exception('Climb not found');
      }
      
      await dao.updateClimb(
        climb.toCompanion(true).copyWith(
          gradeValue: grade != null ? Value(grade.value) : const Value.absent(),
          gradeSystem: grade != null ? Value(grade.system.name) : const Value.absent(),
          gradeSortOrder: grade != null ? Value(grade.sortOrder) : const Value.absent(),
          style: style != null ? Value(style.name) : const Value.absent(),
          result: result != null ? Value(result.name) : const Value.absent(),
          attempts: attempts != null ? Value(attempts) : const Value.absent(),
          notes: notes != null ? Value(notes) : const Value.absent(),
          rating: rating != null ? Value(rating) : const Value.absent(),
          perceivedDifficulty: perceivedDifficulty != null ? Value(perceivedDifficulty) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }
  
  Future<void> deleteClimb(String climbId) async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      final dao = ref.read(climbDaoProvider);
      await dao.deleteClimb(climbId);
    });
  }
}