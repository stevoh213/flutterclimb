// Data Validation Service
// Centralized validation system following design principles

import '../models/climbing_models.dart';
import '../monitoring/sentry_config.dart';
import 'validation_rules.dart';

/// Centralized validation service
class ValidationService {
  // Static validators for reuse
  static final Map<String, Validator> _validators = {};
  
  /// Initialize validation service with common validators
  static void initialize() {
    // Common field validators
    _validators['email'] = const EmailValidator('email');
    _validators['phone'] = const PhoneValidator('phone');
    _validators['website'] = const UrlValidator('website');
    
    // Climbing-specific validators
    _validators['session_duration'] = SessionDurationValidator();
    _validators['climb_logic'] = ClimbLogicValidator();
    _validators['media_file'] = MediaFileValidator();
    _validators['goal'] = GoalValidator();
    
    ClimbingErrorReporter.addClimbingBreadcrumb(
      'Validation service initialized',
      category: 'validation',
    );
  }
  
  /// Validate user profile
  static ValidationResult validateUserProfile(UserProfile profile) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', profile.id));
    result = result.combine(_validateRequired('email', profile.email));
    
    // Email format
    if (profile.email.isNotEmpty) {
      result = result.combine(_getValidator('email').validate(profile.email));
    }
    
    // Full name length
    if (profile.fullName != null) {
      result = result.combine(
        const LengthValidator('fullName', maxLength: 100).validate(profile.fullName)
      );
    }
    
