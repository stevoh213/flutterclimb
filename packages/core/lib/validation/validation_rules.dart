// Data Validation Rules
// Modular validation system following design principles

import 'dart:core';
import '../models/climbing_models.dart';

/// Base validation result
class ValidationResult {
  final bool isValid;
  final List<ValidationError> errors;
  
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
  });
  
  const ValidationResult.valid() : this(isValid: true);
  
  const ValidationResult.invalid(List<ValidationError> errors) 
    : this(isValid: false, errors: errors);
    
  ValidationResult combine(ValidationResult other) {
    return ValidationResult(
      isValid: isValid && other.isValid,
      errors: [...errors, ...other.errors],
    );
  }
}

/// Validation error with context
class ValidationError {
  final String field;
  final String message;
  final ValidationErrorType type;
  final dynamic value;
  
  const ValidationError({
    required this.field,
    required this.message,
    required this.type,
    this.value,
  });
  
  @override
  String toString() => '$field: $message';
}

/// Types of validation errors
enum ValidationErrorType {
  required,
  format,
  range,
  length,
  pattern,
  logic,
  custom,
}

/// Base validator interface
abstract class Validator<T> {
  ValidationResult validate(T value);
}

/// Required field validator
class RequiredValidator<T> implements Validator<T?> {
  final String fieldName;
  
  const RequiredValidator(this.fieldName);
  
  @override
  ValidationResult validate(T? value) {
    if (value == null || 
        (value is String && value.trim().isEmpty) ||
        (value is List && value.isEmpty)) {
      return ValidationResult.invalid([
        ValidationError(
          field: fieldName,
          message: '$fieldName is required',
          type: ValidationErrorType.required,
          value: value,
        ),
      ]);
    }
    return const ValidationResult.valid();
  }
}

/// String length validator
class LengthValidator implements Validator<String?> {
  final String fieldName;
  final int? minLength;
  final int? maxLength;
  
  const LengthValidator(
    this.fieldName, {
    this.minLength,
    this.maxLength,
  });
  
  @override
  ValidationResult validate(String? value) {
    if (value == null) return const ValidationResult.valid();
    
    final errors = <ValidationError>[];
    
    if (minLength != null && value.length < minLength!) {
      errors.add(ValidationError(
        field: fieldName,
        message: '$fieldName must be at least $minLength characters',
        type: ValidationErrorType.length,
        value: value,
      ));
    }
    
    if (maxLength != null && value.length > maxLength!) {
      errors.add(ValidationError(
        field: fieldName,
        message: '$fieldName must not exceed $maxLength characters',
        type: ValidationErrorType.length,
        value: value,
      ));
    }
    
    return errors.isEmpty 
      ? const ValidationResult.valid()
      : ValidationResult.invalid(errors);
  }
}

/// Numeric range validator
class RangeValidator<T extends num> implements Validator<T?> {
  final String fieldName;
  final T? min;
  final T? max;
  
  const RangeValidator(
    this.fieldName, {
    this.min,
    this.max,
  });
  
  @override
  ValidationResult validate(T? value) {
    if (value == null) return const ValidationResult.valid();
    
    final errors = <ValidationError>[];
    
    if (min != null && value < min!) {
      errors.add(ValidationError(
        field: fieldName,
        message: '$fieldName must be at least $min',
        type: ValidationErrorType.range,
        value: value,
      ));
    }
    
    if (max != null && value > max!) {
      errors.add(ValidationError(
        field: fieldName,
        message: '$fieldName must not exceed $max',
        type: ValidationErrorType.range,
        value: value,
      ));
    }
    
    return errors.isEmpty 
      ? const ValidationResult.valid()
      : ValidationResult.invalid(errors);
  }
}

/// Email format validator
class EmailValidator implements Validator<String?> {
  final String fieldName;
  
