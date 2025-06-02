import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

@freezed
class Session with _$Session {
  const Session._();
  
  const factory Session({
    required String id,
    required String location,
    required DateTime startTime,
    DateTime? endTime,
    @Default(false) bool isOutdoor,
    String? notes,
    double? latitude,
    double? longitude,
    @Default(0) int climbCount,
    @Default(0) int completedCount,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

  Duration get duration {
    if (endTime == null) {
      return DateTime.now().difference(startTime);
    }
    return endTime!.difference(startTime);
  }

  double get completionRate {
    if (climbCount == 0) return 0;
    return completedCount / climbCount;
  }
}