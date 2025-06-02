import 'package:freezed_annotation/freezed_annotation.dart';

part 'grade.freezed.dart';
part 'grade.g.dart';

enum GradeSystem { yds, french, vScale, font }

@freezed
class Grade with _$Grade {
  const Grade._();
  
  const factory Grade({
    required String value,
    required GradeSystem system,
    required int sortOrder,
  }) = _Grade;

  factory Grade.fromJson(Map<String, dynamic> json) => _$GradeFromJson(json);

  // YDS grades
  static const List<String> ydsGrades = [
    '5.0', '5.1', '5.2', '5.3', '5.4', '5.5', '5.6', '5.7', '5.8', '5.9',
    '5.10a', '5.10b', '5.10c', '5.10d',
    '5.11a', '5.11b', '5.11c', '5.11d',
    '5.12a', '5.12b', '5.12c', '5.12d',
    '5.13a', '5.13b', '5.13c', '5.13d',
    '5.14a', '5.14b', '5.14c', '5.14d',
    '5.15a', '5.15b', '5.15c', '5.15d',
  ];

  // V-scale grades
  static const List<String> vScaleGrades = [
    'VB', 'V0', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8',
    'V9', 'V10', 'V11', 'V12', 'V13', 'V14', 'V15', 'V16', 'V17'
  ];

  // French grades
  static const List<String> frenchGrades = [
    '1', '2', '3', '4a', '4b', '4c', '5a', '5b', '5c', '6a', '6a+', '6b', '6b+',
    '6c', '6c+', '7a', '7a+', '7b', '7b+', '7c', '7c+', '8a', '8a+', '8b', '8b+',
    '8c', '8c+', '9a', '9a+', '9b', '9b+', '9c'
  ];

  static Grade? parse(String input) {
    final trimmed = input.trim();
    
    // Check YDS
    if (trimmed.startsWith('5.')) {
      final index = ydsGrades.indexOf(trimmed);
      if (index != -1) {
        return Grade(value: trimmed, system: GradeSystem.yds, sortOrder: index);
      }
    }
    
    // Check V-scale
    if (trimmed.startsWith('V')) {
      final index = vScaleGrades.indexOf(trimmed);
      if (index != -1) {
        return Grade(value: trimmed, system: GradeSystem.vScale, sortOrder: index);
      }
    }
    
    // Check French
    final frenchIndex = frenchGrades.indexOf(trimmed);
    if (frenchIndex != -1) {
      return Grade(value: trimmed, system: GradeSystem.french, sortOrder: frenchIndex);
    }
    
    return null;
  }
}