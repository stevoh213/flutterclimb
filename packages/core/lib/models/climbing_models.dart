// Core Climbing Data Models
// Modular, context-free models following design principles

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'climbing_models.freezed.dart';
part 'climbing_models.g.dart';

/// Session status enumeration
enum SessionStatus {
  @JsonValue('active')
  active,
  @JsonValue('paused')
  paused,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

/// Sync status for offline-first architecture
enum SyncStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('synced')
  synced,
  @JsonValue('error')
  error,
  @JsonValue('conflict')
  conflict,
}

/// Climbing styles
enum ClimbingStyle {
  @JsonValue('lead')
  lead,
  @JsonValue('toprope')
  toprope,
  @JsonValue('boulder')
  boulder,
  @JsonValue('aid')
  aid,
  @JsonValue('solo')
  solo,
}

/// Location types
enum LocationType {
  @JsonValue('gym')
  gym,
  @JsonValue('outdoor')
  outdoor,
}

/// Climb results
enum ClimbResult {
  @JsonValue('flash')
  flash,
  @JsonValue('onsight')
  onsight,
  @JsonValue('redpoint')
  redpoint,
  @JsonValue('attempt')
  attempt,
  @JsonValue('project')
  project,
}

/// Grade systems
enum GradeSystem {
  @JsonValue('YDS')
  yds,
  @JsonValue('French')
  french,
  @JsonValue('V-Scale')
  vScale,
  @JsonValue('UIAA')
  uiaa,
}

/// Device types for context tracking
enum DeviceType {
  @JsonValue('ios')
  ios,
  @JsonValue('android')
  android,
  @JsonValue('web')
  web,
}

/// Core user profile model
@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String email,
    String? fullName,
    String? avatarUrl,
    @Default(ClimbingStyle.lead) ClimbingStyle climbingStylePreference,
    @Default(GradeSystem.yds) GradeSystem preferredGradeSystem,
    @Default(false) bool profilePublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

/// User preferences model
@freezed
class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    required String id,
    required String userId,
    
    // App preferences
    String? defaultLocation,
    @Default(false) bool autoStartSession,
    @Default(true) bool voiceLoggingEnabled,
    
    // Notification preferences
    @Default(true) bool sessionReminders,
    @Default(true) bool goalReminders,
    @Default(true) bool weeklySummary,
    
    // Privacy preferences
    @Default(false) bool profilePublic,
    @Default(false) bool shareSessions,
    
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
}

/// Location model for gyms and crags
@freezed
class ClimbingLocation with _$ClimbingLocation {
  const factory ClimbingLocation({
    required String id,
    required String name,
    required LocationType type,
    String? address,
    String? website,
    String? phone,
    String? description,
    
    // Climbing specific data
    @Default(0) int routeCount,
    String? gradeRangeMin,
    String? gradeRangeMax,
    @Default(<ClimbingStyle>[]) List<ClimbingStyle> styles,
    
    // Metadata
    @Default(false) bool verified,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    
    // Coordinates
    double? latitude,
    double? longitude,
  }) = _ClimbingLocation;

  factory ClimbingLocation.fromJson(Map<String, dynamic> json) =>
      _$ClimbingLocationFromJson(json);
}

