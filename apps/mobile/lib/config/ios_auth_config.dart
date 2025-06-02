import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// iOS-specific authentication configuration and utilities
class IOSAuthConfig {
  static const String _keychainPrefix = 'climbing_logbook';
  static const String _sessionKey = '${_keychainPrefix}_session';
  static const String _userKey = '${_keychainPrefix}_user';
  static const String _tokenKey = '${_keychainPrefix}_token';
  
  /// Check if running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  
  /// Configure iOS-specific Supabase settings
  static Future<void> configureSupabaseForIOS() async {
    if (!isIOS) return;
    
    try {
      // iOS-specific configuration for Supabase
      // This ensures proper keychain integration
      debugPrint('Configuring Supabase for iOS');
      
      // Additional iOS-specific settings can be added here
      // For example, configuring keychain access groups, etc.
      
    } catch (e) {
      debugPrint('Error configuring Supabase for iOS: $e');
    }
  }
  
  /// Clear iOS keychain and stored authentication data
  static Future<void> clearIOSAuthData() async {
    if (!isIOS) return;
    
    try {
      debugPrint('Clearing iOS authentication data');
      
      // Clear SharedPreferences auth data
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_sessionKey),
        prefs.remove(_userKey),
        prefs.remove(_tokenKey),
        prefs.remove('supabase.session'),
        prefs.remove('supabase.auth.token'),
        prefs.remove('supabase.auth.refreshToken'),
      ]);
      
      // Clear all keys that start with our prefix
      final keys = prefs.getKeys().where((key) => key.startsWith(_keychainPrefix));
      await Future.wait(keys.map((key) => prefs.remove(key)));
      
      // Clear Supabase-specific keys
      final supabaseKeys = prefs.getKeys().where((key) => 
          key.startsWith('supabase') || 
          key.contains('auth') ||
          key.contains('session') ||
          key.contains('token')
      );
      await Future.wait(supabaseKeys.map((key) => prefs.remove(key)));
      
      debugPrint('iOS authentication data cleared successfully');
      
    } catch (e) {
      debugPrint('Error clearing iOS authentication data: $e');
    }
  }
  
  /// Force clear Supabase session on iOS
  static Future<void> forceSupabaseSignOut() async {
    if (!isIOS) return;
    
    try {
      debugPrint('Force signing out from Supabase on iOS');
      
      final client = Supabase.instance.client;
      
      // Try multiple signout methods for iOS reliability
      await Future.wait([
        client.auth.signOut(scope: SignOutScope.global),
        client.auth.signOut(scope: SignOutScope.local),
        client.auth.signOut(), // Default scope
      ].map((future) => future.catchError((e) {
        debugPrint('Signout method failed: $e');
        return null;
      })));
      
      // Additional wait for state propagation
      await Future.delayed(const Duration(milliseconds: 200));
      
      debugPrint('Force signout completed');
      
    } catch (e) {
      debugPrint('Error during force signout: $e');
    }
  }
  
  /// Check and fix iOS auth state inconsistencies
  static Future<bool> validateIOSAuthState() async {
    if (!isIOS) return true;
    
    try {
      debugPrint('Validating iOS auth state');
      
      final client = Supabase.instance.client;
      final currentSession = client.auth.currentSession;
      final currentUser = client.auth.currentUser;
      
      // Check for inconsistent state
      if ((currentSession == null) != (currentUser == null)) {
        debugPrint('Detected inconsistent auth state on iOS');
        await clearIOSAuthData();
        await forceSupabaseSignOut();
        return false;
      }
      
      // Check if session is expired
      if (currentSession != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (currentSession.expiresAt != null && currentSession.expiresAt! < now) {
          debugPrint('Detected expired session on iOS');
          await clearIOSAuthData();
          await forceSupabaseSignOut();
          return false;
        }
      }
      
      debugPrint('iOS auth state is valid');
      return true;
      
    } catch (e) {
      debugPrint('Error validating iOS auth state: $e');
      return false;
    }
  }
  
  /// iOS-specific session refresh
  static Future<bool> refreshIOSSession() async {
    if (!isIOS) return true;
    
    try {
      debugPrint('Refreshing session on iOS');
      
      final client = Supabase.instance.client;
      final response = await client.auth.refreshSession();
      
      if (response.session != null) {
        debugPrint('iOS session refresh successful');
        return true;
      } else {
        debugPrint('iOS session refresh failed - clearing data');
        await clearIOSAuthData();
        return false;
      }
      
    } catch (e) {
      debugPrint('Error refreshing iOS session: $e');
      await clearIOSAuthData();
      return false;
    }
  }
  
  /// Handle iOS-specific auth errors
  static Future<void> handleIOSAuthError(dynamic error) async {
    if (!isIOS) return;
    
    try {
      final errorString = error.toString().toLowerCase();
      
      // Check for iOS-specific auth errors that require data clearing
      if (errorString.contains('keychain') ||
          errorString.contains('session') ||
          errorString.contains('token') ||
          errorString.contains('invalid') ||
          errorString.contains('expired')) {
        
        debugPrint('Detected iOS auth error requiring data clear: $error');
        await clearIOSAuthData();
        await forceSupabaseSignOut();
      }
      
    } catch (e) {
      debugPrint('Error handling iOS auth error: $e');
    }
  }
  
  /// Initialize iOS authentication system
  static Future<void> initializeIOSAuth() async {
    if (!isIOS) return;
    
    try {
      debugPrint('Initializing iOS authentication system');
      
      // Configure Supabase for iOS
      await configureSupabaseForIOS();
      
      // Validate current auth state
      final isValid = await validateIOSAuthState();
      
      if (!isValid) {
        debugPrint('iOS auth state was invalid and has been reset');
      }
      
      debugPrint('iOS authentication system initialized');
      
    } catch (e) {
      debugPrint('Error initializing iOS auth: $e');
      await clearIOSAuthData();
    }
  }
} 