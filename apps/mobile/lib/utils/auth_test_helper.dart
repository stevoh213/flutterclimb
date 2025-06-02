import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/ios_auth_config.dart';
import '../features/auth/services/auth_service.dart';

/// Helper class for testing and debugging auth functionality
class AuthTestHelper {
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  
  /// Test iOS signout functionality
  static Future<Map<String, dynamic>> testIOSSignOut(AuthService authService) async {
    final results = <String, dynamic>{
      'platform': isIOS ? 'iOS' : 'Other',
      'initial_auth_state': null,
      'signout_success': false,
      'final_auth_state': null,
      'error': null,
      'steps_completed': <String>[],
    };
    
    try {
      // Step 1: Check initial auth state
      results['steps_completed'].add('Check initial state');
      final client = Supabase.instance.client;
      results['initial_auth_state'] = {
        'has_user': client.auth.currentUser != null,
        'has_session': client.auth.currentSession != null,
        'user_id': client.auth.currentUser?.id,
      };
      
      // Step 2: iOS-specific validation if on iOS
      if (isIOS) {
        results['steps_completed'].add('iOS validation');
        final isValid = await IOSAuthConfig.validateIOSAuthState();
        results['ios_validation'] = isValid;
      }
      
      // Step 3: Perform signout
      results['steps_completed'].add('Attempt signout');
      await authService.signOut();
      results['signout_success'] = true;
      
      // Step 4: Wait for state propagation
      results['steps_completed'].add('Wait for state propagation');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 5: Check final auth state
      results['steps_completed'].add('Check final state');
      results['final_auth_state'] = {
        'has_user': client.auth.currentUser != null,
        'has_session': client.auth.currentSession != null,
        'user_id': client.auth.currentUser?.id,
      };
      
      // Step 6: iOS-specific cleanup verification
      if (isIOS) {
        results['steps_completed'].add('iOS cleanup verification');
        final isCleanedUp = await _verifyIOSCleanup();
        results['ios_cleanup_verified'] = isCleanedUp;
      }
      
      results['steps_completed'].add('Test completed successfully');
      
    } catch (e) {
      results['error'] = e.toString();
      results['signout_success'] = false;
    }
    
    return results;
  }
  
  /// Verify iOS-specific cleanup
  static Future<bool> _verifyIOSCleanup() async {
    if (!isIOS) return true;
    
    try {
      // This would check if iOS keychain data is properly cleared
      // For now, we'll just validate the auth state
      return await IOSAuthConfig.validateIOSAuthState();
    } catch (e) {
      debugPrint('Error verifying iOS cleanup: $e');
      return false;
    }
  }
  
  /// Debug auth state
  static Map<String, dynamic> debugAuthState() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final session = client.auth.currentSession;
    
    return {
      'platform': isIOS ? 'iOS' : 'Other',
      'timestamp': DateTime.now().toIso8601String(),
      'user': user != null ? {
        'id': user.id,
        'email': user.email,
        'created_at': user.createdAt,
        'last_sign_in_at': user.lastSignInAt,
      } : null,
      'session': session != null ? {
        'access_token_exists': session.accessToken.isNotEmpty,
        'refresh_token_exists': session.refreshToken?.isNotEmpty ?? false,
        'expires_at': session.expiresAt,
        'is_expired': session.expiresAt != null && 
            session.expiresAt! < (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      } : null,
    };
  }
  
  /// Print debug information
  static void printDebugInfo() {
    final info = debugAuthState();
    debugPrint('=== Auth Debug Info ===');
    debugPrint('Platform: ${info['platform']}');
    debugPrint('User: ${info['user']}');
    debugPrint('Session: ${info['session']}');
    debugPrint('======================');
  }
} 