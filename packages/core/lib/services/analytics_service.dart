// Analytics Service
// Modular service for tracking user progress and climbing analytics

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/climbing_models.dart';
import '../monitoring/sentry_config.dart';
import '../validation/validation_service.dart';
import '../auth/auth_service.dart';

/// Progress tracking period
enum ProgressPeriod {
  week,
  month,
  quarter,
  year,
  allTime,
}

/// Analytics metric type
enum AnalyticsMetric {
  totalClimbs,
  totalSessions,
  successRate,
  averageGrade,
  maxGrade,
  totalTime,
  uniqueRoutes,
  uniqueLocations,
  attempts,
  sends,
}

/// Grade progression direction
enum ProgressionDirection {
  improving,
  maintaining,
  declining,
  insufficient_data,
}

/// User progress statistics
class UserProgressStats {
  final String userId;
  final ProgressPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final int totalClimbs;
  final int totalSessions;
  final Duration totalClimbingTime;
  final double successRate;
  final String? averageGrade;
  final String? maxGrade;
  final int uniqueRoutes;
  final int uniqueLocations;
  final Map<ClimbingStyle, int> climbsByStyle;
  final Map<String, int> gradeDistribution;
  final List<ProgressDataPoint> progressPoints;
  final DateTime calculatedAt;
  
