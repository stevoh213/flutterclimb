// Climb Logging Service
// Modular service for climb data collection and management

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/climbing_models.dart';
import '../monitoring/sentry_config.dart';
import '../validation/validation_service.dart';
import '../auth/auth_service.dart';
import 'session_service.dart';

/// Climb logging modes
enum LoggingMode {
  quick,    // Minimal data entry
  standard, // Standard climb logging
  detailed, // Comprehensive logging
  voice,    // Voice-assisted logging
}

/// Quick climb logging parameters
class QuickClimbParams {
  final String grade;
  final GradeSystem gradeSystem;
  final ClimbingStyle style;
  final ClimbResult result;
  final int attempts;
  
  const QuickClimbParams({
    required this.grade,
    required this.gradeSystem,
    required this.style,
    required this.result,
    this.attempts = 1,
  });
}

/// Standard climb logging parameters
class StandardClimbParams {
  final String grade;
  final GradeSystem gradeSystem;
  final ClimbingStyle style;
  final ClimbResult result;
  final int attempts;
  final String? routeName;
  final String? routeId;
  final int? fallCount;
  final int? restCount;
  final int? qualityRating;
  final String? notes;
  
  const StandardClimbParams({
    required this.grade,
    required this.gradeSystem,
    required this.style,
    required this.result,
    this.attempts = 1,
    this.routeName,
    this.routeId,
    this.fallCount,
    this.restCount,
    this.qualityRating,
    this.notes,
  });
}

/// Detailed climb logging parameters
class DetailedClimbParams {
  final String grade;
  final GradeSystem gradeSystem;
  final ClimbingStyle style;
  final ClimbResult result;
  final int attempts;
  final String? routeName;
  final String? routeId;
  final int? fallCount;
  final int? restCount;
  final int? qualityRating;
  final int? difficultyPerception;
  final int? holdsQuality;
  final int? movementQuality;
  final int? routeLength;
  final int? durationSeconds;
  final String? notes;
  final String? betaNotes;
  final List<String>? tags;
  final Map<String, dynamic>? techniques;
  final Map<String, dynamic>? conditions;
  
  const DetailedClimbParams({
    required this.grade,
    required this.gradeSystem,
    required this.style,
    required this.result,
    this.attempts = 1,
    this.routeName,
    this.routeId,
    this.fallCount,
    this.restCount,
    this.qualityRating,
    this.difficultyPerception,
    this.holdsQuality,
    this.movementQuality,
    this.routeLength,
    this.durationSeconds,
    this.notes,
    this.betaNotes,
    this.tags,
    this.techniques,
    this.conditions,
  });
}

/// Climb editing parameters
class ClimbEditParams {
  final String? grade;
  final GradeSystem? gradeSystem;
  final ClimbingStyle? style;
  final ClimbResult? result;
  final int? attempts;
  final String? routeName;
  final String? routeId;
  final int? fallCount;
  final int? restCount;
  final int? qualityRating;
  final int? difficultyPerception;
  final int? holdsQuality;
  final int? movementQuality;
  final int? routeLength;
  final int? durationSeconds;
  final String? notes;
  final String? betaNotes;
  final List<String>? tags;
  
  const ClimbEditParams({
    this.grade,
    this.gradeSystem,
    this.style,
    this.result,
    this.attempts,
    this.routeName,
    this.routeId,
    this.fallCount,
    this.restCount,
    this.qualityRating,
    this.difficultyPerception,
    this.holdsQuality,
    this.movementQuality,
    this.routeLength,
    this.durationSeconds,
    this.notes,
    this.betaNotes,
    this.tags,
  });
}

/// Climb template for quick logging
class ClimbTemplate {
  final String id;
  final String name;
  final ClimbingStyle style;
  final GradeSystem gradeSystem;
  final String? defaultGrade;
  final Map<String, dynamic> defaultValues;
  final bool isUserCreated;
  
  const ClimbTemplate({
    required this.id,
    required this.name,
    required this.style,
    required this.gradeSystem,
    this.defaultGrade,
    this.defaultValues = const {},
    this.isUserCreated = false,
  });
}

/// Climb logging suggestions
class LoggingSuggestions {
  final List<String> recentGrades;
  final List<String> recentRoutes;
  final List<ClimbTemplate> templates;
  final Map<ClimbingStyle, List<String>> styleGrades;
  final List<String> commonTags;
  
