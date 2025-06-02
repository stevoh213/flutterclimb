// Sentry Error Tracking Configuration
// Modular error tracking system following design principles

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';

/// Environment-aware Sentry configuration
class SentryConfig {
  static const String _dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
  
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  
  /// Initialize Sentry with climbing app specific configuration
  static Future<void> initialize() async {
    if (_dsn.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Sentry DSN not configured, error tracking disabled');
      }
      return;
    }
    
    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = _environment;
        options.release = _getAppVersion();
        options.dist = _getBuildNumber();
        
        // Performance monitoring
        options.tracesSampleRate = _getTracesSampleRate();
        options.profilesSampleRate = _getProfilesSampleRate();
        
        // Error filtering
        options.beforeSend = _filterErrors;
        options.beforeBreadcrumb = _filterBreadcrumbs;
        
        // User context
        options.sendDefaultPii = false; // Privacy first
        
        // Debug settings
        options.debug = kDebugMode;
        options.diagnosticLevel = kDebugMode 
          ? SentryLevel.debug 
          : SentryLevel.warning;
        
        // App-specific tags
        options.initialScope = _buildInitialScope();
        
        // Auto-capture settings
        options.autoAppStart = true;
        options.enableAutoPerformanceTracing = true;
        options.attachStacktrace = true;
        options.attachScreenshot = false; // Privacy
        options.attachViewHierarchy = false; // Privacy
        
        // Network tracking
        options.enableNetworkTracking = true;
        options.captureFailedRequests = true;
        