  const UserProgressStats({
    required this.userId,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalClimbs,
    required this.totalSessions,
    required this.totalClimbingTime,
    required this.successRate,
    this.averageGrade,
    this.maxGrade,
    required this.uniqueRoutes,
    required this.uniqueLocations,
    required this.climbsByStyle,
    required this.gradeDistribution,
    required this.progressPoints,
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();
}

/// Progress data point for trend analysis
class ProgressDataPoint {
  final DateTime date;
  final double value;
  final AnalyticsMetric metric;
  final String? unit;
  final Map<String, dynamic>? metadata;
  
  const ProgressDataPoint({
    required this.date,
    required this.value,
    required this.metric,
    this.unit,
    this.metadata,
  });
}

/// Grade progression analysis
class GradeProgression {
  final ClimbingStyle style;
  final GradeSystem gradeSystem;
  final List<GradeProgressPoint> progressPoints;
  final ProgressionDirection direction;
  final double progressionRate; // grades per month
  final String? currentGrade;
  final String? projectedGrade;
  final int daysToNextGrade;
  final double confidence;
  
  const GradeProgression({
    required this.style,
    required this.gradeSystem,
    required this.progressPoints,
    required this.direction,
    required this.progressionRate,
    this.currentGrade,
    this.projectedGrade,
    required this.daysToNextGrade,
    required this.confidence,
  });
}

/// Grade progress point
class GradeProgressPoint {
  final DateTime date;
  final String grade;
  final int gradeValue;
  final ClimbAttemptResult result;
  final bool isPersonalBest;
  
  const GradeProgressPoint({
    required this.date,
    required this.grade,
    required this.gradeValue,
    required this.result,
    required this.isPersonalBest,
  });
}

/// Session performance analysis
class SessionPerformance {
  final String sessionId;
  final DateTime sessionDate;
  final Duration duration;
  final int totalClimbs;
  final int successfulClimbs;
  final double successRate;
  final String? maxGrade;
  final double averageAttempts;
  final Map<ClimbingStyle, int> styleBreakdown;
  final double performanceScore;
  final String performanceRating;
  final List<String> achievements;
  
  const SessionPerformance({
    required this.sessionId,
    required this.sessionDate,
    required this.duration,
    required this.totalClimbs,
    required this.successfulClimbs,
    required this.successRate,
    this.maxGrade,
    required this.averageAttempts,
    required this.styleBreakdown,
    required this.performanceScore,
    required this.performanceRating,
    required this.achievements,
  });
}

/// Goal progress tracking
class GoalProgress {
  final String goalId;
  final ClimbingGoal goal;
  final double progressPercentage;
  final dynamic currentValue;
  final dynamic targetValue;
  final bool isCompleted;
  final DateTime? completedAt;
  final int daysRemaining;
  final double dailyTargetRate;
  final bool isOnTrack;
  final String status;
  final List<ProgressMilestone> milestones;
  
  const GoalProgress({
    required this.goalId,
    required this.goal,
    required this.progressPercentage,
    required this.currentValue,
    required this.targetValue,
    required this.isCompleted,
    this.completedAt,
    required this.daysRemaining,
    required this.dailyTargetRate,
    required this.isOnTrack,
    required this.status,
    required this.milestones,
  });
}

/// Progress milestone
class ProgressMilestone {
  final String name;
  final double percentage;
  final bool isReached;
  final DateTime? reachedAt;
  final String description;
  
  const ProgressMilestone({
    required this.name,
    required this.percentage,
    required this.isReached,
    this.reachedAt,
    required this.description,
  });
}

/// Analytics comparison data
class AnalyticsComparison {
  final ProgressPeriod period;
  final UserProgressStats currentPeriod;
  final UserProgressStats previousPeriod;
  final Map<AnalyticsMetric, double> changes;
  final Map<AnalyticsMetric, String> changeDescriptions;
  final double overallImprovement;
  
  const AnalyticsComparison({
    required this.period,
    required this.currentPeriod,
    required this.previousPeriod,
    required this.changes,
    required this.changeDescriptions,
    required this.overallImprovement,
  });
}

/// Analytics events
enum AnalyticsEvent {
  progressUpdated,
  goalProgressChanged,
  achievementUnlocked,
  personalBestReached,
  milestoneCompleted,
  reportGenerated,
}

/// Analytics event data
class AnalyticsEventData {
  final AnalyticsEvent event;
  final String userId;
  final dynamic data;
  final DateTime timestamp;
  
  const AnalyticsEventData({
    required this.event,
    required this.userId,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Analytics Service
class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();
  AnalyticsService._();
  
  // Current state
  final Map<String, UserProgressStats> _progressCache = {};
  final Map<String, List<GoalProgress>> _goalProgressCache = {};
  final Map<String, List<SessionPerformance>> _sessionPerformanceCache = {};
  final Map<String, List<GradeProgression>> _gradeProgressionCache = {};
  
  // Event streams
  final _eventController = StreamController<AnalyticsEventData>.broadcast();
  
  // Timers
  Timer? _progressUpdateTimer;
  Timer? _cacheCleanupTimer;
  
  // Configuration
  static const Duration progressUpdateInterval = Duration(hours: 1);
  static const Duration cacheLifetime = Duration(hours: 6);
  static const int maxCacheEntries = 100;
  static const double minimumDataConfidence = 0.7;
  
  /// Analytics events stream
  Stream<AnalyticsEventData> get analyticsEvents => _eventController.stream;
  
  /// Initialize analytics service
  Future<void> initialize() async {
    try {
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Initializing analytics service',
        category: 'analytics',
      );
      
      // Start background tasks
      _startBackgroundTasks();
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.analyticsServices,
        userAction: 'analytics_init',
      );
    }
  }
  
  /// Get user progress statistics for a period
  Future<UserProgressStats?> getUserProgressStats(
    String userId,
    ProgressPeriod period, {
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    try {
      final cacheKey = '${userId}_${period.name}';
      
      // Check cache first
      final cached = _progressCache[cacheKey];
      if (cached != null && _isCacheValid(cached.calculatedAt)) {
        return cached;
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Calculating user progress stats',
        category: 'analytics',
        data: {'user_id': userId, 'period': period.name},
      );
      
      // Calculate date range
      final dateRange = _getDateRange(period, customStartDate, customEndDate);
      
      // Load user data
      final sessions = await _loadUserSessions(userId, dateRange.start, dateRange.end);
      final climbs = await _loadUserClimbs(userId, dateRange.start, dateRange.end);
      
      // Calculate statistics
      final stats = _calculateProgressStats(
        userId,
        period,
        dateRange.start,
        dateRange.end,
        sessions,
        climbs,
      );
      
      // Cache result
      _progressCache[cacheKey] = stats;
      
      _emitAnalyticsEvent(AnalyticsEvent.progressUpdated, userId, stats);
      
      return stats;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.analyticsServices,
        userAction: 'get_progress_stats',
      );
      
      return null;
    }
  }
  
  /// Get grade progression analysis
  Future<List<GradeProgression>> getGradeProgression(
    String userId, {
    ClimbingStyle? style,
    ProgressPeriod period = ProgressPeriod.year,
  }) async {
    try {
      final cacheKey = '${userId}_grades_${style?.name ?? 'all'}_${period.name}';
      
      // Check cache
      final cached = _gradeProgressionCache[cacheKey];
      if (cached != null) {
        return cached;
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Analyzing grade progression',
        category: 'analytics',
        data: {'user_id': userId, 'style': style?.name},
      );
      
      final dateRange = _getDateRange(period);
      final climbs = await _loadUserClimbs(userId, dateRange.start, dateRange.end);
      
      // Filter by style if specified
      final filteredClimbs = style != null
          ? climbs.where((c) => c.style == style).toList()
          : climbs;
      
      // Group by style and grade system
      final groupedClimbs = <String, List<ClimbRecord>>{};
      for (final climb in filteredClimbs) {
        final key = '${climb.style.name}_${climb.gradeSystem.name}';
        groupedClimbs.putIfAbsent(key, () => []).add(climb);
      }
      
      // Analyze progression for each group
      final progressions = <GradeProgression>[];
      for (final entry in groupedClimbs.entries) {
        final progression = _analyzeGradeProgression(entry.value);
        if (progression != null) {
          progressions.add(progression);
        }
      }
      
      // Cache result
      _gradeProgressionCache[cacheKey] = progressions;
      
      return progressions;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.analyticsServices,
        userAction: 'get_grade_progression',
      );
      
      return [];
    }
  }
  
  /// Get session performance analysis
  Future<List<SessionPerformance>> getSessionPerformance(
    String userId, {
    ProgressPeriod period = ProgressPeriod.month,
    int limit = 50,
  }) async {
    try {
      final cacheKey = '${userId}_sessions_${period.name}';
      
      // Check cache
      final cached = _sessionPerformanceCache[cacheKey];
      if (cached != null) {
        return cached.take(limit).toList();
      }
      
      final dateRange = _getDateRange(period);
      final sessions = await _loadUserSessions(userId, dateRange.start, dateRange.end);
      
      final performances = <SessionPerformance>[];
      for (final session in sessions) {
        final performance = await _analyzeSessionPerformance(session);
        if (performance != null) {
          performances.add(performance);
        }
      }
      
      // Sort by date (newest first)
      performances.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
      
      // Cache result
      _sessionPerformanceCache[cacheKey] = performances;
      
      return performances.take(limit).toList();
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.analyticsServices,
        userAction: 'get_session_performance',
      );
      
      return [];
    }
  }
  