  const LoggingSuggestions({
    required this.recentGrades,
    required this.recentRoutes,
    required this.templates,
    required this.styleGrades,
    required this.commonTags,
  });
}

/// Climb logging service
class ClimbLoggingService {
  static ClimbLoggingService? _instance;
  static ClimbLoggingService get instance => _instance ??= ClimbLoggingService._();
  ClimbLoggingService._();
  
  // Current state
  LoggingMode _currentMode = LoggingMode.standard;
  ClimbRecord? _currentDraft;
  List<ClimbTemplate> _userTemplates = [];
  
  // Event streams
  final _climbController = StreamController<ClimbRecord>.broadcast();
  final _modeController = StreamController<LoggingMode>.broadcast();
  final _suggestionsController = StreamController<LoggingSuggestions>.broadcast();
  
  // Configuration
  static const int maxRecentGrades = 10;
  static const int maxRecentRoutes = 20;
  static const Duration draftSaveInterval = Duration(seconds: 30);
  
  // Timer for draft saving
  Timer? _draftTimer;
  
  /// Current logging mode
  LoggingMode get currentMode => _currentMode;
  
  /// Current draft climb
  ClimbRecord? get currentDraft => _currentDraft;
  
  /// User templates
  List<ClimbTemplate> get userTemplates => List.unmodifiable(_userTemplates);
  
  /// Climb logging events stream
  Stream<ClimbRecord> get climbEvents => _climbController.stream;
  
  /// Mode changes stream
  Stream<LoggingMode> get modeChanges => _modeController.stream;
  
  /// Suggestions updates stream
  Stream<LoggingSuggestions> get suggestionsUpdates => _suggestionsController.stream;
  