/// Session model for tracking climbing sessions
@freezed
class ClimbingSession with _$ClimbingSession {
  const factory ClimbingSession({
    required String id,
    required String userId,
    required DateTime startTime,
    DateTime? endTime,
    required String locationName,
    required LocationType locationType,
    String? locationId,
    String? notes,
    
    // Status and sync
    @Default(SessionStatus.active) SessionStatus status,
    @Default(SyncStatus.pending) SyncStatus syncStatus,
    
    // Metadata
    Map<String, dynamic>? weatherConditions,
    Map<String, dynamic>? deviceInfo,
    String? appVersion,
    
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ClimbingSession;

  factory ClimbingSession.fromJson(Map<String, dynamic> json) =>
      _$ClimbingSessionFromJson(json);
      
  // Computed properties
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }
  
  bool get isActive => status == SessionStatus.active;
  bool get isCompleted => status == SessionStatus.completed;
}

/// Individual climb record
@freezed
class ClimbRecord with _$ClimbRecord {
  const factory ClimbRecord({
    required String id,
    required String sessionId,
    required String userId,
    @Default(1) int sequenceNumber,
    
    // Route information
    String? routeName,
    String? routeColor,
    String? routeSetter,
    String? externalRouteId,
    
    // Climb details
    required String grade,
    @Default(GradeSystem.yds) GradeSystem gradeSystem,
    required ClimbingStyle style,
    @Default(1) int attempts,
    required ClimbResult result,
    
    // Performance metrics
    int? qualityRating, // 1-5
    int? difficultyPerception, // 1-5
    @Default(0) int fallCount,
    @Default(0) int restCount,
    int? routeLength,
    
    // Additional assessments
    int? holdsQuality, // 1-5
    int? movementQuality, // 1-5
    String? perceivedGrade,
    String? comparativeDifficulty, // 'soft', 'accurate', 'stiff'
    
    // Notes and media
    String? notes,
    String? betaNotes,
    @Default(<String>[]) List<String> photos,
    @Default(<String>[]) List<String> videos,
    
    // Timing
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    
    // Metadata
    @Default('manual') String inputMethod, // 'manual', 'voice', 'photo', 'bulk'
    @Default(1.0) double confidenceScore, // For AI-parsed data
    @Default(SyncStatus.pending) SyncStatus syncStatus,
    
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ClimbRecord;

  factory ClimbRecord.fromJson(Map<String, dynamic> json) =>
      _$ClimbRecordFromJson(json);
      
  // Computed properties
  bool get isSuccessful => 
      result == ClimbResult.flash || 
      result == ClimbResult.onsight || 
      result == ClimbResult.redpoint;
      
  bool get isProject => result == ClimbResult.project;
  bool get isAttempt => result == ClimbResult.attempt;
  
  Duration? get duration {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!);
  }
}

/// Goal tracking model
@freezed
class ClimbingGoal with _$ClimbingGoal {
  const factory ClimbingGoal({
    required String id,
    required String userId,
    required String title,
    String? description,
    String? targetGrade,
    DateTime? targetDate,
    required String goalType, // 'grade', 'volume', 'style', 'route'
    @Default('active') String status, // 'active', 'completed', 'paused', 'cancelled'
    @Default(0) int progressPercentage,
    
    // Associated data
    Map<String, dynamic>? criteria, // Specific goal criteria
    Map<String, dynamic>? metadata, // Additional goal data
    
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ClimbingGoal;

  factory ClimbingGoal.fromJson(Map<String, dynamic> json) =>
      _$ClimbingGoalFromJson(json);
      
  // Computed properties
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isPaused => status == 'paused';
  
  double get progressDecimal => progressPercentage / 100.0;
}

/// Media attachment model
@freezed
class MediaAttachment with _$MediaAttachment {
  const factory MediaAttachment({
    required String id,
    String? climbId,
    String? sessionId,
    required String userId,
    
    // Media details
    required String type, // 'photo', 'video', 'audio'
    required String filePath,
    int? fileSize,
    String? mimeType,
    int? duration, // For video/audio in seconds
    int? width, // For images/video
    int? height, // For images/video
    
    // Upload tracking
    @Default(SyncStatus.pending) SyncStatus uploadStatus,
    @Default(0) int uploadAttempts,
    DateTime? lastUploadAttempt,
    String? uploadError,
    
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _MediaAttachment;

  factory MediaAttachment.fromJson(Map<String, dynamic> json) =>
      _$MediaAttachmentFromJson(json);
      
  // Computed properties
  bool get isUploaded => uploadStatus == SyncStatus.synced;
  bool get hasFailed => uploadStatus == SyncStatus.error;
  bool get isImage => type == 'photo';
  bool get isVideo => type == 'video';
}

/// Route information model
@freezed
class RouteInfo with _$RouteInfo {
  const factory RouteInfo({
    required String id,
    String? locationId,
    
    // Route details
    required String name,
    required String grade,
    required GradeSystem gradeSystem,
    required ClimbingStyle style,
    int? length, // Length in feet/meters
    @Default(1) int pitches,
    
    // Route characteristics
    String? color,
    String? setter,
    String? section, // Wall section or crag area
    String? description,
    String? betaNotes,
    DateTime? firstAscentDate,
    String? firstAscentBy,
    
    // External references
    Map<String, dynamic>? externalIds, // {mountain_project: "id", 8a_nu: "id"}
    
    // Aggregated data
    double? avgRating,
    @Default(0) int totalAscents,
    
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _RouteInfo;

  factory RouteInfo.fromJson(Map<String, dynamic> json) =>
      _$RouteInfoFromJson(json);
}

/// Sync queue item for offline operations
@freezed
class SyncQueueItem with _$SyncQueueItem {
  const factory SyncQueueItem({
    required String id,
    required String userId,
    
    // Sync details
    required String entityType, // 'session', 'climb', 'media', etc.
    required String entityId,
    required String operation, // 'create', 'update', 'delete'
    Map<String, dynamic>? data,
    
    // Retry logic
    @Default(0) int attempts,
    @Default(5) int maxAttempts,
    DateTime? nextRetry,
    String? lastError,
    
    // Priority and batching
    @Default(1) int priority, // Higher = more important
    String? batchId,
    
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _SyncQueueItem;

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) =>
      _$SyncQueueItemFromJson(json);
      
  // Computed properties
  bool get canRetry => attempts < maxAttempts;
  bool get shouldRetry => canRetry && 
      (nextRetry == null || DateTime.now().isAfter(nextRetry!));
  bool get hasFailed => attempts >= maxAttempts;
}

/// Performance metrics model
@freezed
class PerformanceMetric with _$PerformanceMetric {
  const factory PerformanceMetric({
    required String id,
    String? userId,
    
    // Metrics
    required String metricType, // 'session_duration', 'sync_time', 'load_time', etc.
    double? value,
    String? unit,
    Map<String, dynamic>? context,
    
    DateTime? createdAt,
  }) = _PerformanceMetric;

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) =>
      _$PerformanceMetricFromJson(json);
}

/// Training plan model
@freezed
class TrainingPlan with _$TrainingPlan {
  const factory TrainingPlan({
    required String id,
    required String userId,
    String? goalId,
    
    // Plan details
    required String name,
    String? description,
    int? durationWeeks,
    int? difficultyLevel, // 1-5
    
    // Plan structure
    required Map<String, dynamic> planData, // Detailed weekly/daily structure
    
    // Progress tracking
    @Default('active') String status, // 'active', 'completed', 'paused', 'cancelled'
    @Default(1) int currentWeek,
    @Default(0) int completionPercentage,
    
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TrainingPlan;

  factory TrainingPlan.fromJson(Map<String, dynamic> json) =>
      _$TrainingPlanFromJson(json);
      
  // Computed properties
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  double get progressDecimal => completionPercentage / 100.0;
} 