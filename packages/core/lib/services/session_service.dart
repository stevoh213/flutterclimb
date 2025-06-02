// Session Management Service
// Modular service for climbing session lifecycle management

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/climbing_models.dart';
import '../monitoring/sentry_config.dart';
import '../validation/validation_service.dart';
import '../auth/auth_service.dart';

/// Session management events
enum SessionEvent {
  started,
  paused,
  resumed,
  completed,
  cancelled,
  climbAdded,
  climbUpdated,
  climbRemoved,
  locationChanged,
}

/// Session event data
class SessionEventData {
  final SessionEvent event;
  final ClimbingSession session;
  final ClimbRecord? climb;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  
  const SessionEventData({
    required this.event,
    required this.session,
    this.climb,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Session creation parameters
class SessionCreateParams {
  final String locationName;
  final LocationType locationType;
  final String? locationId;
  final String? notes;
  final Map<String, dynamic>? weatherConditions;
  final Map<String, dynamic>? metadata;
  
  const SessionCreateParams({
    required this.locationName,
    required this.locationType,
    this.locationId,
    this.notes,
    this.weatherConditions,
    this.metadata,
  });
}

/// Session update parameters
class SessionUpdateParams {
  final String? notes;
  final Map<String, dynamic>? weatherConditions;
  final String? locationName;
  final LocationType? locationType;
  final String? locationId;
  
  const SessionUpdateParams({
    this.notes,
    this.weatherConditions,
    this.locationName,
    this.locationType,
    this.locationId,
  });
}

/// Session statistics
class SessionStats {
  final int totalClimbs;
  final int successfulClimbs;
  final int attempts;
  final Duration duration;
  final String? maxGrade;
  final double averageQuality;
  final Map<ClimbingStyle, int> styleDistribution;
  final Map<ClimbResult, int> resultDistribution;
  
  const SessionStats({
    required this.totalClimbs,
    required this.successfulClimbs,
    required this.attempts,
    required this.duration,
    this.maxGrade,
    required this.averageQuality,
    required this.styleDistribution,
    required this.resultDistribution,
  });
  
  double get successRate => 
      totalClimbs > 0 ? successfulClimbs / totalClimbs : 0.0;
}

/// Session management service
class SessionService {
  static SessionService? _instance;
  static SessionService get instance => _instance ??= SessionService._();
  SessionService._();
  
  // Current state
  ClimbingSession? _currentSession;
  final List<ClimbRecord> _currentClimbs = [];
  bool _isActive = false;
  
  // Event streams
  final _sessionController = StreamController<ClimbingSession?>.broadcast();
  final _eventController = StreamController<SessionEventData>.broadcast();
  final _climbsController = StreamController<List<ClimbRecord>>.broadcast();
  
  // Timers
  Timer? _autosaveTimer;
  Timer? _durationTimer;
  
  // Configuration
  static const Duration autosaveInterval = Duration(minutes: 2);
  static const Duration maxSessionDuration = Duration(hours: 12);
  
  /// Current active session
  ClimbingSession? get currentSession => _currentSession;
  
  /// Current session climbs
  List<ClimbRecord> get currentClimbs => List.unmodifiable(_currentClimbs);
  
  /// Whether session is active
  bool get isActive => _isActive && _currentSession != null;
  
  /// Session changes stream
  Stream<ClimbingSession?> get sessionChanges => _sessionController.stream;
  
  /// Session events stream
  Stream<SessionEventData> get sessionEvents => _eventController.stream;
  
  /// Climbs changes stream
  Stream<List<ClimbRecord>> get climbsChanges => _climbsController.stream;
  
  /// Initialize session service
  Future<void> initialize() async {
    try {
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Initializing session service',
        category: 'session',
      );
      
      // Try to restore active session
      await _restoreActiveSession();
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'session_init',
      );
    }
  }
  
  /// Start a new climbing session
  Future<ClimbingSession?> startSession(SessionCreateParams params) async {
    try {
      // Check authentication
      if (!AuthService.instance.isAuthenticated) {
        throw Exception('User must be authenticated to start session');
      }
      
      // Validate parameters
      final validation = _validateSessionParams(params);
      if (!validation.isValid) {
        throw Exception('Invalid session parameters: ${validation.errors.first.message}');
      }
      
      // End current session if active
      if (_currentSession != null) {
        await _pauseCurrentSession();
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Starting new session',
        category: 'session',
        data: {
          'location': params.locationName,
          'type': params.locationType.name,
        },
      );
      
      // Create new session
      final now = DateTime.now();
      final session = ClimbingSession(
        id: _generateSessionId(),
        userId: AuthService.instance.currentUser!.id,
        startTime: now,
        locationName: params.locationName,
        locationType: params.locationType,
        locationId: params.locationId,
        notes: params.notes,
        weatherConditions: params.weatherConditions,
        deviceInfo: await _getDeviceInfo(),
        appVersion: await _getAppVersion(),
        createdAt: now,
        updatedAt: now,
      );
      
      // Validate session
      final sessionValidation = ValidationService.validateClimbingSession(session);
      if (!sessionValidation.isValid) {
        throw Exception('Session validation failed: ${sessionValidation.errors.first.message}');
      }
      
      // Set current session
      _currentSession = session;
      _currentClimbs.clear();
      _isActive = true;
      
      // Start timers
      _startAutosaveTimer();
      _startDurationTimer();
      
      // Save session
      await _saveSession(session);
      
      // Emit events
      _sessionController.add(session);
      _climbsController.add([]);
      _emitSessionEvent(SessionEvent.started, session);
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Session started successfully',
        category: 'session',
        data: {'session_id': session.id},
      );
      
      return session;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'start_session',
      );
      
      return null;
    }
  }
  
  /// Pause current session
  Future<bool> pauseSession() async {
    try {
      if (_currentSession == null || !_isActive) {
        return false;
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Pausing session',
        category: 'session',
        data: {'session_id': _currentSession!.id},
      );
      
      final updatedSession = _currentSession!.copyWith(
        status: SessionStatus.paused,
        updatedAt: DateTime.now(),
      );
      
      _currentSession = updatedSession;
      _isActive = false;
      
      // Stop timers
      _stopTimers();
      
      // Save session
      await _saveSession(updatedSession);
      
      // Emit events
      _sessionController.add(updatedSession);
      _emitSessionEvent(SessionEvent.paused, updatedSession);
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'pause_session',
      );
      
      return false;
    }
  }
  
  /// Resume paused session
  Future<bool> resumeSession() async {
    try {
      if (_currentSession == null || _currentSession!.status != SessionStatus.paused) {
        return false;
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Resuming session',
        category: 'session',
        data: {'session_id': _currentSession!.id},
      );
      
      final updatedSession = _currentSession!.copyWith(
        status: SessionStatus.active,
        updatedAt: DateTime.now(),
      );
      
      _currentSession = updatedSession;
      _isActive = true;
      
      // Restart timers
      _startAutosaveTimer();
      _startDurationTimer();
      
      // Save session
      await _saveSession(updatedSession);
      
      // Emit events
      _sessionController.add(updatedSession);
      _emitSessionEvent(SessionEvent.resumed, updatedSession);
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'resume_session',
      );
      
      return false;
    }
  }
  
  /// Complete current session
  Future<bool> completeSession() async {
    try {
      if (_currentSession == null) {
        return false;
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Completing session',
        category: 'session',
        data: {
          'session_id': _currentSession!.id,
          'climb_count': _currentClimbs.length,
        },
      );
      
      final now = DateTime.now();
      final updatedSession = _currentSession!.copyWith(
        endTime: now,
        status: SessionStatus.completed,
        updatedAt: now,
      );
      
      // Validate completed session
      final validation = ValidationService.validateClimbingSession(updatedSession);
      if (!validation.isValid) {
        ClimbingErrorReporter.addClimbingBreadcrumb(
          'Session validation warnings',
          category: 'session',
          data: {'warnings': validation.errors.map((e) => e.message).toList()},
        );
      }
      
      _currentSession = updatedSession;
      _isActive = false;
      
      // Stop timers
      _stopTimers();
      
      // Save final session
      await _saveSession(updatedSession);
      
      // Save all climbs
      for (final climb in _currentClimbs) {
        await _saveClimb(climb);
      }
      
      // Emit events
      _sessionController.add(updatedSession);
      _emitSessionEvent(SessionEvent.completed, updatedSession);
      
      // Clear current session
      _currentSession = null;
      _currentClimbs.clear();
      _sessionController.add(null);
      _climbsController.add([]);
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'complete_session',
      );
      
      return false;
    }
  }
  
  /// Cancel current session
  Future<bool> cancelSession() async {
    try {
      if (_currentSession == null) {
        return false;
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Cancelling session',
        category: 'session',
        data: {'session_id': _currentSession!.id},
      );
      
      final updatedSession = _currentSession!.copyWith(
        status: SessionStatus.cancelled,
        updatedAt: DateTime.now(),
      );
      
      // Save cancelled session
      await _saveSession(updatedSession);
      
      // Emit events
      _emitSessionEvent(SessionEvent.cancelled, updatedSession);
      
      // Clear current session
      _currentSession = null;
      _currentClimbs.clear();
      _isActive = false;
      
      // Stop timers
      _stopTimers();
      
      // Emit cleared state
      _sessionController.add(null);
      _climbsController.add([]);
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'cancel_session',
      );
      
      return false;
    }
  }
  
  /// Update current session
  Future<bool> updateSession(SessionUpdateParams params) async {
    try {
      if (_currentSession == null) {
        return false;
      }
      
      final updatedSession = _currentSession!.copyWith(
        notes: params.notes ?? _currentSession!.notes,
        weatherConditions: params.weatherConditions ?? _currentSession!.weatherConditions,
        locationName: params.locationName ?? _currentSession!.locationName,
        locationType: params.locationType ?? _currentSession!.locationType,
        locationId: params.locationId ?? _currentSession!.locationId,
        updatedAt: DateTime.now(),
      );
      
      // Validate updated session
      final validation = ValidationService.validateClimbingSession(updatedSession);
      if (!validation.isValid) {
        throw Exception('Session update validation failed: ${validation.errors.first.message}');
      }
      
      _currentSession = updatedSession;
      
      // Save session
      await _saveSession(updatedSession);
      
      // Emit events
      _sessionController.add(updatedSession);
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'update_session',
      );
      
      return false;
    }
  }
  
  /// Add climb to current session
  Future<bool> addClimb(ClimbRecord climb) async {
    try {
      if (_currentSession == null || !_isActive) {
        return false;
      }
      
      // Validate climb
      final validation = ValidationService.validateClimbRecord(climb);
      if (!validation.isValid) {
        throw Exception('Climb validation failed: ${validation.errors.first.message}');
      }
      
      // Ensure climb belongs to current session
      final sessionClimb = climb.copyWith(
        sessionId: _currentSession!.id,
        userId: _currentSession!.userId,
        sequenceNumber: _currentClimbs.length + 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _currentClimbs.add(sessionClimb);
      
      // Save climb
      await _saveClimb(sessionClimb);
      
      // Emit events
      _climbsController.add(List.from(_currentClimbs));
      _emitSessionEvent(SessionEvent.climbAdded, _currentSession!, climb: sessionClimb);
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Climb added to session',
        category: 'session',
        data: {
          'climb_id': sessionClimb.id,
          'grade': sessionClimb.grade,
          'result': sessionClimb.result.name,
        },
      );
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'add_climb',
      );
      
      return false;
    }
  }
  
  /// Update climb in current session
  Future<bool> updateClimb(ClimbRecord updatedClimb) async {
    try {
      if (_currentSession == null) {
        return false;
      }
      
      final index = _currentClimbs.indexWhere((c) => c.id == updatedClimb.id);
      if (index == -1) {
        return false;
      }
      
      // Validate updated climb
      final validation = ValidationService.validateClimbRecord(updatedClimb);
      if (!validation.isValid) {
        throw Exception('Climb update validation failed: ${validation.errors.first.message}');
      }
      
      final climbWithUpdate = updatedClimb.copyWith(updatedAt: DateTime.now());
      _currentClimbs[index] = climbWithUpdate;
      
      // Save climb
      await _saveClimb(climbWithUpdate);
      
      // Emit events
      _climbsController.add(List.from(_currentClimbs));
      _emitSessionEvent(SessionEvent.climbUpdated, _currentSession!, climb: climbWithUpdate);
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'update_climb',
      );
      
      return false;
    }
  }
  
  /// Remove climb from current session
  Future<bool> removeClimb(String climbId) async {
    try {
      if (_currentSession == null) {
        return false;
      }
      
      final removedClimb = _currentClimbs.firstWhere(
        (c) => c.id == climbId,
        orElse: () => throw Exception('Climb not found'),
      );
      
      _currentClimbs.removeWhere((c) => c.id == climbId);
      
      // Resequence remaining climbs
      for (int i = 0; i < _currentClimbs.length; i++) {
        _currentClimbs[i] = _currentClimbs[i].copyWith(sequenceNumber: i + 1);
      }
      
      // Delete climb
      await _deleteClimb(climbId);
      
      // Emit events
      _climbsController.add(List.from(_currentClimbs));
      _emitSessionEvent(SessionEvent.climbRemoved, _currentSession!, climb: removedClimb);
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'remove_climb',
      );
      
      return false;
    }
  }
  
  /// Get session statistics
  SessionStats getSessionStats() {
    if (_currentSession == null) {
      return const SessionStats(
        totalClimbs: 0,
        successfulClimbs: 0,
        attempts: 0,
        duration: Duration.zero,
        averageQuality: 0.0,
        styleDistribution: {},
        resultDistribution: {},
      );
    }
    
    final climbs = _currentClimbs;
    final duration = _currentSession!.duration ?? Duration.zero;
    
    int successfulClimbs = 0;
    int totalAttempts = 0;
    double totalQuality = 0.0;
    int qualityCount = 0;
    final styleDistribution = <ClimbingStyle, int>{};
    final resultDistribution = <ClimbResult, int>{};
    String? maxGrade;
    
    for (final climb in climbs) {
      // Count successful climbs
      if (climb.isSuccessful) {
        successfulClimbs++;
      }
      
      // Sum attempts
      totalAttempts += climb.attempts;
      
      // Quality rating
      if (climb.qualityRating != null) {
        totalQuality += climb.qualityRating!;
        qualityCount++;
      }
      
      // Style distribution
      styleDistribution[climb.style] = (styleDistribution[climb.style] ?? 0) + 1;
      
      // Result distribution
      resultDistribution[climb.result] = (resultDistribution[climb.result] ?? 0) + 1;
      
      // Max grade (simplified comparison)
      if (maxGrade == null || _compareGrades(climb.grade, maxGrade) > 0) {
        maxGrade = climb.grade;
      }
    }
    
    return SessionStats(
      totalClimbs: climbs.length,
      successfulClimbs: successfulClimbs,
      attempts: totalAttempts,
      duration: duration,
      maxGrade: maxGrade,
      averageQuality: qualityCount > 0 ? totalQuality / qualityCount : 0.0,
      styleDistribution: styleDistribution,
      resultDistribution: resultDistribution,
    );
  }
  
  /// Get recent sessions for current user
  Future<List<ClimbingSession>> getRecentSessions({int limit = 10}) async {
    try {
      if (!AuthService.instance.isAuthenticated) {
        return [];
      }
      
      return await _loadRecentSessions(
        AuthService.instance.currentUser!.id,
        limit,
      );
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.sessionManagement,
        userAction: 'get_recent_sessions',
      );
      
      return [];
    }
  }
  
  /// Private methods
  ValidationResult _validateSessionParams(SessionCreateParams params) {
    var result = const ValidationResult.valid();
    
    result = result.combine(ValidationService.validateClimbingLocation(
      ClimbingLocation(
        id: 'temp',
        name: params.locationName,
        type: params.locationType,
      ),
    ));
    
    return result;
  }
  
  void _emitSessionEvent(SessionEvent event, ClimbingSession session, {ClimbRecord? climb}) {
    final eventData = SessionEventData(
      event: event,
      session: session,
      climb: climb,
    );
    _eventController.add(eventData);
  }
  
  void _startAutosaveTimer() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(autosaveInterval, (_) async {
      if (_currentSession != null) {
        await _saveSession(_currentSession!);
      }
    });
  }
  
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_currentSession != null && _isActive) {
        // Check for maximum session duration
        final duration = DateTime.now().difference(_currentSession!.startTime);
        if (duration > maxSessionDuration) {
          ClimbingErrorReporter.addClimbingBreadcrumb(
            'Session exceeds maximum duration',
            category: 'session',
            data: {'duration_hours': duration.inHours},
          );
        }
      }
    });
  }
  
  void _stopTimers() {
    _autosaveTimer?.cancel();
    _durationTimer?.cancel();
  }
  
  Future<void> _pauseCurrentSession() async {
    if (_currentSession != null && _isActive) {
      await pauseSession();
    }
  }
  
  Future<void> _restoreActiveSession() async {
    try {
      final session = await _loadActiveSession();
      if (session != null) {
        _currentSession = session;
        _isActive = session.status == SessionStatus.active;
        
        // Load session climbs
        final climbs = await _loadSessionClimbs(session.id);
        _currentClimbs.clear();
        _currentClimbs.addAll(climbs);
        
        // Restart timers if active
        if (_isActive) {
          _startAutosaveTimer();
          _startDurationTimer();
        }
        
        _sessionController.add(session);
        _climbsController.add(List.from(_currentClimbs));
      }
    } catch (error) {
      // Failed to restore session, start fresh
    }
  }
  
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'session_${timestamp}_$random';
  }
  
  int _compareGrades(String grade1, String grade2) {
    // Simplified grade comparison - would need full implementation
    return grade1.compareTo(grade2);
  }
  
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    // TODO: Get actual device information
    return {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'version': 'unknown',
    };
  }
  
  Future<String> _getAppVersion() async {
    // TODO: Get actual app version
    return '1.0.0';
  }
  
  // Mock database operations - replace with actual implementations
  Future<void> _saveSession(ClimbingSession session) async {
    // TODO: Save to database
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  Future<void> _saveClimb(ClimbRecord climb) async {
    // TODO: Save to database
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  Future<void> _deleteClimb(String climbId) async {
    // TODO: Delete from database
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  Future<ClimbingSession?> _loadActiveSession() async {
    // TODO: Load from database
    await Future.delayed(const Duration(milliseconds: 100));
    return null;
  }
  
  Future<List<ClimbRecord>> _loadSessionClimbs(String sessionId) async {
    // TODO: Load from database
    await Future.delayed(const Duration(milliseconds: 100));
    return [];
  }
  
  Future<List<ClimbingSession>> _loadRecentSessions(String userId, int limit) async {
    // TODO: Load from database
    await Future.delayed(const Duration(milliseconds: 200));
    return [];
  }
  
  /// Dispose resources
  void dispose() {
    _stopTimers();
    _sessionController.close();
    _eventController.close();
    _climbsController.close();
  }
} 