        // Session tracking
        options.enableAutoSessionTracking = true;
        options.sessionTrackingIntervalMillis = 30000; // 30 seconds
      },
    );
  }
  
  /// Filter errors to reduce noise and protect privacy
  static SentryEvent? _filterErrors(SentryEvent event, {Hint? hint}) {
    // Don't send errors in development
    if (kDebugMode) return null;
    
    // Filter out common Flutter/Dart errors that aren't actionable
    final exception = event.throwable;
    if (exception != null) {
      final exceptionString = exception.toString();
      
      // Network errors that are expected
      if (exceptionString.contains('SocketException') ||
          exceptionString.contains('TimeoutException') ||
          exceptionString.contains('HandshakeException')) {
        return null;
      }
      
      // State errors during hot reload
      if (exceptionString.contains('setState() called after dispose()')) {
        return null;
      }
      
      // Navigation errors during development
      if (exceptionString.contains('Navigator operation requested')) {
        return null;
      }
    }
    
    // Add climbing-specific context
    return event.copyWith(
      tags: {
        ...?event.tags,
        'app.component': 'climbing_logbook',
        'app.platform': _getPlatform(),
      },
      contexts: {
        ...?event.contexts,
        'climbing_context': _getClimbingContext(),
      },
    );
  }
  
  /// Filter breadcrumbs to reduce noise
  static Breadcrumb? _filterBreadcrumbs(Breadcrumb crumb, {Hint? hint}) {
    // Skip navigation breadcrumbs in development
    if (kDebugMode && crumb.category == 'navigation') {
      return null;
    }
    
    // Skip frequent UI interactions
    if (crumb.category == 'ui.click' && 
        crumb.message?.contains('grade_selector') == true) {
      return null;
    }
    
    return crumb;
  }
  
  /// Build initial scope with app context
  static Scope _buildInitialScope() {
    final scope = Scope();
    
    scope.setTag('app.name', 'climbing_logbook');
    scope.setTag('app.platform', _getPlatform());
    scope.setTag('app.version', _getAppVersion());
    
    // Don't set user info for privacy
    // Will be set contextually when needed
    
    return scope;
  }
  
  /// Get sample rate based on environment
  static double _getTracesSampleRate() {
    switch (_environment) {
      case 'production':
        return 0.1; // 10% sampling in production
      case 'staging':
        return 0.5; // 50% sampling in staging
      default:
        return 1.0; // 100% sampling in development
    }
  }
  
  /// Get profiles sample rate
  static double _getProfilesSampleRate() {
    switch (_environment) {
      case 'production':
        return 0.05; // 5% profiling in production
      case 'staging':
        return 0.2; // 20% profiling in staging
      default:
        return 0.5; // 50% profiling in development
    }
  }
  
  /// Get app version from pubspec
  static String _getAppVersion() {
    return const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.0.0+1',
    );
  }
  
  /// Get build number
  static String _getBuildNumber() {
    return const String.fromEnvironment(
      'BUILD_NUMBER',
      defaultValue: '1',
    );
  }
  
  /// Get platform identifier
  static String _getPlatform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }
  
  /// Get climbing-specific context
  static Map<String, dynamic> _getClimbingContext() {
    return {
      'module': 'core',
      'feature': 'error_tracking',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Error categories for climbing app
enum ErrorCategory {
  authentication('auth'),
  sessionManagement('session'),
  climbLogging('climb_logging'),
  dataSync('data_sync'),
  voiceProcessing('voice_processing'),
  mediaUpload('media_upload'),
  database('database'),
  network('network'),
  ui('ui'),
  unknown('unknown');
  
  const ErrorCategory(this.value);
  final String value;
}

/// Custom error reporter for climbing app
class ClimbingErrorReporter {
  /// Report error with climbing-specific context
  static Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    ErrorCategory category = ErrorCategory.unknown,
    Map<String, dynamic>? extra,
    String? userAction,
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      print('🚨 Error [${category.value}]: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
      return;
    }
    
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('error.category', category.value);
        scope.setTag('error.fatal', fatal.toString());
        
        if (userAction != null) {
          scope.setContext('user_action', {'action': userAction});
        }
        
        if (extra != null) {
          scope.setContext('extra_data', extra);
        }
        
        scope.setLevel(fatal ? SentryLevel.error : SentryLevel.warning);
      },
    );
  }
  
  /// Report performance issue
  static Future<void> reportPerformanceIssue(
    String operation,
    Duration duration, {
    Map<String, dynamic>? data,
  }) async {
    if (kDebugMode) {
      print('⚡ Performance [${operation}]: ${duration.inMilliseconds}ms');
      return;
    }
    
    final transaction = Sentry.startTransaction(
      operation,
      'performance_issue',
      description: 'Operation took ${duration.inMilliseconds}ms',
    );
    
    transaction.setData('duration_ms', duration.inMilliseconds);
    transaction.setData('operation', operation);
    
    if (data != null) {
      for (final entry in data.entries) {
        transaction.setData(entry.key, entry.value);
      }
    }
    
    await transaction.finish(status: const SpanStatus.ok());
  }
  
  /// Add breadcrumb for climbing action
  static void addClimbingBreadcrumb(
    String message, {
    String category = 'climbing',
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    if (kDebugMode) {
      print('🍞 Breadcrumb [$category]: $message');
      return;
    }
    
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
        timestamp: DateTime.now(),
      ),
    );
  }
  
  /// Set user context (privacy-safe)
  static void setUserContext({
    String? userId,
    String? userLevel, // e.g., "5.10a_climber"
    int? sessionCount,
  }) {
    if (kDebugMode) return;
    
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: userId,
        // Don't include email or personal data
        data: {
          if (userLevel != null) 'climbing_level': userLevel,
          if (sessionCount != null) 'session_count': sessionCount,
        },
      ));
    });
  }
  
  /// Clear user context (on logout)
  static void clearUserContext() {
    if (kDebugMode) return;
    
    Sentry.configureScope((scope) {
      scope.clearUser();
    });
  }
  
  /// Start performance transaction
  static ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
  }) {
    return Sentry.startTransaction(
      name,
      operation,
      description: description,
    );
  }
  
  /// Report user feedback (for handled errors)
  static Future<void> reportUserFeedback(
    String feedbackId,
    String userEmail,
    String comment,
  ) async {
    if (kDebugMode) {
      print('📝 User feedback: $comment');
      return;
    }
    
    await Sentry.captureUserFeedback(SentryUserFeedback(
      eventId: SentryId.fromId(feedbackId),
      email: userEmail,
      comments: comment,
    ));
  }
}

/// Mixin for automatic error reporting in widgets
mixin SentryErrorReporting {
  void reportWidgetError(
    dynamic error,
    StackTrace? stackTrace,
    String widgetName,
  ) {
    ClimbingErrorReporter.reportError(
      error,
      stackTrace,
      category: ErrorCategory.ui,
      extra: {'widget': widgetName},
      userAction: 'widget_interaction',
    );
  }
}

/// Extension for easy error reporting in services
extension ServiceErrorReporting on Object {
  Future<void> reportServiceError(
    dynamic error,
    StackTrace? stackTrace,
    ErrorCategory category, {
    String? operation,
    Map<String, dynamic>? extra,
  }) async {
    await ClimbingErrorReporter.reportError(
      error,
      stackTrace,
      category: category,
      extra: {
        'service': runtimeType.toString(),
        if (operation != null) 'operation': operation,
        ...?extra,
      },
    );
  }
} 