    return result;
  }
  
  /// Validate user preferences
  static ValidationResult validateUserPreferences(UserPreferences preferences) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', preferences.id));
    result = result.combine(_validateRequired('userId', preferences.userId));
    
    return result;
  }
  
  /// Validate climbing location
  static ValidationResult validateClimbingLocation(ClimbingLocation location) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', location.id));
    result = result.combine(_validateRequired('name', location.name));
    result = result.combine(_validateRequired('type', location.type));
    
    // Name length
    result = result.combine(
      const LengthValidator('name', minLength: 2, maxLength: 200).validate(location.name)
    );
    
    // Address length
    if (location.address != null) {
      result = result.combine(
        const LengthValidator('address', maxLength: 500).validate(location.address)
      );
    }
    
    // Website URL format
    if (location.website != null) {
      result = result.combine(_getValidator('website').validate(location.website));
    }
    
    // Phone format
    if (location.phone != null) {
      result = result.combine(_getValidator('phone').validate(location.phone));
    }
    
    // Route count range
    result = result.combine(
      const RangeValidator<int>('routeCount', min: 0, max: 10000).validate(location.routeCount)
    );
    
    // Coordinate validation
    if (location.latitude != null) {
      result = result.combine(
        const RangeValidator<double>('latitude', min: -90.0, max: 90.0).validate(location.latitude)
      );
    }
    
    if (location.longitude != null) {
      result = result.combine(
        const RangeValidator<double>('longitude', min: -180.0, max: 180.0).validate(location.longitude)
      );
    }
    
    return result;
  }
  
  /// Validate climbing session
  static ValidationResult validateClimbingSession(ClimbingSession session) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', session.id));
    result = result.combine(_validateRequired('userId', session.userId));
    result = result.combine(_validateRequired('startTime', session.startTime));
    result = result.combine(_validateRequired('locationName', session.locationName));
    result = result.combine(_validateRequired('locationType', session.locationType));
    
    // Location name length
    result = result.combine(
      const LengthValidator('locationName', minLength: 1, maxLength: 200).validate(session.locationName)
    );
    
    // Notes length
    if (session.notes != null) {
      result = result.combine(
        const LengthValidator('notes', maxLength: 2000).validate(session.notes)
      );
    }
    
    // Start time validation
    result = result.combine(
      const DateRangeValidator(
        'startTime',
        minDate: null, // Allow historical sessions
        allowFuture: false, // Don't allow future start times
      ).validate(session.startTime)
    );
    
    // End time validation
    if (session.endTime != null) {
      result = result.combine(
        DateRangeValidator(
          'endTime',
          minDate: session.startTime, // Must be after start time
          allowFuture: false,
        ).validate(session.endTime)
      );
    }
    
    // Session-specific logic validation
    result = result.combine(_getValidator('session_duration').validate(session));
    
    return result;
  }
  
  /// Validate climb record
  static ValidationResult validateClimbRecord(ClimbRecord climb) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', climb.id));
    result = result.combine(_validateRequired('sessionId', climb.sessionId));
    result = result.combine(_validateRequired('userId', climb.userId));
    result = result.combine(_validateRequired('grade', climb.grade));
    result = result.combine(_validateRequired('style', climb.style));
    result = result.combine(_validateRequired('result', climb.result));
    
    // Grade validation
    result = result.combine(
      ClimbingGradeValidator('grade', climb.gradeSystem).validate(climb.grade)
    );
    
    // Route name length
    if (climb.routeName != null) {
      result = result.combine(
        const LengthValidator('routeName', maxLength: 200).validate(climb.routeName)
      );
    }
    
    // Attempts validation
    result = result.combine(
      const RangeValidator<int>('attempts', min: 1, max: 100).validate(climb.attempts)
    );
    
    // Rating validations
    if (climb.qualityRating != null) {
      result = result.combine(
        const RangeValidator<int>('qualityRating', min: 1, max: 5).validate(climb.qualityRating)
      );
    }
    
    if (climb.difficultyPerception != null) {
      result = result.combine(
        const RangeValidator<int>('difficultyPerception', min: 1, max: 5).validate(climb.difficultyPerception)
      );
    }
    
    if (climb.holdsQuality != null) {
      result = result.combine(
        const RangeValidator<int>('holdsQuality', min: 1, max: 5).validate(climb.holdsQuality)
      );
    }
    
    if (climb.movementQuality != null) {
      result = result.combine(
        const RangeValidator<int>('movementQuality', min: 1, max: 5).validate(climb.movementQuality)
      );
    }
    
    // Count validations
    result = result.combine(
      const RangeValidator<int>('fallCount', min: 0, max: 100).validate(climb.fallCount)
    );
    
    result = result.combine(
      const RangeValidator<int>('restCount', min: 0, max: 100).validate(climb.restCount)
    );
    
    // Route length validation
    if (climb.routeLength != null) {
      result = result.combine(
        const RangeValidator<int>('routeLength', min: 1, max: 5000).validate(climb.routeLength)
      );
    }
    
    // Duration validation
    if (climb.durationSeconds != null) {
      result = result.combine(
        const RangeValidator<int>('durationSeconds', min: 1, max: 7200).validate(climb.durationSeconds)
      );
    }
    
    // Notes length validation
    if (climb.notes != null) {
      result = result.combine(
        const LengthValidator('notes', maxLength: 1000).validate(climb.notes)
      );
    }
    
    if (climb.betaNotes != null) {
      result = result.combine(
        const LengthValidator('betaNotes', maxLength: 1000).validate(climb.betaNotes)
      );
    }
    
    // Confidence score validation
    result = result.combine(
      const RangeValidator<double>('confidenceScore', min: 0.0, max: 1.0).validate(climb.confidenceScore)
    );
    
    // Climb logic validation
    result = result.combine(_getValidator('climb_logic').validate(climb));
    
    return result;
  }
  
  /// Validate climbing goal
  static ValidationResult validateClimbingGoal(ClimbingGoal goal) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', goal.id));
    result = result.combine(_validateRequired('userId', goal.userId));
    result = result.combine(_validateRequired('title', goal.title));
    result = result.combine(_validateRequired('goalType', goal.goalType));
    
    // Title length
    result = result.combine(
      const LengthValidator('title', minLength: 3, maxLength: 200).validate(goal.title)
    );
    
    // Description length
    if (goal.description != null) {
      result = result.combine(
        const LengthValidator('description', maxLength: 1000).validate(goal.description)
      );
    }
    
    // Target grade validation
    if (goal.targetGrade != null) {
      // Try to validate as different grade systems
      final gradeValidation = _validateGradeAnySystem(goal.targetGrade!);
      result = result.combine(gradeValidation);
    }
    
    // Goal-specific validation
    result = result.combine(_getValidator('goal').validate(goal));
    
    return result;
  }
  
  /// Validate media attachment
  static ValidationResult validateMediaAttachment(MediaAttachment media) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', media.id));
    result = result.combine(_validateRequired('userId', media.userId));
    result = result.combine(_validateRequired('type', media.type));
    result = result.combine(_validateRequired('filePath', media.filePath));
    
    // Type validation
    const validTypes = ['photo', 'video', 'audio'];
    if (!validTypes.contains(media.type)) {
      result = result.combine(ValidationResult.invalid([
        ValidationError(
          field: 'type',
          message: 'Type must be one of: ${validTypes.join(', ')}',
          type: ValidationErrorType.format,
          value: media.type,
        ),
      ]));
    }
    
    // File path validation
    if (media.filePath.isEmpty) {
      result = result.combine(ValidationResult.invalid([
        const ValidationError(
          field: 'filePath',
          message: 'File path cannot be empty',
          type: ValidationErrorType.required,
        ),
      ]));
    }
    
    // MIME type validation
    if (media.mimeType != null) {
      result = result.combine(_validateMimeType(media.type, media.mimeType!));
    }
    
    // Upload attempts validation
    result = result.combine(
      const RangeValidator<int>('uploadAttempts', min: 0, max: 10).validate(media.uploadAttempts)
    );
    
    // Media-specific validation
    result = result.combine(_getValidator('media_file').validate(media));
    
    return result;
  }
  
  /// Validate route information
  static ValidationResult validateRouteInfo(RouteInfo route) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', route.id));
    result = result.combine(_validateRequired('name', route.name));
    result = result.combine(_validateRequired('grade', route.grade));
    result = result.combine(_validateRequired('gradeSystem', route.gradeSystem));
    result = result.combine(_validateRequired('style', route.style));
    
    // Name length
    result = result.combine(
      const LengthValidator('name', minLength: 1, maxLength: 200).validate(route.name)
    );
    
    // Grade validation
    result = result.combine(
      ClimbingGradeValidator('grade', route.gradeSystem).validate(route.grade)
    );
    
    // Length validation
    if (route.length != null) {
      result = result.combine(
        const RangeValidator<int>('length', min: 1, max: 5000).validate(route.length)
      );
    }
    
    // Pitches validation
    result = result.combine(
      const RangeValidator<int>('pitches', min: 1, max: 50).validate(route.pitches)
    );
    
    // Section length
    if (route.section != null) {
      result = result.combine(
        const LengthValidator('section', maxLength: 100).validate(route.section)
      );
    }
    
    // Description length
    if (route.description != null) {
      result = result.combine(
        const LengthValidator('description', maxLength: 2000).validate(route.description)
      );
    }
    
    // Beta notes length
    if (route.betaNotes != null) {
      result = result.combine(
        const LengthValidator('betaNotes', maxLength: 2000).validate(route.betaNotes)
      );
    }
    
    // Average rating validation
    if (route.avgRating != null) {
      result = result.combine(
        const RangeValidator<double>('avgRating', min: 1.0, max: 5.0).validate(route.avgRating)
      );
    }
    
    // Total ascents validation
    result = result.combine(
      const RangeValidator<int>('totalAscents', min: 0, max: 100000).validate(route.totalAscents)
    );
    
    return result;
  }
  
  /// Validate sync queue item
  static ValidationResult validateSyncQueueItem(SyncQueueItem item) {
    var result = const ValidationResult.valid();
    
    // Required fields
    result = result.combine(_validateRequired('id', item.id));
    result = result.combine(_validateRequired('userId', item.userId));
    result = result.combine(_validateRequired('entityType', item.entityType));
    result = result.combine(_validateRequired('entityId', item.entityId));
    result = result.combine(_validateRequired('operation', item.operation));
    
    // Entity type validation
    const validEntityTypes = [
      'session', 'climb', 'media', 'goal', 'location', 'route', 'user_profile', 'user_preferences'
    ];
    if (!validEntityTypes.contains(item.entityType)) {
      result = result.combine(ValidationResult.invalid([
        ValidationError(
          field: 'entityType',
          message: 'Entity type must be one of: ${validEntityTypes.join(', ')}',
          type: ValidationErrorType.format,
          value: item.entityType,
        ),
      ]));
    }
    
    // Operation validation
    const validOperations = ['create', 'update', 'delete', 'upsert'];
    if (!validOperations.contains(item.operation)) {
      result = result.combine(ValidationResult.invalid([
        ValidationError(
          field: 'operation',
          message: 'Operation must be one of: ${validOperations.join(', ')}',
          type: ValidationErrorType.format,
          value: item.operation,
        ),
      ]));
    }
    
    // Attempts validation
    result = result.combine(
      const RangeValidator<int>('attempts', min: 0, max: 20).validate(item.attempts)
    );
    
    result = result.combine(
      const RangeValidator<int>('maxAttempts', min: 1, max: 20).validate(item.maxAttempts)
    );
    
    // Priority validation
    result = result.combine(
      const RangeValidator<int>('priority', min: 1, max: 100).validate(item.priority)
    );
    
    return result;
  }
  
  /// Validate a grade against any supported grade system
  static ValidationResult _validateGradeAnySystem(String grade) {
    final systems = [GradeSystem.yds, GradeSystem.french, GradeSystem.vScale, GradeSystem.uiaa];
    
    for (final system in systems) {
      final validator = ClimbingGradeValidator('targetGrade', system);
      final result = validator.validate(grade);
      if (result.isValid) {
        return result;
      }
    }
    
    return ValidationResult.invalid([
      ValidationError(
        field: 'targetGrade',
        message: 'Target grade is not valid in any supported grade system',
        type: ValidationErrorType.format,
        value: grade,
      ),
    ]);
  }
  
  /// Validate MIME type against media type
  static ValidationResult _validateMimeType(String mediaType, String mimeType) {
    final validMimeTypes = {
      'photo': ['image/jpeg', 'image/png', 'image/webp', 'image/heic'],
      'video': ['video/mp4', 'video/mov', 'video/avi', 'video/webm'],
      'audio': ['audio/mp3', 'audio/wav', 'audio/aac', 'audio/m4a'],
    };
    
    final validTypes = validMimeTypes[mediaType];
    if (validTypes == null || !validTypes.contains(mimeType.toLowerCase())) {
      return ValidationResult.invalid([
        ValidationError(
          field: 'mimeType',
          message: 'Invalid MIME type for $mediaType: $mimeType',
          type: ValidationErrorType.format,
          value: mimeType,
        ),
      ]);
    }
    
    return const ValidationResult.valid();
  }
  
  /// Validate required field
  static ValidationResult _validateRequired(String fieldName, dynamic value) {
    return RequiredValidator(fieldName).validate(value);
  }
  
  /// Get validator from registry
  static Validator _getValidator(String key) {
    final validator = _validators[key];
    if (validator == null) {
      throw ArgumentError('Validator not found: $key');
    }
    return validator;
  }
  
  /// Batch validation for multiple items
  static Map<int, ValidationResult> validateBatch<T>(
    List<T> items,
    ValidationResult Function(T) validator,
  ) {
    final results = <int, ValidationResult>{};
    
    for (int i = 0; i < items.length; i++) {
      try {
        results[i] = validator(items[i]);
      } catch (error, stackTrace) {
        results[i] = ValidationResult.invalid([
          ValidationError(
            field: 'item_$i',
            message: 'Validation error: $error',
            type: ValidationErrorType.custom,
          ),
        ]);
        
        ClimbingErrorReporter.reportError(
          error,
          stackTrace,
          category: ErrorCategory.unknown,
          extra: {'batch_index': i, 'item_type': T.toString()},
        );
      }
    }
    
    return results;
  }
  
  /// Get summary of validation results
  static ValidationSummary summarizeResults(Map<int, ValidationResult> results) {
    int validCount = 0;
    int invalidCount = 0;
    final allErrors = <ValidationError>[];
    
    for (final result in results.values) {
      if (result.isValid) {
        validCount++;
      } else {
        invalidCount++;
        allErrors.addAll(result.errors);
      }
    }
    
    return ValidationSummary(
      totalItems: results.length,
      validItems: validCount,
      invalidItems: invalidCount,
      errors: allErrors,
    );
  }
}

/// Summary of batch validation results
class ValidationSummary {
  final int totalItems;
  final int validItems;
  final int invalidItems;
  final List<ValidationError> errors;
  
  const ValidationSummary({
    required this.totalItems,
    required this.validItems,
    required this.invalidItems,
    required this.errors,
  });
  
  bool get allValid => invalidItems == 0;
  double get validPercentage => totalItems > 0 ? (validItems / totalItems) * 100 : 0;
  
  @override
  String toString() {
    return 'ValidationSummary(total: $totalItems, valid: $validItems, invalid: $invalidItems, ${validPercentage.toStringAsFixed(1)}% valid)';
  }
} 