  const EmailValidator(this.fieldName);
  
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );
  
  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    
    if (!_emailRegex.hasMatch(value)) {
      return ValidationResult.invalid([
        ValidationError(
          field: fieldName,
          message: '$fieldName must be a valid email address',
          type: ValidationErrorType.format,
          value: value,
        ),
      ]);
    }
    
    return const ValidationResult.valid();
  }
}

/// URL format validator
class UrlValidator implements Validator<String?> {
  final String fieldName;
  
  const UrlValidator(this.fieldName);
  
  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return ValidationResult.invalid([
        ValidationError(
          field: fieldName,
          message: '$fieldName must be a valid URL',
          type: ValidationErrorType.format,
          value: value,
        ),
      ]);
    }
    
    return const ValidationResult.valid();
  }
}

/// Phone number validator
class PhoneValidator implements Validator<String?> {
  final String fieldName;
  
  const PhoneValidator(this.fieldName);
  
  static final RegExp _phoneRegex = RegExp(
    r'^\+?[\d\s\-\(\)\.]{10,}$'
  );
  
  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    
    if (!_phoneRegex.hasMatch(value)) {
      return ValidationResult.invalid([
        ValidationError(
          field: fieldName,
          message: '$fieldName must be a valid phone number',
          type: ValidationErrorType.format,
          value: value,
        ),
      ]);
    }
    
    return const ValidationResult.valid();
  }
}

/// Climbing grade validator
class ClimbingGradeValidator implements Validator<String?> {
  final String fieldName;
  final GradeSystem gradeSystem;
  
  const ClimbingGradeValidator(this.fieldName, this.gradeSystem);
  
  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    
    final isValid = _isValidGrade(value, gradeSystem);
    if (!isValid) {
      return ValidationResult.invalid([
        ValidationError(
          field: fieldName,
          message: '$fieldName is not a valid ${gradeSystem.name} grade',
          type: ValidationErrorType.format,
          value: value,
        ),
      ]);
    }
    
    return const ValidationResult.valid();
  }
  
  bool _isValidGrade(String grade, GradeSystem system) {
    switch (system) {
      case GradeSystem.yds:
        return _isValidYdsGrade(grade);
      case GradeSystem.french:
        return _isValidFrenchGrade(grade);
      case GradeSystem.vScale:
        return _isValidVGrade(grade);
      case GradeSystem.uiaa:
        return _isValidUiaaGrade(grade);
    }
  }
  
  bool _isValidYdsGrade(String grade) {
    final regex = RegExp(r'^5\.\d{1,2}[a-d]?(\+|-)?(/A\d)?$');
    return regex.hasMatch(grade);
  }
  
  bool _isValidFrenchGrade(String grade) {
    final regex = RegExp(r'^\d[a-c](\+)?$');
    return regex.hasMatch(grade);
  }
  
  bool _isValidVGrade(String grade) {
    final regex = RegExp(r'^V\d{1,2}(\+|-)?$');
    return regex.hasMatch(grade);
  }
  
  bool _isValidUiaaGrade(String grade) {
    final regex = RegExp(r'^(I{1,3}X?|IV|VI{1,3}|IX|X{1,2})(\+|-)?$');
    return regex.hasMatch(grade);
  }
}

/// Date range validator
class DateRangeValidator implements Validator<DateTime?> {
  final String fieldName;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool allowFuture;
  
  const DateRangeValidator(
    this.fieldName, {
    this.minDate,
    this.maxDate,
    this.allowFuture = true,
  });
  
