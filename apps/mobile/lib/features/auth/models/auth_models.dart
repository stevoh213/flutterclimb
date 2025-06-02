import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

@freezed
class AppAuthState with _$AppAuthState {
  const factory AppAuthState({
    @JsonKey(includeFromJson: false, includeToJson: false) User? user,
    @JsonKey(includeFromJson: false, includeToJson: false) Session? session,
    @Default(false) bool loading,
    String? error,
  }) = _AppAuthState;
  
  factory AppAuthState.fromJson(Map<String, dynamic> json) => _$AppAuthStateFromJson(json);
}

@freezed
class AuthCredentials with _$AuthCredentials {
  const factory AuthCredentials({
    required String email,
    required String password,
    String? fullName,
  }) = _AuthCredentials;
  
  factory AuthCredentials.fromJson(Map<String, dynamic> json) => _$AuthCredentialsFromJson(json);
}

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String email,
    String? fullName,
    String? avatarUrl,
    String? climbingStylePreference,
    String? preferredGradeSystem,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserProfile;
  
  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
}

enum ClimbingStyle {
  lead,
  toprope,
  boulder,
  aid,
  solo,
}

enum GradeSystem {
  yds,
  french,
  vScale,
  uiaa,
}

class AppAuthException implements Exception {
  final String message;
  final String? code;
  
  const AppAuthException(this.message, [this.code]);
  
  @override
  String toString() => 'AppAuthException: $message${code != null ? ' (Code: $code)' : ''}';
} 