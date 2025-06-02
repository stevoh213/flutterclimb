// Offline-First Data Synchronization Service
// Modular sync system following design principles

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/climbing_models.dart';
import '../monitoring/sentry_config.dart';

/// Sync priorities for queue management
enum SyncPriority {
  low(1),
  normal(5),
  high(10),
  critical(20);
  
  const SyncPriority(this.value);
  final int value;
}

/// Conflict resolution strategies
enum ConflictStrategy {
  serverWins,
  clientWins,
  lastWriteWins,
  userChoice,
  merge,
}

/// Sync operation types
enum SyncOperation {
  create,
  update,
  delete,
  upsert,
}

/// Sync result status
enum SyncResultStatus {
  success,
  conflict,
  error,
  cancelled,
}

/// Result of a sync operation
@immutable
class SyncResult {
  final SyncResultStatus status;
  final String? error;
  final Map<String, dynamic>? conflictData;
  final String? entityId;
  
  const SyncResult({
    required this.status,
    this.error,
    this.conflictData,
    this.entityId,
  });
  
  bool get isSuccess => status == SyncResultStatus.success;
  bool get hasConflict => status == SyncResultStatus.conflict;
  bool get hasError => status == SyncResultStatus.error;
}

/// Interface for data repositories that support sync
abstract class SyncableRepository<T> {
  /// Entity type identifier
  String get entityType;
  
  /// Get local data for sync
  Future<List<T>> getLocalChanges();
  
  /// Apply remote changes locally
  Future<void> applyRemoteChanges(List<T> entities);
  
  /// Get entity by ID
  Future<T?> getById(String id);
  
  /// Delete entity locally
  Future<void> deleteLocal(String id);
  
  /// Serialize entity for transmission
  Map<String, dynamic> serialize(T entity);
  
  /// Deserialize entity from remote data
  T deserialize(Map<String, dynamic> data);
  
  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime();
  
  /// Update last sync timestamp
  Future<void> setLastSyncTime(DateTime timestamp);
}

/// Offline-first synchronization service
class SyncService {
  final Map<String, SyncableRepository> _repositories = {};
  final List<StreamController<SyncResult>> _syncControllers = [];
  final Map<String, Timer> _retryTimers = {};
  
  // Configuration
  static const int maxRetryAttempts = 5;
  static const Duration baseRetryDelay = Duration(seconds: 5);
  static const Duration syncBatchTimeout = Duration(seconds: 30);
  static const int maxBatchSize = 50;
  
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  
  /// Register a repository for synchronization
  void registerRepository<T>(SyncableRepository<T> repository) {
    _repositories[repository.entityType] = repository;
    
    if (kDebugMode) {
      print('📝 Registered sync repository: ${repository.entityType}');
    }
  }
  
