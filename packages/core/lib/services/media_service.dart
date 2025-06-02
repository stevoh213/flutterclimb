// Media Attachment Service
// Modular service for handling media uploads, storage, and thumbnails

import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/climbing_models.dart';
import '../monitoring/sentry_config.dart';
import '../validation/validation_service.dart';
import '../auth/auth_service.dart';

/// Media upload status
enum MediaUploadStatus {
  pending,
  uploading,
  processing,
  completed,
  failed,
  cancelled,
}

/// Media processing state
enum MediaProcessingState {
  none,
  thumbnailGeneration,
  compression,
  validation,
  completed,
  failed,
}

/// Media upload progress
class MediaUploadProgress {
  final String mediaId;
  final MediaUploadStatus status;
  final MediaProcessingState processingState;
  final double progress; // 0.0 to 1.0
  final int? bytesUploaded;
  final int? totalBytes;
  final String? errorMessage;
  final DateTime timestamp;
  
  const MediaUploadProgress({
    required this.mediaId,
    required this.status,
    required this.processingState,
    required this.progress,
    this.bytesUploaded,
    this.totalBytes,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  MediaUploadProgress copyWith({
    MediaUploadStatus? status,
    MediaProcessingState? processingState,
    double? progress,
    int? bytesUploaded,
    int? totalBytes,
    String? errorMessage,
  }) {
    return MediaUploadProgress(
      mediaId: mediaId,
      status: status ?? this.status,
      processingState: processingState ?? this.processingState,
      progress: progress ?? this.progress,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: DateTime.now(),
    );
  }
}

/// Media upload request
class MediaUploadRequest {
  final String localPath;
  final MediaType mediaType;
  final String? fileName;
  final Map<String, dynamic>? metadata;
  final String? attachToEntityId;
  final String? attachToEntityType;
  final bool generateThumbnail;
  final bool compressImage;
  final int? maxImageSize;
  final int? thumbnailSize;
  
  const MediaUploadRequest({
    required this.localPath,
    required this.mediaType,
    this.fileName,
    this.metadata,
    this.attachToEntityId,
    this.attachToEntityType,
    this.generateThumbnail = true,
    this.compressImage = true,
    this.maxImageSize = 2048,
    this.thumbnailSize = 300,
  });
}

/// Media processing options
class MediaProcessingOptions {
  final bool generateThumbnail;
  final bool compressImages;
  final bool extractMetadata;
  final bool validateContent;
  final int maxImageWidth;
  final int maxImageHeight;
  final int thumbnailSize;
  final double imageQuality;
  final bool stripExifData;
  
  const MediaProcessingOptions({
    this.generateThumbnail = true,
    this.compressImages = true,
    this.extractMetadata = true,
    this.validateContent = true,
    this.maxImageWidth = 2048,
    this.maxImageHeight = 2048,
    this.thumbnailSize = 300,
    this.imageQuality = 0.85,
    this.stripExifData = true,
  });
}

/// Media service events
enum MediaServiceEvent {
  uploadStarted,
  uploadProgress,
  uploadCompleted,
  uploadFailed,
  processingStarted,
  processingCompleted,
  processingFailed,
  attachmentCreated,
  attachmentRemoved,
  cacheUpdated,
}

/// Media event data
class MediaEventData {
  final MediaServiceEvent event;
  final String mediaId;
  final dynamic data;
  final DateTime timestamp;
  
  const MediaEventData({
    required this.event,
    required this.mediaId,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Media cache entry
class MediaCacheEntry {
  final MediaAttachment attachment;
  final Uint8List? thumbnailData;
  final Uint8List? fullData;
  final DateTime lastAccessed;
  final int accessCount;
  
  const MediaCacheEntry({
    required this.attachment,
    this.thumbnailData,
    this.fullData,
    DateTime? lastAccessed,
    this.accessCount = 1,
  }) : lastAccessed = lastAccessed ?? DateTime.now();
  
  MediaCacheEntry copyWith({
    MediaAttachment? attachment,
    Uint8List? thumbnailData,
    Uint8List? fullData,
    int? accessCount,
  }) {
    return MediaCacheEntry(
      attachment: attachment ?? this.attachment,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      fullData: fullData ?? this.fullData,
      lastAccessed: DateTime.now(),
      accessCount: accessCount ?? this.accessCount + 1,
    );
  }
}

/// Media Attachment Service
class MediaService {
  static MediaService? _instance;
  static MediaService get instance => _instance ??= MediaService._();
  MediaService._();
  
  // Current state
  final Map<String, MediaUploadProgress> _uploadProgress = {};
  final Map<String, MediaCacheEntry> _mediaCache = {};
  final List<MediaAttachment> _pendingUploads = [];
  final Set<String> _uploadQueue = {};
  
  // Event streams
  final _eventController = StreamController<MediaEventData>.broadcast();
  final _progressController = StreamController<MediaUploadProgress>.broadcast();
  
  // Timers
  Timer? _uploadRetryTimer;
  Timer? _cacheCleanupTimer;
  
  // Configuration
  static const Duration uploadRetryInterval = Duration(minutes: 5);
  static const Duration cacheCleanupInterval = Duration(hours: 6);
  static const int maxCacheSize = 100; // MB
  static const int maxCacheEntries = 500;
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> supportedVideoFormats = ['mp4', 'mov', 'avi'];
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB
  
  /// Active upload progress
  Map<String, MediaUploadProgress> get uploadProgress => 
    Map.unmodifiable(_uploadProgress);
  
  /// Pending uploads count
  int get pendingUploadsCount => _pendingUploads.length;
  
  /// Cache statistics
  Map<String, dynamic> get cacheStats => {
    'entries': _mediaCache.length,
    'size_mb': _calculateCacheSize() / (1024 * 1024),
    'hit_rate': _calculateCacheHitRate(),
  };
  
  /// Media events stream
  Stream<MediaEventData> get mediaEvents => _eventController.stream;
  
  /// Upload progress stream
  Stream<MediaUploadProgress> get uploadProgressStream => _progressController.stream;
  
  /// Initialize media service
  Future<void> initialize() async {
    try {
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Initializing media service',
        category: 'media',
      );
      
      // Load pending uploads
      await _loadPendingUploads();
      
      // Start background tasks
      _startBackgroundTasks();
      
      // Resume pending uploads
      await _resumePendingUploads();
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'media_init',
      );
    }
  }
  
  /// Upload media file
  Future<MediaAttachment?> uploadMedia(MediaUploadRequest request) async {
    try {
      // Validate request
      final validationResult = await ValidationService.instance.validateMediaFile(
        request.localPath,
        request.mediaType,
        maxFileSize,
      );
      
      if (!validationResult.isValid) {
        throw Exception('Media validation failed: ${validationResult.errors.join(', ')}');
      }
      
      // Generate unique media ID
      final mediaId = _generateMediaId();
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Starting media upload',
        category: 'media',
        data: {
          'media_id': mediaId,
          'type': request.mediaType.name,
          'size': await _getFileSize(request.localPath),
        },
      );
      
      // Create initial progress
      final progress = MediaUploadProgress(
        mediaId: mediaId,
        status: MediaUploadStatus.pending,
        processingState: MediaProcessingState.validation,
        progress: 0.0,
      );
      
      _uploadProgress[mediaId] = progress;
      _progressController.add(progress);
      _emitMediaEvent(MediaServiceEvent.uploadStarted, mediaId, request);
      
      // Process media
      final processedMedia = await _processMedia(mediaId, request);
      if (processedMedia == null) {
        _updateUploadProgress(mediaId, status: MediaUploadStatus.failed);
        return null;
      }
      
      // Create media attachment
      final attachment = MediaAttachment(
        id: mediaId,
        fileName: processedMedia['fileName'],
        filePath: processedMedia['filePath'],
        mediaType: request.mediaType,
        fileSize: processedMedia['fileSize'],
        mimeType: processedMedia['mimeType'],
        thumbnailPath: processedMedia['thumbnailPath'],
        metadata: processedMedia['metadata'],
        uploadStatus: UploadStatus.pending,
        entityId: request.attachToEntityId,
        entityType: request.attachToEntityType,
        createdAt: DateTime.now(),
      );
      
      // Queue for upload
      _pendingUploads.add(attachment);
      _uploadQueue.add(mediaId);
      await _savePendingUploads();
      
      // Start upload
      await _startUpload(attachment);
      
      return attachment;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'upload_media',
      );
      
      return null;
    }
  }
  
  /// Upload multiple media files
  Future<List<MediaAttachment>> uploadMultipleMedia(
    List<MediaUploadRequest> requests,
  ) async {
    try {
      final results = <MediaAttachment>[];
      
      // Process uploads in parallel (limited concurrency)
      const maxConcurrent = 3;
      for (int i = 0; i < requests.length; i += maxConcurrent) {
        final batch = requests.skip(i).take(maxConcurrent).toList();
        final batchResults = await Future.wait(
          batch.map((request) => uploadMedia(request)),
        );
        
        results.addAll(batchResults.whereType<MediaAttachment>());
      }
      
      return results;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'upload_multiple_media',
      );
      
      return [];
    }
  }
  