  /// Initialize climb logging service
  Future<void> initialize() async {
    try {
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Initializing climb logging service',
        category: 'climb_logging',
      );
      
      // Load user templates
      await _loadUserTemplates();
      
      // Generate initial suggestions
      await _updateSuggestions();
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'logging_init',
      );
    }
  }
  
  /// Set logging mode
  void setLoggingMode(LoggingMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _modeController.add(mode);
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Logging mode changed',
        category: 'climb_logging',
        data: {'mode': mode.name},
      );
    }
  }
  
  /// Log a quick climb
  Future<ClimbRecord?> logQuickClimb(QuickClimbParams params) async {
    try {
      if (!SessionService.instance.isActive) {
        throw Exception('No active session for logging climb');
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Logging quick climb',
        category: 'climb_logging',
        data: {
          'grade': params.grade,
          'style': params.style.name,
          'result': params.result.name,
        },
      );
      
      // Create climb record
      final climb = ClimbRecord(
        id: _generateClimbId(),
        sessionId: SessionService.instance.currentSession!.id,
        userId: AuthService.instance.currentUser!.id,
        grade: params.grade,
        gradeSystem: params.gradeSystem,
        style: params.style,
        result: params.result,
        attempts: params.attempts,
        sequenceNumber: SessionService.instance.currentClimbs.length + 1,
        confidenceScore: _calculateConfidenceScore(params),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Validate climb
      final validation = ValidationService.validateClimbRecord(climb);
      if (!validation.isValid) {
        throw Exception('Climb validation failed: ${validation.errors.first.message}');
      }
      
      // Add to session
      final success = await SessionService.instance.addClimb(climb);
      if (!success) {
        throw Exception('Failed to add climb to session');
      }
      
      // Update suggestions
      await _updateSuggestions();
      
      // Emit event
      _climbController.add(climb);
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Quick climb logged successfully',
        category: 'climb_logging',
        data: {'climb_id': climb.id},
      );
      
      return climb;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'log_quick_climb',
      );
      
      return null;
    }
  }
  
  /// Log a standard climb
  Future<ClimbRecord?> logStandardClimb(StandardClimbParams params) async {
    try {
      if (!SessionService.instance.isActive) {
        throw Exception('No active session for logging climb');
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Logging standard climb',
        category: 'climb_logging',
        data: {
          'grade': params.grade,
          'style': params.style.name,
          'route': params.routeName ?? 'unnamed',
        },
      );
      
      // Create climb record
      final climb = ClimbRecord(
        id: _generateClimbId(),
        sessionId: SessionService.instance.currentSession!.id,
        userId: AuthService.instance.currentUser!.id,
        grade: params.grade,
        gradeSystem: params.gradeSystem,
        style: params.style,
        result: params.result,
        attempts: params.attempts,
        routeName: params.routeName,
        routeId: params.routeId,
        fallCount: params.fallCount ?? 0,
        restCount: params.restCount ?? 0,
        qualityRating: params.qualityRating,
        notes: params.notes,
        sequenceNumber: SessionService.instance.currentClimbs.length + 1,
        confidenceScore: _calculateConfidenceScore(params),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Validate climb
      final validation = ValidationService.validateClimbRecord(climb);
      if (!validation.isValid) {
        throw Exception('Climb validation failed: ${validation.errors.first.message}');
      }
      
      // Add to session
      final success = await SessionService.instance.addClimb(climb);
      if (!success) {
        throw Exception('Failed to add climb to session');
      }
      
      // Update suggestions
      await _updateSuggestions();
      
      // Emit event
      _climbController.add(climb);
      
      return climb;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'log_standard_climb',
      );
      
      return null;
    }
  }
  
  /// Log a detailed climb
  Future<ClimbRecord?> logDetailedClimb(DetailedClimbParams params) async {
    try {
      if (!SessionService.instance.isActive) {
        throw Exception('No active session for logging climb');
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Logging detailed climb',
        category: 'climb_logging',
        data: {
          'grade': params.grade,
          'style': params.style.name,
          'route': params.routeName ?? 'unnamed',
        },
      );
      
      // Create climb record
      final climb = ClimbRecord(
        id: _generateClimbId(),
        sessionId: SessionService.instance.currentSession!.id,
        userId: AuthService.instance.currentUser!.id,
        grade: params.grade,
        gradeSystem: params.gradeSystem,
        style: params.style,
        result: params.result,
        attempts: params.attempts,
        routeName: params.routeName,
        routeId: params.routeId,
        fallCount: params.fallCount ?? 0,
        restCount: params.restCount ?? 0,
        qualityRating: params.qualityRating,
        difficultyPerception: params.difficultyPerception,
        holdsQuality: params.holdsQuality,
        movementQuality: params.movementQuality,
        routeLength: params.routeLength,
        durationSeconds: params.durationSeconds,
        notes: params.notes,
        betaNotes: params.betaNotes,
        tags: params.tags,
        sequenceNumber: SessionService.instance.currentClimbs.length + 1,
        confidenceScore: _calculateConfidenceScore(params),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Validate climb
      final validation = ValidationService.validateClimbRecord(climb);
      if (!validation.isValid) {
        throw Exception('Climb validation failed: ${validation.errors.first.message}');
      }
      
      // Add to session
      final success = await SessionService.instance.addClimb(climb);
      if (!success) {
        throw Exception('Failed to add climb to session');
      }
      
      // Update suggestions
      await _updateSuggestions();
      
      // Emit event
      _climbController.add(climb);
      
      return climb;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'log_detailed_climb',
      );
      
      return null;
    }
  }
  
  /// Start a new draft climb
  Future<ClimbRecord?> startDraft({
    ClimbingStyle? style,
    String? grade,
    GradeSystem? gradeSystem,
  }) async {
    try {
      if (!SessionService.instance.isActive) {
        return null;
      }
      
      _currentDraft = ClimbRecord(
        id: _generateClimbId(),
        sessionId: SessionService.instance.currentSession!.id,
        userId: AuthService.instance.currentUser!.id,
        grade: grade ?? '',
        gradeSystem: gradeSystem ?? GradeSystem.yds,
        style: style ?? ClimbingStyle.lead,
        result: ClimbResult.working,
        attempts: 1,
        sequenceNumber: SessionService.instance.currentClimbs.length + 1,
        confidenceScore: 0.5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _startDraftTimer();
      
      return _currentDraft;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'start_draft',
      );
      
      return null;
    }
  }
  
  /// Update current draft
  Future<bool> updateDraft(ClimbEditParams params) async {
    try {
      if (_currentDraft == null) {
        return false;
      }
      
      _currentDraft = _currentDraft!.copyWith(
        grade: params.grade ?? _currentDraft!.grade,
        gradeSystem: params.gradeSystem ?? _currentDraft!.gradeSystem,
        style: params.style ?? _currentDraft!.style,
        result: params.result ?? _currentDraft!.result,
        attempts: params.attempts ?? _currentDraft!.attempts,
        routeName: params.routeName ?? _currentDraft!.routeName,
        routeId: params.routeId ?? _currentDraft!.routeId,
        fallCount: params.fallCount ?? _currentDraft!.fallCount,
        restCount: params.restCount ?? _currentDraft!.restCount,
        qualityRating: params.qualityRating ?? _currentDraft!.qualityRating,
        difficultyPerception: params.difficultyPerception ?? _currentDraft!.difficultyPerception,
        holdsQuality: params.holdsQuality ?? _currentDraft!.holdsQuality,
        movementQuality: params.movementQuality ?? _currentDraft!.movementQuality,
        routeLength: params.routeLength ?? _currentDraft!.routeLength,
        durationSeconds: params.durationSeconds ?? _currentDraft!.durationSeconds,
        notes: params.notes ?? _currentDraft!.notes,
        betaNotes: params.betaNotes ?? _currentDraft!.betaNotes,
        tags: params.tags ?? _currentDraft!.tags,
        updatedAt: DateTime.now(),
      );
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'update_draft',
      );
      
      return false;
    }
  }
  
  /// Save current draft as climb
  Future<ClimbRecord?> saveDraft() async {
    try {
      if (_currentDraft == null) {
        return null;
      }
      
      // Validate draft
      final validation = ValidationService.validateClimbRecord(_currentDraft!);
      if (!validation.isValid) {
        throw Exception('Draft validation failed: ${validation.errors.first.message}');
      }
      
      // Update confidence score
      final updatedDraft = _currentDraft!.copyWith(
        confidenceScore: _calculateConfidenceScore(_currentDraft!),
        updatedAt: DateTime.now(),
      );
      
      // Add to session
      final success = await SessionService.instance.addClimb(updatedDraft);
      if (!success) {
        throw Exception('Failed to save draft to session');
      }
      
      // Clear draft
      _currentDraft = null;
      _stopDraftTimer();
      
      // Update suggestions
      await _updateSuggestions();
      
      // Emit event
      _climbController.add(updatedDraft);
      
      return updatedDraft;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'save_draft',
      );
      
      return null;
    }
  }
  
  /// Discard current draft
  void discardDraft() {
    _currentDraft = null;
    _stopDraftTimer();
  }
  
  /// Edit an existing climb
  Future<bool> editClimb(String climbId, ClimbEditParams params) async {
    try {
      final climbs = SessionService.instance.currentClimbs;
      final climb = climbs.firstWhere(
        (c) => c.id == climbId,
        orElse: () => throw Exception('Climb not found'),
      );
      
      final updatedClimb = climb.copyWith(
        grade: params.grade ?? climb.grade,
        gradeSystem: params.gradeSystem ?? climb.gradeSystem,
        style: params.style ?? climb.style,
        result: params.result ?? climb.result,
        attempts: params.attempts ?? climb.attempts,
        routeName: params.routeName ?? climb.routeName,
        routeId: params.routeId ?? climb.routeId,
        fallCount: params.fallCount ?? climb.fallCount,
        restCount: params.restCount ?? climb.restCount,
        qualityRating: params.qualityRating ?? climb.qualityRating,
        difficultyPerception: params.difficultyPerception ?? climb.difficultyPerception,
        holdsQuality: params.holdsQuality ?? climb.holdsQuality,
        movementQuality: params.movementQuality ?? climb.movementQuality,
        routeLength: params.routeLength ?? climb.routeLength,
        durationSeconds: params.durationSeconds ?? climb.durationSeconds,
        notes: params.notes ?? climb.notes,
        betaNotes: params.betaNotes ?? climb.betaNotes,
        tags: params.tags ?? climb.tags,
        confidenceScore: _calculateConfidenceScore(params),
        updatedAt: DateTime.now(),
      );
      
      // Update in session
      final success = await SessionService.instance.updateClimb(updatedClimb);
      if (success) {
        _climbController.add(updatedClimb);
        await _updateSuggestions();
      }
      
      return success;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'edit_climb',
      );
      
      return false;
    }
  }
  
  /// Delete a climb
  Future<bool> deleteClimb(String climbId) async {
    try {
      final success = await SessionService.instance.removeClimb(climbId);
      if (success) {
        await _updateSuggestions();
      }
      
      return success;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'delete_climb',
      );
      
      return false;
    }
  }
  
  /// Create a new template from climb
  Future<bool> createTemplateFromClimb(String climbId, String templateName) async {
    try {
      final climbs = SessionService.instance.currentClimbs;
      final climb = climbs.firstWhere(
        (c) => c.id == climbId,
        orElse: () => throw Exception('Climb not found'),
      );
      
      final template = ClimbTemplate(
        id: _generateTemplateId(),
        name: templateName,
        style: climb.style,
        gradeSystem: climb.gradeSystem,
        defaultGrade: climb.grade,
        defaultValues: {
          'fallCount': climb.fallCount,
          'restCount': climb.restCount,
          'qualityRating': climb.qualityRating,
          'routeLength': climb.routeLength,
        },
        isUserCreated: true,
      );
      
      _userTemplates.add(template);
      await _saveUserTemplates();
      await _updateSuggestions();
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'create_template',
      );
      
      return false;
    }
  }
  
  /// Get current logging suggestions
  Future<LoggingSuggestions> getSuggestions() async {
    try {
      return await _generateSuggestions();
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.climbLogging,
        userAction: 'get_suggestions',
      );
      
      return const LoggingSuggestions(
        recentGrades: [],
        recentRoutes: [],
        templates: [],
        styleGrades: {},
        commonTags: [],
      );
    }
  }
  
  /// Private methods
  double _calculateConfidenceScore(dynamic params) {
    double score = 0.5; // Base confidence
    
    // Increase confidence based on data completeness
    if (params is DetailedClimbParams) {
      score += 0.3; // Detailed logging
      if (params.routeName != null) score += 0.1;
      if (params.qualityRating != null) score += 0.1;
    } else if (params is StandardClimbParams) {
      score += 0.2; // Standard logging
      if (params.routeName != null) score += 0.1;
    } else if (params is ClimbRecord) {
      score += 0.2;
      if (params.routeName != null) score += 0.1;
      if (params.qualityRating != null) score += 0.1;
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  void _startDraftTimer() {
    _draftTimer?.cancel();
    _draftTimer = Timer.periodic(draftSaveInterval, (_) async {
      if (_currentDraft != null) {
        await _saveDraftToStorage();
      }
    });
  }
  
  void _stopDraftTimer() {
    _draftTimer?.cancel();
  }
  
  Future<void> _updateSuggestions() async {
    try {
      final suggestions = await _generateSuggestions();
      _suggestionsController.add(suggestions);
    } catch (error) {
      // Fail silently for suggestions
    }
  }
  
  Future<LoggingSuggestions> _generateSuggestions() async {
    // Generate suggestions based on recent climbs
    final recentClimbs = await _getRecentClimbs(50);
    
    final recentGrades = recentClimbs
        .map((c) => c.grade)
        .where((g) => g.isNotEmpty)
        .toSet()
        .take(maxRecentGrades)
        .toList();
    
    final recentRoutes = recentClimbs
        .map((c) => c.routeName)
        .where((r) => r != null && r.isNotEmpty)
        .cast<String>()
        .toSet()
        .take(maxRecentRoutes)
        .toList();
    
    final styleGrades = <ClimbingStyle, List<String>>{};
    for (final style in ClimbingStyle.values) {
      final grades = recentClimbs
          .where((c) => c.style == style)
          .map((c) => c.grade)
          .where((g) => g.isNotEmpty)
          .toSet()
          .take(5)
          .toList();
      styleGrades[style] = grades;
    }
    
    final commonTags = recentClimbs
        .expand((c) => c.tags ?? <String>[])
        .fold<Map<String, int>>({}, (map, tag) {
          map[tag] = (map[tag] ?? 0) + 1;
          return map;
        })
        .entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .take(10)
        .toList();
    
    return LoggingSuggestions(
      recentGrades: recentGrades,
      recentRoutes: recentRoutes,
      templates: _userTemplates,
      styleGrades: styleGrades,
      commonTags: commonTags,
    );
  }
  
  String _generateClimbId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'climb_${timestamp}_$random';
  }
  
  String _generateTemplateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'template_${timestamp}_$random';
  }
  
  // Mock implementations - replace with actual implementations
  Future<void> _loadUserTemplates() async {
    // TODO: Load from storage
    _userTemplates = [];
  }
  
  Future<void> _saveUserTemplates() async {
    // TODO: Save to storage
  }
  
  Future<void> _saveDraftToStorage() async {
    // TODO: Save draft to local storage
  }
  
  Future<List<ClimbRecord>> _getRecentClimbs(int limit) async {
    // TODO: Get from database
    return SessionService.instance.currentClimbs.take(limit).toList();
  }
  
  /// Dispose resources
  void dispose() {
    _stopDraftTimer();
    _climbController.close();
    _modeController.close();
    _suggestionsController.close();
  }
} 