  /// Start periodic sync (every 5 minutes when online)
  void startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncAll(),
    );
  }
  
  /// Stop periodic sync
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }
  
  /// Sync all registered repositories
  Future<Map<String, SyncResult>> syncAll({
    ConflictStrategy strategy = ConflictStrategy.lastWriteWins,
  }) async {
    if (_isSyncing) {
      if (kDebugMode) {
        print('⚠️ Sync already in progress, skipping');
      }
      return {};
    }
    
    _isSyncing = true;
    final results = <String, SyncResult>{};
    
    try {
      ClimbingErrorReporter.addClimbingBreadcrumb(
        'Starting sync for ${_repositories.length} repositories',
        category: 'sync',
      );
      
      // Sync each repository
      for (final entry in _repositories.entries) {
        final entityType = entry.key;
        final repository = entry.value;
        
        try {
          final result = await _syncRepository(repository, strategy);
          results[entityType] = result;
          
          ClimbingErrorReporter.addClimbingBreadcrumb(
            'Synced $entityType: ${result.status}',
            category: 'sync',
            data: {'entity_type': entityType, 'status': result.status.toString()},
          );
        } catch (error, stackTrace) {
          final result = SyncResult(
            status: SyncResultStatus.error,
            error: error.toString(),
          );
          results[entityType] = result;
          
          await ClimbingErrorReporter.reportError(
            error,
            stackTrace,
            category: ErrorCategory.dataSync,
            extra: {'entity_type': entityType},
            userAction: 'sync_repository',
          );
        }
      }
      
      // Emit sync completion event
      _emitSyncEvent(SyncResult(status: SyncResultStatus.success));
      
    } finally {
      _isSyncing = false;
    }
    
    return results;
  }
  
  /// Sync a specific entity type
  Future<SyncResult> syncEntityType(
    String entityType, {
    ConflictStrategy strategy = ConflictStrategy.lastWriteWins,
  }) async {
    final repository = _repositories[entityType];
    if (repository == null) {
      return SyncResult(
        status: SyncResultStatus.error,
        error: 'Repository not found for $entityType',
      );
    }
    
    return _syncRepository(repository, strategy);
  }
  
  /// Queue an operation for sync
  Future<void> queueOperation(
    String entityType,
    String entityId,
    SyncOperation operation,
    Map<String, dynamic>? data, {
    SyncPriority priority = SyncPriority.normal,
    String? batchId,
  }) async {
    final queueItem = SyncQueueItem(
      id: _generateId(),
      userId: _getCurrentUserId(),
      entityType: entityType,
      entityId: entityId,
      operation: operation.name,
      data: data,
      priority: priority.value,
      batchId: batchId,
      nextRetry: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    await _saveSyncQueueItem(queueItem);
    
    ClimbingErrorReporter.addClimbingBreadcrumb(
      'Queued ${operation.name} for $entityType',
      category: 'sync',
      data: {
        'entity_type': entityType,
        'operation': operation.name,
        'priority': priority.value,
      },
    );
    
    // Try immediate sync if online
    if (await _isOnline()) {
      unawaited(_processSyncQueue());
    }
  }
  
  /// Process the sync queue
  Future<void> _processSyncQueue() async {
    final pendingItems = await _getPendingSyncItems();
    if (pendingItems.isEmpty) return;
    
    // Group by priority and batch
    final batches = _groupSyncItems(pendingItems);
    
    for (final batch in batches) {
      await _processSyncBatch(batch);
    }
  }
  
  /// Sync a single repository
  Future<SyncResult> _syncRepository(
    SyncableRepository repository,
    ConflictStrategy strategy,
  ) async {
    try {
      // Get local changes
      final localChanges = await repository.getLocalChanges();
      
      // Upload local changes
      if (localChanges.isNotEmpty) {
        final uploadResult = await _uploadChanges(repository, localChanges);
        if (!uploadResult.isSuccess) {
          return uploadResult;
        }
      }
      
      // Download remote changes
      final downloadResult = await _downloadChanges(repository, strategy);
      if (!downloadResult.isSuccess) {
        return downloadResult;
      }
      
      // Update last sync time
      await repository.setLastSyncTime(DateTime.now());
      
      return SyncResult(status: SyncResultStatus.success);
      
    } catch (error, stackTrace) {
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.dataSync,
        extra: {'repository': repository.entityType},
      );
      
      return SyncResult(
        status: SyncResultStatus.error,
        error: error.toString(),
      );
    }
  }
  
  /// Upload local changes to server
  Future<SyncResult> _uploadChanges(
    SyncableRepository repository,
    List<dynamic> changes,
  ) async {
    try {
      final batches = _createBatches(changes, maxBatchSize);
      
      for (final batch in batches) {
        final serializedBatch = batch.map((e) => repository.serialize(e)).toList();
        
        // Simulate API call (replace with actual implementation)
        await _uploadBatch(repository.entityType, serializedBatch);
      }
      
      return SyncResult(status: SyncResultStatus.success);
      
    } catch (error) {
      return SyncResult(
        status: SyncResultStatus.error,
        error: 'Upload failed: $error',
      );
    }
  }
  
  /// Download remote changes from server
  Future<SyncResult> _downloadChanges(
    SyncableRepository repository,
    ConflictStrategy strategy,
  ) async {
    try {
      final lastSync = await repository.getLastSyncTime();
      
      // Simulate API call (replace with actual implementation)
      final remoteData = await _downloadUpdates(
        repository.entityType,
        lastSync,
      );
      
      if (remoteData.isEmpty) {
        return SyncResult(status: SyncResultStatus.success);
      }
      
      // Handle conflicts
      final resolvedData = await _resolveConflicts(
        repository,
        remoteData,
        strategy,
      );
      
      // Apply changes locally
      final entities = resolvedData.map((data) => repository.deserialize(data)).toList();
      await repository.applyRemoteChanges(entities);
      
      return SyncResult(status: SyncResultStatus.success);
      
    } catch (error) {
      return SyncResult(
        status: SyncResultStatus.error,
        error: 'Download failed: $error',
      );
    }
  }
  
  /// Resolve conflicts between local and remote data
  Future<List<Map<String, dynamic>>> _resolveConflicts(
    SyncableRepository repository,
    List<Map<String, dynamic>> remoteData,
    ConflictStrategy strategy,
  ) async {
    final resolved = <Map<String, dynamic>>[];
    
    for (final remoteItem in remoteData) {
      final entityId = remoteItem['id'] as String;
      final localItem = await repository.getById(entityId);
      
      if (localItem == null) {
        // No conflict - new remote item
        resolved.add(remoteItem);
        continue;
      }
      
      final localData = repository.serialize(localItem);
      final conflict = _detectConflict(localData, remoteItem);
      
      if (!conflict) {
        // No conflict - items are the same
        resolved.add(remoteItem);
        continue;
      }
      
      // Resolve conflict based on strategy
      final resolvedItem = await _applyConflictStrategy(
        localData,
        remoteItem,
        strategy,
      );
      
      resolved.add(resolvedItem);
    }
    
    return resolved;
  }
  
  /// Detect if there's a conflict between local and remote data
  bool _detectConflict(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localUpdated = DateTime.tryParse(local['updated_at'] ?? '');
    final remoteUpdated = DateTime.tryParse(remote['updated_at'] ?? '');
    
    if (localUpdated == null || remoteUpdated == null) {
      return false; // Can't determine, assume no conflict
    }
    
    // Simple conflict detection based on content hash
    final localHash = _generateContentHash(local);
    final remoteHash = _generateContentHash(remote);
    
    return localHash != remoteHash && localUpdated.isAfter(remoteUpdated);
  }
  
  /// Apply conflict resolution strategy
  Future<Map<String, dynamic>> _applyConflictStrategy(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    ConflictStrategy strategy,
  ) async {
    switch (strategy) {
      case ConflictStrategy.serverWins:
        return remote;
        
      case ConflictStrategy.clientWins:
        return local;
        
      case ConflictStrategy.lastWriteWins:
        final localUpdated = DateTime.tryParse(local['updated_at'] ?? '');
        final remoteUpdated = DateTime.tryParse(remote['updated_at'] ?? '');
        
        if (localUpdated != null && remoteUpdated != null) {
          return localUpdated.isAfter(remoteUpdated) ? local : remote;
        }
        return remote;
        
      case ConflictStrategy.userChoice:
        // Emit conflict event for user resolution
        _emitConflictEvent(local, remote);
        return remote; // Default to remote while waiting for user input
        
      case ConflictStrategy.merge:
        return _mergeConflictingData(local, remote);
    }
  }
  
  /// Merge conflicting data intelligently
  Map<String, dynamic> _mergeConflictingData(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = Map<String, dynamic>.from(remote);
    
    // Preserve local changes to certain fields
    const preserveLocalFields = ['notes', 'user_preferences'];
    
    for (final field in preserveLocalFields) {
      if (local.containsKey(field) && local[field] != null) {
        merged[field] = local[field];
      }
    }
    
    // Use latest timestamp
    merged['updated_at'] = DateTime.now().toIso8601String();
    
    return merged;
  }
  
  /// Process a batch of sync items
  Future<void> _processSyncBatch(List<SyncQueueItem> batch) async {
    for (final item in batch) {
      try {
        await _processSyncItem(item);
        await _removeSyncQueueItem(item.id);
        
      } catch (error, stackTrace) {
        await _handleSyncItemError(item, error, stackTrace);
      }
    }
  }
  
  /// Process a single sync item
  Future<void> _processSyncItem(SyncQueueItem item) async {
    final repository = _repositories[item.entityType];
    if (repository == null) {
      throw Exception('Repository not found for ${item.entityType}');
    }
    
    switch (SyncOperation.values.byName(item.operation)) {
      case SyncOperation.create:
        await _createRemoteEntity(item);
        break;
      case SyncOperation.update:
        await _updateRemoteEntity(item);
        break;
      case SyncOperation.delete:
        await _deleteRemoteEntity(item);
        break;
      case SyncOperation.upsert:
        await _upsertRemoteEntity(item);
        break;
    }
  }
  
  /// Group sync items by priority and batch ID
  List<List<SyncQueueItem>> _groupSyncItems(List<SyncQueueItem> items) {
    // Sort by priority (highest first)
    items.sort((a, b) => b.priority.compareTo(a.priority));
    
    final batches = <List<SyncQueueItem>>[];
    final currentBatch = <SyncQueueItem>[];
    
    for (final item in items) {
      currentBatch.add(item);
      
      if (currentBatch.length >= maxBatchSize) {
        batches.add(List.from(currentBatch));
        currentBatch.clear();
      }
    }
    
    if (currentBatch.isNotEmpty) {
      batches.add(currentBatch);
    }
    
    return batches;
  }
  
  /// Create batches from a list of items
  List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }
  
  /// Handle sync item error with exponential backoff
  Future<void> _handleSyncItemError(
    SyncQueueItem item,
    dynamic error,
    StackTrace stackTrace,
  ) async {
    final newAttempts = item.attempts + 1;
    
    if (newAttempts >= maxRetryAttempts) {
      // Max retries reached, remove from queue
      await _removeSyncQueueItem(item.id);
      
      await ClimbingErrorReporter.reportError(
        error,
        stackTrace,
        category: ErrorCategory.dataSync,
        extra: {
          'sync_item_id': item.id,
          'entity_type': item.entityType,
          'attempts': newAttempts,
        },
        fatal: true,
      );
      return;
    }
    
    // Calculate exponential backoff delay
    final delayMs = baseRetryDelay.inMilliseconds * pow(2, newAttempts - 1);
    final jitter = Random().nextInt(1000); // Add jitter to prevent thundering herd
    final nextRetry = DateTime.now().add(Duration(milliseconds: delayMs + jitter));
    
    // Update sync item with new retry info
    final updatedItem = item.copyWith(
      attempts: newAttempts,
      lastError: error.toString(),
      nextRetry: nextRetry,
      updatedAt: DateTime.now(),
    );
    
    await _updateSyncQueueItem(updatedItem);
    
    // Schedule retry
    _scheduleRetry(updatedItem);
    
    await ClimbingErrorReporter.reportError(
      error,
      stackTrace,
      category: ErrorCategory.dataSync,
      extra: {
        'sync_item_id': item.id,
        'entity_type': item.entityType,
        'attempts': newAttempts,
        'next_retry': nextRetry.toIso8601String(),
      },
    );
  }
  
  /// Schedule a retry for a failed sync item
  void _scheduleRetry(SyncQueueItem item) {
    final delay = item.nextRetry!.difference(DateTime.now());
    
    if (delay.isNegative) {
      // Should retry now
      unawaited(_processSyncItem(item));
      return;
    }
    
    _retryTimers[item.id]?.cancel();
    _retryTimers[item.id] = Timer(delay, () {
      _retryTimers.remove(item.id);
      unawaited(_processSyncItem(item));
    });
  }
  
  /// Emit sync events to listeners
  void _emitSyncEvent(SyncResult result) {
    for (final controller in _syncControllers) {
      if (!controller.isClosed) {
        controller.add(result);
      }
    }
  }
  
  /// Emit conflict events for user resolution
  void _emitConflictEvent(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final result = SyncResult(
      status: SyncResultStatus.conflict,
      conflictData: {
        'local': local,
        'remote': remote,
      },
    );
    _emitSyncEvent(result);
  }
  
  /// Generate a simple content hash for conflict detection
  String _generateContentHash(Map<String, dynamic> data) {
    final relevantData = Map<String, dynamic>.from(data);
    relevantData.removeWhere((key, value) => 
        key == 'updated_at' || key == 'created_at' || key == 'id');
    
    final jsonString = jsonEncode(relevantData);
    return jsonString.hashCode.toString();
  }
  
  /// Generate unique ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(1000).toString();
  }
  
  /// Get current user ID (implement based on auth system)
  String _getCurrentUserId() {
    // TODO: Implement based on your auth system
    return 'current_user_id';
  }
  
  /// Check if device is online
  Future<bool> _isOnline() async {
    // TODO: Implement network connectivity check
    return true;
  }
  
  // Mock implementations - replace with actual API calls
  Future<void> _uploadBatch(String entityType, List<Map<String, dynamic>> batch) async {
    // TODO: Implement actual API upload
    await Future.delayed(Duration(milliseconds: 100));
  }
  
  Future<List<Map<String, dynamic>>> _downloadUpdates(
    String entityType,
    DateTime? since,
  ) async {
    // TODO: Implement actual API download
    await Future.delayed(Duration(milliseconds: 100));
    return [];
  }
  
  Future<void> _createRemoteEntity(SyncQueueItem item) async {
    // TODO: Implement create API call
  }
  
  Future<void> _updateRemoteEntity(SyncQueueItem item) async {
    // TODO: Implement update API call
  }
  
  Future<void> _deleteRemoteEntity(SyncQueueItem item) async {
    // TODO: Implement delete API call
  }
  
  Future<void> _upsertRemoteEntity(SyncQueueItem item) async {
    // TODO: Implement upsert API call
  }
  
  // Mock database operations - replace with actual implementation
  Future<void> _saveSyncQueueItem(SyncQueueItem item) async {
    // TODO: Save to local database
  }
  
  Future<List<SyncQueueItem>> _getPendingSyncItems() async {
    // TODO: Get from local database
    return [];
  }
  
  Future<void> _removeSyncQueueItem(String id) async {
    // TODO: Remove from local database
  }
  
  Future<void> _updateSyncQueueItem(SyncQueueItem item) async {
    // TODO: Update in local database
  }
  
  /// Clean up resources
  void dispose() {
    _periodicSyncTimer?.cancel();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    
    for (final controller in _syncControllers) {
      controller.close();
    }
    _syncControllers.clear();
  }
  
  /// Listen to sync events
  Stream<SyncResult> get syncEvents {
    final controller = StreamController<SyncResult>.broadcast();
    _syncControllers.add(controller);
    return controller.stream;
  }
}

/// Extension for handling async operations without awaiting
extension UnawaiteExtension on Future {
  void get unawaited {}
} 