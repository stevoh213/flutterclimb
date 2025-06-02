import 'package:freezed_annotation/freezed_annotation.dart';
import 'grade.dart';

part 'climb.freezed.dart';
part 'climb.g.dart';

enum ClimbStyle { sport, trad, boulder, topRope }

enum ClimbResult { flash, redpoint, onsight, attempt, project }

@freezed
class Climb with _$Climb {
  const factory Climb({
    required String id,
    required String sessionId,
    required Grade grade,
    required ClimbStyle style,
    required ClimbResult result,
    required DateTime timestamp,
    @Default(1) int attempts,
    String? notes,
    @Default([]) List<String> photos,
    double? rating,
    double? perceivedDifficulty,
  }) = _Climb;

  factory Climb.fromJson(Map<String, dynamic> json) => _$ClimbFromJson(json);
}