  /// Get goal progress for user
  Future<List<GoalProgress>> getGoalProgress(String userId) async {
    try {
      // Check cache
      final cached = _goalProgressCache[userId];
      if (cached != null) {
        return cached;
      }
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Calculating goal progress',
        category: 'analytics',
        data: {'user_id': userId},
      );
      
      final goals = await _loadUserGoals(userId);
      final progressList = <GoalProgress>[];
      
      for (final goal in goals) {
        final progress = await _calculateGoalProgress(userId, goal);
        if (progress != null) {
          progressList.add(progress);
        }
      }
      
      // Cache result
      _goalProgressCache[userId] = progressList;
      
      return progressList;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.analyticsServices,
        userAction: 'get_goal_progress',
      );
      
      return [];
    }
  }
  
  /// Compare progress between periods
  Future<AnalyticsComparison?> compareProgress(
    String userId,
    ProgressPeriod period,
  ) async {
    try {
      final currentStats = await getUserProgressStats(userId, period);
      if (currentStats == null) return null;
      
      // Calculate previous period dates
      final previousRange = _getPreviousPeriodRange(period, currentStats.startDate);
      final previousStats = await getUserProgressStats(
        userId,
        period,
        customStartDate: previousRange.start,
        customEndDate: previousRange.end,
      );
      
      if (previousStats == null) return null;
      
      // Calculate changes
      final changes = _calculateChanges(currentStats, previousStats);
      final changeDescriptions = _generateChangeDescriptions(changes);
      final overallImprovement = _calculateOverallImprovement(changes);
      
      return AnalyticsComparison(
        period: period,
        currentPeriod: currentStats,
        previousPeriod: previousStats,
        changes: changes,
        changeDescriptions: changeDescriptions,
        overallImprovement: overallImprovement,
      );
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.analyticsServices,
        userAction: 'compare_progress',
      );
      
      return null;
    }
  }
  
  /// Update progress for a user (call after new climbs/sessions)
  Future<void> updateUserProgress(String userId) async {
    try {
      // Clear cache for user
      _progressCache.removeWhere((key, _) => key.startsWith(userId));
      _goalProgressCache.remove(userId);
      _sessionPerformanceCache.removeWhere((key, _) => key.startsWith(userId));
      _gradeProgressionCache.removeWhere((key, _) => key.startsWith(userId));
      
      // Recalculate current month progress
      await getUserProgressStats(userId, ProgressPeriod.month);
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'User progress updated',
        category: 'analytics',
        data: {'user_id': userId},
      );
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.analyticsServices,
        userAction: 'update_progress',
      );
    }
  }
  
  /// Get analytics insights and recommendations
  Future<List<String>> getAnalyticsInsights(String userId) async {
    try {
      final insights = <String>[];
      
      // Get recent progress
      final monthlyStats = await getUserProgressStats(userId, ProgressPeriod.month);
      final gradeProgressions = await getGradeProgression(userId);
      final goalProgress = await getGoalProgress(userId);
      
      if (monthlyStats != null) {
        // Success rate insights
        if (monthlyStats.successRate > 0.8) {
          insights.add('Excellent success rate! Consider challenging yourself with harder routes.');
        } else if (monthlyStats.successRate < 0.4) {
          insights.add('Focus on routes within your comfort zone to build confidence.');
        }
        
        // Volume insights
        if (monthlyStats.totalSessions < 4) {
          insights.add('Try to climb more regularly for better progress.');
        } else if (monthlyStats.totalSessions > 20) {
          insights.add('Great climbing frequency! Remember to include rest days.');
        }
      }
      
      // Grade progression insights
      for (final progression in gradeProgressions) {
        if (progression.direction == ProgressionDirection.improving) {
          insights.add('Great progress on ${progression.style.name}! Keep pushing those harder grades.');
        } else if (progression.direction == ProgressionDirection.declining) {
          insights.add('Consider focusing more on ${progression.style.name} technique and training.');
        }
      }
      
      // Goal insights
      final behindGoals = goalProgress.where((g) => !g.isOnTrack && !g.isCompleted).length;
      if (behindGoals > 0) {
        insights.add('You have $behindGoals goals that need attention to stay on track.');
      }
      
      return insights;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.analyticsServices,
        userAction: 'get_insights',
      );
      
      return [];
    }
  }
  
  /// Private methods
  void _emitAnalyticsEvent(AnalyticsEvent event, String userId, dynamic data) {
    final eventData = AnalyticsEventData(event: event, userId: userId, data: data);
    _eventController.add(eventData);
  }
  
  bool _isCacheValid(DateTime calculatedAt) {
    return DateTime.now().difference(calculatedAt) < cacheLifetime;
  }
  
  ({DateTime start, DateTime end}) _getDateRange(
    ProgressPeriod period, [
    DateTime? customStart,
    DateTime? customEnd,
  ]) {
    if (customStart != null && customEnd != null) {
      return (start: customStart, end: customEnd);
    }
    
    final now = DateTime.now();
    switch (period) {
      case ProgressPeriod.week:
        final start = now.subtract(const Duration(days: 7));
        return (start: start, end: now);
      case ProgressPeriod.month:
        final start = DateTime(now.year, now.month - 1, now.day);
        return (start: start, end: now);
      case ProgressPeriod.quarter:
        final start = DateTime(now.year, now.month - 3, now.day);
        return (start: start, end: now);
      case ProgressPeriod.year:
        final start = DateTime(now.year - 1, now.month, now.day);
        return (start: start, end: now);
      case ProgressPeriod.allTime:
        final start = DateTime(2020, 1, 1); // Arbitrary start date
        return (start: start, end: now);
    }
  }
  
  ({DateTime start, DateTime end}) _getPreviousPeriodRange(
    ProgressPeriod period,
    DateTime currentStart,
  ) {
    final duration = DateTime.now().difference(currentStart);
    final previousEnd = currentStart;
    final previousStart = currentStart.subtract(duration);
    return (start: previousStart, end: previousEnd);
  }
  
  UserProgressStats _calculateProgressStats(
    String userId,
    ProgressPeriod period,
    DateTime startDate,
    DateTime endDate,
    List<ClimbingSession> sessions,
    List<ClimbRecord> climbs,
  ) {
    // Calculate basic metrics
    final totalClimbs = climbs.length;
    final totalSessions = sessions.length;
    final successfulClimbs = climbs.where((c) => c.result == ClimbAttemptResult.success).length;
    final successRate = totalClimbs > 0 ? successfulClimbs / totalClimbs : 0.0;
    
    // Calculate total time
    final totalTime = sessions.fold<Duration>(
      Duration.zero,
      (total, session) => total + (session.endTime?.difference(session.startTime) ?? Duration.zero),
    );
    
    // Calculate unique counts
    final uniqueRoutes = climbs.map((c) => c.routeId).where((id) => id != null).toSet().length;
    final uniqueLocations = climbs.map((c) => c.locationId).where((id) => id != null).toSet().length;
    
    // Group by style
    final climbsByStyle = <ClimbingStyle, int>{};
    for (final climb in climbs) {
      climbsByStyle[climb.style] = (climbsByStyle[climb.style] ?? 0) + 1;
    }
    
    // Grade distribution
    final gradeDistribution = <String, int>{};
    for (final climb in climbs) {
      gradeDistribution[climb.grade] = (gradeDistribution[climb.grade] ?? 0) + 1;
    }
    
    // Calculate average and max grades (simplified)
    final grades = climbs.map((c) => c.grade).toList();
    final averageGrade = grades.isNotEmpty ? grades.first : null; // Simplified
    final maxGrade = grades.isNotEmpty ? grades.first : null; // Simplified
    
    // Generate progress points (simplified)
    final progressPoints = _generateProgressPoints(climbs, startDate, endDate);
    
    return UserProgressStats(
      userId: userId,
      period: period,
      startDate: startDate,
      endDate: endDate,
      totalClimbs: totalClimbs,
      totalSessions: totalSessions,
      totalClimbingTime: totalTime,
      successRate: successRate,
      averageGrade: averageGrade,
      maxGrade: maxGrade,
      uniqueRoutes: uniqueRoutes,
      uniqueLocations: uniqueLocations,
      climbsByStyle: climbsByStyle,
      gradeDistribution: gradeDistribution,
      progressPoints: progressPoints,
    );
  }
  
  List<ProgressDataPoint> _generateProgressPoints(
    List<ClimbRecord> climbs,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Group climbs by week and calculate success rate
    final points = <ProgressDataPoint>[];
    final weeklyClimbs = <DateTime, List<ClimbRecord>>{};
    
    for (final climb in climbs) {
      final weekStart = _getWeekStart(climb.createdAt);
      weeklyClimbs.putIfAbsent(weekStart, () => []).add(climb);
    }
    
    for (final entry in weeklyClimbs.entries) {
      final successful = entry.value.where((c) => c.result == ClimbAttemptResult.success).length;
      final rate = successful / entry.value.length;
      
      points.add(ProgressDataPoint(
        date: entry.key,
        value: rate,
        metric: AnalyticsMetric.successRate,
        unit: 'percentage',
      ));
    }
    
    return points;
  }
  
  DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }
  
  GradeProgression? _analyzeGradeProgression(List<ClimbRecord> climbs) {
    if (climbs.isEmpty) return null;
    
    // Sort by date
    climbs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    final firstClimb = climbs.first;
    final style = firstClimb.style;
    final gradeSystem = firstClimb.gradeSystem;
    
    // Generate progress points (simplified)
    final progressPoints = <GradeProgressPoint>[];
    String? personalBest;
    
    for (final climb in climbs) {
      if (climb.result == ClimbAttemptResult.success) {
        final isNewPB = personalBest == null || _isGradeHigher(climb.grade, personalBest, gradeSystem);
        if (isNewPB) {
          personalBest = climb.grade;
        }
        
        progressPoints.add(GradeProgressPoint(
          date: climb.createdAt,
          grade: climb.grade,
          gradeValue: _getGradeValue(climb.grade, gradeSystem),
          result: climb.result,
          isPersonalBest: isNewPB,
        ));
      }
    }
    
    // Analyze progression (simplified)
    final direction = progressPoints.length < 2 
        ? ProgressionDirection.insufficient_data
        : ProgressionDirection.improving; // Simplified
    
    return GradeProgression(
      style: style,
      gradeSystem: gradeSystem,
      progressPoints: progressPoints,
      direction: direction,
      progressionRate: 0.5, // Simplified
      currentGrade: personalBest,
      projectedGrade: personalBest,
      daysToNextGrade: 30, // Simplified
      confidence: 0.8,
    );
  }
  
  bool _isGradeHigher(String grade1, String grade2, GradeSystem system) {
    // Simplified grade comparison
    return _getGradeValue(grade1, system) > _getGradeValue(grade2, system);
  }
  
  int _getGradeValue(String grade, GradeSystem system) {
    // Simplified grade value calculation
    return grade.hashCode % 100;
  }
  
  Future<SessionPerformance?> _analyzeSessionPerformance(ClimbingSession session) async {
    try {
      final climbs = await _loadSessionClimbs(session.id);
      if (climbs.isEmpty) return null;
      
      final totalClimbs = climbs.length;
      final successfulClimbs = climbs.where((c) => c.result == ClimbAttemptResult.success).length;
      final successRate = successfulClimbs / totalClimbs;
      
      // Calculate style breakdown
      final styleBreakdown = <ClimbingStyle, int>{};
      for (final climb in climbs) {
        styleBreakdown[climb.style] = (styleBreakdown[climb.style] ?? 0) + 1;
      }
      
      // Calculate performance score (simplified)
      final performanceScore = successRate * 100;
      final performanceRating = _getPerformanceRating(performanceScore);
      
      // Generate achievements (simplified)
      final achievements = <String>[];
      if (successRate >= 0.8) achievements.add('High Success Rate');
      if (totalClimbs >= 20) achievements.add('High Volume Session');
      
      return SessionPerformance(
        sessionId: session.id,
        sessionDate: session.startTime,
        duration: session.endTime?.difference(session.startTime) ?? Duration.zero,
        totalClimbs: totalClimbs,
        successfulClimbs: successfulClimbs,
        successRate: successRate,
        maxGrade: climbs.isNotEmpty ? climbs.first.grade : null,
        averageAttempts: 1.5, // Simplified
        styleBreakdown: styleBreakdown,
        performanceScore: performanceScore,
        performanceRating: performanceRating,
        achievements: achievements,
      );
      
    } catch (error) {
      return null;
    }
  }
  
  String _getPerformanceRating(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Great';
    if (score >= 70) return 'Good';
    if (score >= 60) return 'Average';
    return 'Needs Improvement';
  }
  
  Future<GoalProgress?> _calculateGoalProgress(String userId, ClimbingGoal goal) async {
    try {
      // Load relevant data based on goal type
      final currentValue = await _getCurrentGoalValue(userId, goal);
      final progressPercentage = _calculateGoalPercentage(currentValue, goal.targetValue);
      
      final now = DateTime.now();
      final daysRemaining = goal.deadline?.difference(now).inDays ?? 0;
      
      // Calculate if on track (simplified)
      final isOnTrack = progressPercentage >= 50.0; // Simplified
      
      // Generate milestones
      final milestones = _generateGoalMilestones(goal, currentValue);
      
      return GoalProgress(
        goalId: goal.id,
        goal: goal,
        progressPercentage: progressPercentage,
        currentValue: currentValue,
        targetValue: goal.targetValue,
        isCompleted: progressPercentage >= 100.0,
        completedAt: progressPercentage >= 100.0 ? now : null,
        daysRemaining: daysRemaining,
        dailyTargetRate: 1.0, // Simplified
        isOnTrack: isOnTrack,
        status: isOnTrack ? 'On Track' : 'Behind',
        milestones: milestones,
      );
      
    } catch (error) {
      return null;
    }
  }
  
  double _calculateGoalPercentage(dynamic current, dynamic target) {
    if (current == null || target == null) return 0.0;
    
    if (current is num && target is num) {
      return (current / target * 100).clamp(0.0, 100.0);
    }
    
    return 0.0;
  }
  
  List<ProgressMilestone> _generateGoalMilestones(ClimbingGoal goal, dynamic currentValue) {
    return [
      ProgressMilestone(
        name: '25% Complete',
        percentage: 25.0,
        isReached: _calculateGoalPercentage(currentValue, goal.targetValue) >= 25.0,
        description: 'Quarter way to your goal!',
      ),
      ProgressMilestone(
        name: '50% Complete',
        percentage: 50.0,
        isReached: _calculateGoalPercentage(currentValue, goal.targetValue) >= 50.0,
        description: 'Halfway there!',
      ),
      ProgressMilestone(
        name: '75% Complete',
        percentage: 75.0,
        isReached: _calculateGoalPercentage(currentValue, goal.targetValue) >= 75.0,
        description: 'Almost there!',
      ),
      ProgressMilestone(
        name: 'Complete',
        percentage: 100.0,
        isReached: _calculateGoalPercentage(currentValue, goal.targetValue) >= 100.0,
        description: 'Goal achieved!',
      ),
    ];
  }
  
  Map<AnalyticsMetric, double> _calculateChanges(
    UserProgressStats current,
    UserProgressStats previous,
  ) {
    return {
      AnalyticsMetric.totalClimbs: (current.totalClimbs - previous.totalClimbs).toDouble(),
      AnalyticsMetric.totalSessions: (current.totalSessions - previous.totalSessions).toDouble(),
      AnalyticsMetric.successRate: current.successRate - previous.successRate,
      AnalyticsMetric.uniqueRoutes: (current.uniqueRoutes - previous.uniqueRoutes).toDouble(),
    };
  }
  
  Map<AnalyticsMetric, String> _generateChangeDescriptions(Map<AnalyticsMetric, double> changes) {
    final descriptions = <AnalyticsMetric, String>{};
    
    for (final entry in changes.entries) {
      final change = entry.value;
      final metric = entry.key;
      
      if (change > 0) {
        descriptions[metric] = '+${change.toStringAsFixed(1)}';
      } else if (change < 0) {
        descriptions[metric] = change.toStringAsFixed(1);
      } else {
        descriptions[metric] = 'No change';
      }
    }
    
    return descriptions;
  }
  
  double _calculateOverallImprovement(Map<AnalyticsMetric, double> changes) {
    // Simplified overall improvement calculation
    return changes.values.fold(0.0, (sum, change) => sum + change) / changes.length;
  }
  
  void _startBackgroundTasks() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(progressUpdateInterval, (_) async {
      await _cleanupCache();
    });
    
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(cacheLifetime, (_) async {
      await _cleanupCache();
    });
  }
  
  Future<void> _cleanupCache() async {
    final now = DateTime.now();
    
    // Clean progress cache
    _progressCache.removeWhere((key, stats) => 
      now.difference(stats.calculatedAt) > cacheLifetime);
    
    // Limit cache sizes
    if (_progressCache.length > maxCacheEntries) {
      final entries = _progressCache.entries.toList();
      entries.sort((a, b) => b.value.calculatedAt.compareTo(a.value.calculatedAt));
      _progressCache.clear();
      _progressCache.addEntries(entries.take(maxCacheEntries));
    }
  }
  
  // Mock implementations - replace with actual data access
  Future<List<ClimbingSession>> _loadUserSessions(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return []; // TODO: Load from database
  }
  
  Future<List<ClimbRecord>> _loadUserClimbs(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return []; // TODO: Load from database
  }
  
  Future<List<ClimbRecord>> _loadSessionClimbs(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return []; // TODO: Load from database
  }
  
  Future<List<ClimbingGoal>> _loadUserGoals(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return []; // TODO: Load from database
  }
  
  Future<dynamic> _getCurrentGoalValue(String userId, ClimbingGoal goal) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return 50; // TODO: Calculate based on goal type
  }
  
  /// Dispose resources
  void dispose() {
    _progressUpdateTimer?.cancel();
    _cacheCleanupTimer?.cancel();
    _eventController.close();
  }
} 