  @override
  ValidationResult validate(DateTime? value) {
    if (value == null) return const ValidationResult.valid();
    
    final errors = <ValidationError>[];
    final now = DateTime.now();
    
    if (!allowFuture && value.isAfter(now)) {
      errors.add(ValidationError(
        field: fieldName,
        message: '$fieldName cannot be in the future',
        type: ValidationErrorType.logic,
        value: value,
      ));
    }
    
    if (minDate != null && value.isBefore(minDate!)) {
      errors.add(ValidationError(
        field: fieldName,
        message: '$fieldName cannot be before ${_formatDate(minDate!)}',
        type: ValidationErrorType.range,
        value: value,
      ));
    }
    
    if (maxDate != null && value.isAfter(maxDate!)) {
      errors.add(ValidationError(
        field: fieldName,
        message: '$fieldName cannot be after ${_formatDate(maxDate!)}',
        type: ValidationErrorType.range,
        value: value,
      ));
    }
    
    return errors.isEmpty 
      ? const ValidationResult.valid()
      : ValidationResult.invalid(errors);
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Session duration validator
class SessionDurationValidator implements Validator<ClimbingSession> {
  @override
  ValidationResult validate(ClimbingSession session) {
    final errors = <ValidationError>[];
    
    if (session.endTime != null) {
      final duration = session.duration!;
      
      // Sessions shouldn't be longer than 24 hours
      if (duration.inHours > 24) {
        errors.add(const ValidationError(
          field: 'duration',
          message: 'Session duration cannot exceed 24 hours',
          type: ValidationErrorType.logic,
        ));
      }
      
      // Sessions shouldn't be negative duration
      if (duration.isNegative) {
        errors.add(const ValidationError(
          field: 'duration',
          message: 'Session end time cannot be before start time',
          type: ValidationErrorType.logic,
        ));
      }
      
      // Very short sessions might be errors
      if (duration.inMinutes < 5) {
        errors.add(const ValidationError(
          field: 'duration',
          message: 'Session duration seems unusually short (less than 5 minutes)',
          type: ValidationErrorType.logic,
        ));
      }
    }
    
    return errors.isEmpty 
      ? const ValidationResult.valid()
      : ValidationResult.invalid(errors);
  }
}

/// Climb logical consistency validator
class ClimbLogicValidator implements Validator<ClimbRecord> {
  @override
  ValidationResult validate(ClimbRecord climb) {
    final errors = <ValidationError>[];
    
    // Flash/onsight should only have 1 attempt
    if ((climb.result == ClimbResult.flash || climb.result == ClimbResult.onsight) &&
        climb.attempts > 1) {
      errors.add(ValidationError(
        field: 'attempts',
        message: '${climb.result.name} should only have 1 attempt',
        type: ValidationErrorType.logic,
        value: climb.attempts,
      ));
    }
    
    // Falls shouldn't exceed attempts
    if (climb.fallCount > climb.attempts) {
      errors.add(ValidationError(
        field: 'fallCount',
        message: 'Fall count cannot exceed number of attempts',
        type: ValidationErrorType.logic,
        value: climb.fallCount,
      ));
    }
    
    // Boulder problems shouldn't have route length > 50 feet
    if (climb.style == ClimbingStyle.boulder && 
        climb.routeLength != null && 
        climb.routeLength! > 50) {
      errors.add(ValidationError(
        field: 'routeLength',
        message: 'Boulder problems are typically less than 50 feet',
        type: ValidationErrorType.logic,
        value: climb.routeLength,
      ));
    }
    
    // Lead climbs should typically be > 30 feet
    if (climb.style == ClimbingStyle.lead && 
        climb.routeLength != null && 
        climb.routeLength! < 30) {
      errors.add(ValidationError(
        field: 'routeLength',
        message: 'Lead climbs are typically longer than 30 feet',
        type: ValidationErrorType.logic,
        value: climb.routeLength,
      ));
    }
    
    // Duration validation if available
    if (climb.duration != null) {
      final duration = climb.duration!;
      
      if (duration.inHours > 2) {
        errors.add(const ValidationError(
          field: 'duration',
          message: 'Climb duration seems unusually long (over 2 hours)',
          type: ValidationErrorType.logic,
        ));
      }
      
      if (duration.inSeconds < 10) {
        errors.add(const ValidationError(
          field: 'duration',
          message: 'Climb duration seems unusually short (under 10 seconds)',
          type: ValidationErrorType.logic,
        ));
      }
    }
    
    return errors.isEmpty 
      ? const ValidationResult.valid()
      : ValidationResult.invalid(errors);
  }
}

/// Media file validator
class MediaFileValidator implements Validator<MediaAttachment> {
  static const int maxPhotoSizeMB = 10;
  static const int maxVideoSizeMB = 100;
  static const int maxAudioSizeMB = 50;
  
  @override
  ValidationResult validate(MediaAttachment media) {
    final errors = <ValidationError>[];
    
    // File size validation
    if (media.fileSize != null) {
      final sizeMB = media.fileSize! / (1024 * 1024);
      int? maxSize;
      
      switch (media.type) {
        case 'photo':
          maxSize = maxPhotoSizeMB;
          break;
        case 'video':
          maxSize = maxVideoSizeMB;
          break;
        case 'audio':
          maxSize = maxAudioSizeMB;
          break;
      }
      
      if (maxSize != null && sizeMB > maxSize) {
        errors.add(ValidationError(
          field: 'fileSize',
          message: '${media.type} file size cannot exceed ${maxSize}MB',
          type: ValidationErrorType.range,
          value: sizeMB,
        ));
      }
    }
    
    // Duration validation for video/audio
    if ((media.type == 'video' || media.type == 'audio') && 
        media.duration != null) {
      const maxDurationMinutes = 30;
      final durationMinutes = media.duration! / 60;
      
      if (durationMinutes > maxDurationMinutes) {
        errors.add(ValidationError(
          field: 'duration',
          message: '${media.type} duration cannot exceed ${maxDurationMinutes} minutes',
          type: ValidationErrorType.range,
          value: durationMinutes,
        ));
      }
    }
    
    // Image dimensions validation
    if (media.type == 'photo') {
      const maxDimension = 8000; // 8K resolution
      
      if (media.width != null && media.width! > maxDimension) {
        errors.add(ValidationError(
          field: 'width',
          message: 'Image width cannot exceed ${maxDimension}px',
          type: ValidationErrorType.range,
          value: media.width,
        ));
      }
      
      if (media.height != null && media.height! > maxDimension) {
        errors.add(ValidationError(
          field: 'height',
          message: 'Image height cannot exceed ${maxDimension}px',
          type: ValidationErrorType.range,
          value: media.height,
        ));
      }
    }
    
    return errors.isEmpty 
      ? const ValidationResult.valid()
      : ValidationResult.invalid(errors);
  }
}

/// Goal validation
class GoalValidator implements Validator<ClimbingGoal> {
  @override
  ValidationResult validate(ClimbingGoal goal) {
    final errors = <ValidationError>[];
    
    // Target date should be in the future for active goals
    if (goal.isActive && goal.targetDate != null) {
      if (goal.targetDate!.isBefore(DateTime.now())) {
        errors.add(const ValidationError(
          field: 'targetDate',
          message: 'Target date should be in the future for active goals',
          type: ValidationErrorType.logic,
        ));
      }
      
      // Target date shouldn't be too far in the future (> 5 years)
      final fiveYearsFromNow = DateTime.now().add(const Duration(days: 1825));
      if (goal.targetDate!.isAfter(fiveYearsFromNow)) {
        errors.add(const ValidationError(
          field: 'targetDate',
          message: 'Target date should not be more than 5 years in the future',
          type: ValidationErrorType.logic,
        ));
      }
    }
    
    // Progress percentage validation
    if (goal.progressPercentage < 0 || goal.progressPercentage > 100) {
      errors.add(ValidationError(
        field: 'progressPercentage',
        message: 'Progress percentage must be between 0 and 100',
        type: ValidationErrorType.range,
        value: goal.progressPercentage,
      ));
    }
    
    return errors.isEmpty 
      ? const ValidationResult.valid()
      : ValidationResult.invalid(errors);
  }
} 