  /// Attach media to entity
  Future<bool> attachMediaToEntity(
    String mediaId,
    String entityId,
    String entityType,
  ) async {
    try {
      // Find media attachment
      final attachment = await _findMediaAttachment(mediaId);
      if (attachment == null) {
        throw Exception('Media attachment not found: $mediaId');
      }
      
      // Update attachment
      final updatedAttachment = attachment.copyWith(
        entityId: entityId,
        entityType: entityType,
      );
      
      // Save update
      await _updateMediaAttachment(updatedAttachment);
      
      _emitMediaEvent(MediaServiceEvent.attachmentCreated, mediaId, {
        'entity_id': entityId,
        'entity_type': entityType,
      });
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'attach_media',
      );
      
      return false;
    }
  }
  
  /// Remove media attachment
  Future<bool> removeMediaAttachment(String mediaId) async {
    try {
      // Cancel upload if in progress
      if (_uploadProgress.containsKey(mediaId)) {
        await cancelUpload(mediaId);
      }
      
      // Remove from pending uploads
      _pendingUploads.removeWhere((a) => a.id == mediaId);
      _uploadQueue.remove(mediaId);
      
      // Remove from cache
      _mediaCache.remove(mediaId);
      
      // Delete files
      await _deleteMediaFiles(mediaId);
      
      // Remove from database
      await _deleteMediaAttachment(mediaId);
      
      _emitMediaEvent(MediaServiceEvent.attachmentRemoved, mediaId, null);
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'remove_media',
      );
      
      return false;
    }
  }
  
  /// Get media attachments for entity
  Future<List<MediaAttachment>> getEntityMediaAttachments(
    String entityId,
    String entityType,
  ) async {
    try {
      // Check cache first
      final cached = _mediaCache.values
          .where((entry) => 
            entry.attachment.entityId == entityId &&
            entry.attachment.entityType == entityType)
          .map((entry) => entry.attachment)
          .toList();
      
      if (cached.isNotEmpty) {
        return cached;
      }
      
      // Load from database
      final attachments = await _loadEntityMediaAttachments(entityId, entityType);
      
      // Update cache
      for (final attachment in attachments) {
        _mediaCache[attachment.id] = MediaCacheEntry(attachment: attachment);
      }
      
      return attachments;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'get_entity_media',
      );
      
      return [];
    }
  }
  
  /// Get media thumbnail
  Future<Uint8List?> getMediaThumbnail(String mediaId) async {
    try {
      // Check cache first
      final cached = _mediaCache[mediaId];
      if (cached?.thumbnailData != null) {
        _mediaCache[mediaId] = cached!.copyWith();
        return cached.thumbnailData;
      }
      
      // Load from storage
      final thumbnailData = await _loadThumbnailData(mediaId);
      if (thumbnailData != null && cached != null) {
        _mediaCache[mediaId] = cached.copyWith(thumbnailData: thumbnailData);
      }
      
      return thumbnailData;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'get_thumbnail',
      );
      
      return null;
    }
  }
  
  /// Get full media data
  Future<Uint8List?> getMediaData(String mediaId) async {
    try {
      // Check cache first
      final cached = _mediaCache[mediaId];
      if (cached?.fullData != null) {
        _mediaCache[mediaId] = cached!.copyWith();
        return cached.fullData;
      }
      
      // Load from storage
      final mediaData = await _loadMediaData(mediaId);
      if (mediaData != null && cached != null) {
        _mediaCache[mediaId] = cached.copyWith(fullData: mediaData);
      }
      
      return mediaData;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'get_media_data',
      );
      
      return null;
    }
  }
  
  /// Cancel upload
  Future<bool> cancelUpload(String mediaId) async {
    try {
      if (!_uploadProgress.containsKey(mediaId)) {
        return false;
      }
      
      _updateUploadProgress(mediaId, status: MediaUploadStatus.cancelled);
      _uploadQueue.remove(mediaId);
      
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Upload cancelled',
        category: 'media',
        data: {'media_id': mediaId},
      );
      
      return true;
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'cancel_upload',
      );
      
      return false;
    }
  }
  
  /// Retry failed uploads
  Future<void> retryFailedUploads() async {
    try {
      final failedUploads = _pendingUploads
          .where((a) => a.uploadStatus == UploadStatus.failed)
          .toList();
      
      for (final attachment in failedUploads) {
        if (!_uploadQueue.contains(attachment.id)) {
          _uploadQueue.add(attachment.id);
          await _startUpload(attachment);
        }
      }
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'retry_uploads',
      );
    }
  }
  
  /// Clear media cache
  Future<void> clearCache() async {
    try {
      _mediaCache.clear();
      await _clearLocalMediaCache();
      
      _emitMediaEvent(MediaServiceEvent.cacheUpdated, '', null);
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'clear_cache',
      );
    }
  }
  
  /// Private methods
  void _emitMediaEvent(MediaServiceEvent event, String mediaId, dynamic data) {
    final eventData = MediaEventData(event: event, mediaId: mediaId, data: data);
    _eventController.add(eventData);
  }
  
  void _updateUploadProgress(
    String mediaId, {
    MediaUploadStatus? status,
    MediaProcessingState? processingState,
    double? progress,
    int? bytesUploaded,
    int? totalBytes,
    String? errorMessage,
  }) {
    final current = _uploadProgress[mediaId];
    if (current != null) {
      final updated = current.copyWith(
        status: status,
        processingState: processingState,
        progress: progress,
        bytesUploaded: bytesUploaded,
        totalBytes: totalBytes,
        errorMessage: errorMessage,
      );
      
      _uploadProgress[mediaId] = updated;
      _progressController.add(updated);
      
      if (status != null) {
        _emitMediaEvent(MediaServiceEvent.uploadProgress, mediaId, updated);
      }
    }
  }
  
  String _generateMediaId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'media_${timestamp}_$random';
  }
  
  Future<Map<String, dynamic>?> _processMedia(
    String mediaId,
    MediaUploadRequest request,
  ) async {
    try {
      _updateUploadProgress(
        mediaId,
        processingState: MediaProcessingState.validation,
        progress: 0.1,
      );
      
      // Validate file
      if (!await _fileExists(request.localPath)) {
        throw Exception('File not found: ${request.localPath}');
      }
      
      final fileSize = await _getFileSize(request.localPath);
      final mimeType = _getMimeType(request.localPath);
      
      _updateUploadProgress(
        mediaId,
        processingState: MediaProcessingState.compression,
        progress: 0.3,
      );
      
      // Process based on media type
      String? processedPath;
      String? thumbnailPath;
      Map<String, dynamic> metadata = {};
      
      if (request.mediaType == MediaType.image) {
        final result = await _processImage(request);
        processedPath = result['processedPath'];
        thumbnailPath = result['thumbnailPath'];
        metadata = result['metadata'];
      } else if (request.mediaType == MediaType.video) {
        final result = await _processVideo(request);
        processedPath = result['processedPath'];
        thumbnailPath = result['thumbnailPath'];
        metadata = result['metadata'];
      } else {
        processedPath = request.localPath;
      }
      
      _updateUploadProgress(
        mediaId,
        processingState: MediaProcessingState.completed,
        progress: 1.0,
      );
      
      return {
        'fileName': request.fileName ?? _getFileName(request.localPath),
        'filePath': processedPath,
        'fileSize': await _getFileSize(processedPath!),
        'mimeType': mimeType,
        'thumbnailPath': thumbnailPath,
        'metadata': metadata,
      };
      
    } catch (error) {
      _updateUploadProgress(
        mediaId,
        processingState: MediaProcessingState.failed,
        errorMessage: error.toString(),
      );
      
      return null;
    }
  }
  
  Future<void> _startUpload(MediaAttachment attachment) async {
    try {
      _updateUploadProgress(
        attachment.id,
        status: MediaUploadStatus.uploading,
        progress: 0.0,
      );
      
      // Simulate upload progress
      final totalBytes = attachment.fileSize;
      int uploadedBytes = 0;
      
      while (uploadedBytes < totalBytes && 
             _uploadQueue.contains(attachment.id)) {
        await Future.delayed(const Duration(milliseconds: 100));
        uploadedBytes = math.min(uploadedBytes + (totalBytes ~/ 20), totalBytes);
        
        _updateUploadProgress(
          attachment.id,
          progress: uploadedBytes / totalBytes,
          bytesUploaded: uploadedBytes,
          totalBytes: totalBytes,
        );
      }
      
      if (_uploadQueue.contains(attachment.id)) {
        // Mark as completed
        _updateUploadProgress(
          attachment.id,
          status: MediaUploadStatus.completed,
          progress: 1.0,
        );
        
        // Update attachment status
        final updatedAttachment = attachment.copyWith(
          uploadStatus: UploadStatus.completed,
          uploadedAt: DateTime.now(),
        );
        
        await _updateMediaAttachment(updatedAttachment);
        _uploadQueue.remove(attachment.id);
        _pendingUploads.removeWhere((a) => a.id == attachment.id);
        
        _emitMediaEvent(MediaServiceEvent.uploadCompleted, attachment.id, attachment);
      }
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.mediaServices,
        userAction: 'start_upload',
      );
      
      _updateUploadProgress(
        attachment.id,
        status: MediaUploadStatus.failed,
        errorMessage: error.toString(),
      );
      
      _emitMediaEvent(MediaServiceEvent.uploadFailed, attachment.id, error.toString());
    }
  }
  
  void _startBackgroundTasks() {
    _uploadRetryTimer?.cancel();
    _uploadRetryTimer = Timer.periodic(uploadRetryInterval, (_) async {
      await retryFailedUploads();
    });
    
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(cacheCleanupInterval, (_) async {
      await _cleanupCache();
    });
  }
  
  Future<void> _resumePendingUploads() async {
    for (final attachment in _pendingUploads) {
      if (attachment.uploadStatus == UploadStatus.pending ||
          attachment.uploadStatus == UploadStatus.failed) {
        _uploadQueue.add(attachment.id);
        await _startUpload(attachment);
      }
    }
  }
  
  Future<void> _cleanupCache() async {
    try {
      // Remove old entries if cache is too large
      if (_mediaCache.length > maxCacheEntries) {
        final entries = _mediaCache.entries.toList();
        entries.sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
        
        final toRemove = entries.take(_mediaCache.length - maxCacheEntries);
        for (final entry in toRemove) {
          _mediaCache.remove(entry.key);
        }
      }
      
      // Check cache size and remove large entries if needed
      while (_calculateCacheSize() > maxCacheSize * 1024 * 1024) {
        final largestEntry = _mediaCache.entries
            .where((e) => e.value.fullData != null)
            .reduce((a, b) => 
              (a.value.fullData?.length ?? 0) > (b.value.fullData?.length ?? 0) ? a : b);
        
        _mediaCache[largestEntry.key] = largestEntry.value.copyWith(
          fullData: null,
        );
      }
      
    } catch (error) {
      // Silent cleanup failure
    }
  }
  
  int _calculateCacheSize() {
    return _mediaCache.values.fold(0, (total, entry) {
      final thumbSize = entry.thumbnailData?.length ?? 0;
      final dataSize = entry.fullData?.length ?? 0;
      return total + thumbSize + dataSize;
    });
  }
  
  double _calculateCacheHitRate() {
    final totalAccesses = _mediaCache.values.fold(0, (total, entry) => total + entry.accessCount);
    return totalAccesses > 0 ? _mediaCache.length / totalAccesses : 0.0;
  }
  
  // Mock implementations - replace with actual implementations
  Future<bool> _fileExists(String path) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return true;
  }
  
  Future<int> _getFileSize(String path) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return Random().nextInt(5000000) + 100000; // 100KB - 5MB
  }
  
  String _getMimeType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }
  
  String _getFileName(String path) {
    return path.split('/').last;
  }
  
  Future<Map<String, dynamic>> _processImage(MediaUploadRequest request) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'processedPath': request.localPath,
      'thumbnailPath': '${request.localPath}_thumb',
      'metadata': {'width': 1920, 'height': 1080},
    };
  }
  
  Future<Map<String, dynamic>> _processVideo(MediaUploadRequest request) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      'processedPath': request.localPath,
      'thumbnailPath': '${request.localPath}_thumb.jpg',
      'metadata': {'duration': 30, 'width': 1920, 'height': 1080},
    };
  }
  
  Future<MediaAttachment?> _findMediaAttachment(String mediaId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _pendingUploads.firstWhere(
      (a) => a.id == mediaId,
      orElse: () => MediaAttachment(
        id: '',
        fileName: '',
        filePath: '',
        mediaType: MediaType.image,
        fileSize: 0,
        mimeType: '',
        uploadStatus: UploadStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
  }
  
  Future<void> _updateMediaAttachment(MediaAttachment attachment) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _pendingUploads.indexWhere((a) => a.id == attachment.id);
    if (index >= 0) {
      _pendingUploads[index] = attachment;
    }
  }
  
  Future<void> _deleteMediaFiles(String mediaId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
  
  Future<void> _deleteMediaAttachment(String mediaId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  Future<List<MediaAttachment>> _loadEntityMediaAttachments(
    String entityId,
    String entityType,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }
  
  Future<Uint8List?> _loadThumbnailData(String mediaId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return null;
  }
  
  Future<Uint8List?> _loadMediaData(String mediaId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return null;
  }
  
  Future<void> _loadPendingUploads() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _pendingUploads.clear();
  }
  
  Future<void> _savePendingUploads() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  Future<void> _clearLocalMediaCache() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
  
  /// Dispose resources
  void dispose() {
    _uploadRetryTimer?.cancel();
    _cacheCleanupTimer?.cancel();
    _eventController.close();
    _progressController.close();
  }
} 