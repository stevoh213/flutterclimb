import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../../../config/ios_auth_config.dart';
import '../models/auth_models.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;
  final StreamController<AppAuthState> _stateController = StreamController<AppAuthState>.broadcast();
  
  AppAuthState _currentState = const AppAuthState();
  bool _isSigningOut = false;
  
  AuthService() {
    _initialize();
  }
  
  void _initialize() async {
    // Initialize iOS-specific auth if needed
    await IOSAuthConfig.initializeIOSAuth();
    
    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      debugPrint('Auth state change: ${event.name}, has_session: ${session != null}, signing_out: $_isSigningOut');
      
      // Don't update state if we're in the middle of signing out
      // Let the signout method handle state updates
      if (_isSigningOut) {
        debugPrint('Ignoring auth state change during signout process');
        return;
      }
      
      _updateState(
        user: session?.user,
        session: session,
        loading: false,
        error: null,
      );
      
      // Create profile on sign up
      if (event == AuthChangeEvent.signedIn && session?.user != null) {
        _createUserProfileIfNeeded(session!.user);
      }
    });
    
    // Set initial state
    final session = _client.auth.currentSession;
    _updateState(
      user: session?.user,
      session: session,
      loading: false,
      error: null,
    );
  }
  
  // State management
  AppAuthState get currentState => _currentState;
  Stream<AppAuthState> get stateStream => _stateController.stream;
  
  void _updateState({
    User? user,
    Session? session,
    bool? loading,
    String? error,
  }) {
    _currentState = _currentState.copyWith(
      user: user ?? _currentState.user,
      session: session ?? _currentState.session,
      loading: loading ?? _currentState.loading,
      error: error,
    );
    _stateController.add(_currentState);
  }
  
  // Authentication methods
  Future<void> signIn(AuthCredentials credentials) async {
    try {
      _updateState(loading: true, error: null);
      
      final response = await _client.auth.signInWithPassword(
        email: credentials.email,
        password: credentials.password,
      );
      
      if (response.user == null) {
        throw const AppAuthException('Sign in failed');
      }
      
      _updateState(
        user: response.user,
        session: response.session,
        loading: false,
      );
    } on AppAuthException {
      _updateState(loading: false);
      rethrow;
    } catch (e) {
      final error = 'Sign in failed: ${e.toString()}';
      _updateState(loading: false, error: error);
      throw AppAuthException(error);
    }
  }
  
  Future<void> signUp(AuthCredentials credentials) async {
    try {
      _updateState(loading: true, error: null);
      
      final response = await _client.auth.signUp(
        email: credentials.email,
        password: credentials.password,
        data: credentials.fullName != null 
          ? {'full_name': credentials.fullName}
          : null,
      );
      
      if (response.user == null) {
        throw const AppAuthException('Sign up failed');
      }
      
      _updateState(
        user: response.user,
        session: response.session,
        loading: false,
      );
    } on AppAuthException {
      _updateState(loading: false);
      rethrow;
    } catch (e) {
      final error = 'Sign up failed: ${e.toString()}';
      _updateState(loading: false, error: error);
      throw AppAuthException(error);
    }
  }
  
  Future<void> signOut() async {
    if (_isSigningOut) {
      return; // Prevent multiple simultaneous signout attempts
    }
    
    try {
      _isSigningOut = true;
      _updateState(loading: true, error: null);
      
      // Step 1: Clear local state immediately to prevent UI confusion
      _updateState(
        user: null,
        session: null,
        loading: true,
        error: null,
      );
      
      // Step 2: iOS-specific credential clearing (this also does signout)
      if (!kIsWeb && Platform.isIOS) {
        await _clearIOSCredentials();
      } else {
        // For non-iOS platforms, do standard signout
        await _client.auth.signOut(scope: SignOutScope.global);
      }
      
      // Step 3: Wait longer for state propagation on iOS
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Step 4: Verify signout was successful
      final currentUser = _client.auth.currentUser;
      final currentSession = _client.auth.currentSession;
      
      if (currentUser != null || currentSession != null) {
        debugPrint('SignOut verification failed - forcing additional cleanup');
        
        // Force additional cleanup
        await _forceCompleteSignout();
      }
      
      // Step 5: Final state update
      _updateState(
        user: null,
        session: null,
        loading: false,
        error: null,
      );
      
      debugPrint('SignOut completed successfully');
      
    } catch (e) {
      final error = 'Sign out failed: ${e.toString()}';
      
      // Handle iOS-specific auth errors
      await IOSAuthConfig.handleIOSAuthError(e);
      
      // Force complete signout even on error
      await _forceCompleteSignout();
      
      _updateState(
        user: null, // Clear user even if signout failed
        session: null, // Clear session even if signout failed
        loading: false, 
        error: null, // Don't show error to user since we cleared state
      );
      
      debugPrint('SignOut error handled: $error');
    } finally {
      _isSigningOut = false;
    }
  }
  
  /// Force complete signout with aggressive cleanup
  Future<void> _forceCompleteSignout() async {
    try {
      debugPrint('Force complete signout initiated');
      
      // Multiple signout attempts with different scopes
      final signoutFutures = [
        _client.auth.signOut(scope: SignOutScope.global).catchError((_) => null),
        _client.auth.signOut(scope: SignOutScope.local).catchError((_) => null),
        _client.auth.signOut().catchError((_) => null),
      ];
      
      await Future.wait(signoutFutures);
      
      // iOS-specific additional cleanup
      if (!kIsWeb && Platform.isIOS) {
        await IOSAuthConfig.clearIOSAuthData();
        await IOSAuthConfig.forceSupabaseSignOut();
      }
      
      debugPrint('Force complete signout finished');
      
    } catch (e) {
      debugPrint('Error in force complete signout: $e');
    }
  }
  
  /// iOS-specific credential clearing
  Future<void> _clearIOSCredentials() async {
    try {
      // Use the iOS-specific auth config to clear credentials
      await IOSAuthConfig.clearIOSAuthData();
      await IOSAuthConfig.forceSupabaseSignOut();
      debugPrint('iOS credentials cleared using IOSAuthConfig');
    } catch (e) {
      debugPrint('Error clearing iOS credentials: $e');
    }
  }
  
  Future<void> resetPassword(String email) async {
    try {
      _updateState(loading: true, error: null);
      
      await _client.auth.resetPasswordForEmail(email);
      
      _updateState(loading: false);
    } catch (e) {
      final error = 'Password reset failed: ${e.toString()}';
      _updateState(loading: false, error: error);
      throw AppAuthException(error);
    }
  }
  
  // Session management
  Future<Session?> getSession() async {
    return _client.auth.currentSession;
  }
  
  Future<Session?> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return response.session;
    } catch (e) {
      throw AppAuthException('Session refresh failed: ${e.toString()}');
    }
  }
  
  // Profile management
  Future<void> _createUserProfileIfNeeded(User user) async {
    try {
      // Check if profile already exists
      final existingProfile = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      
      if (existingProfile == null) {
        // Create new profile
        await _client.from('profiles').insert({
          'id': user.id,
          'email': user.email!,
          'full_name': user.userMetadata?['full_name'],
          'avatar_url': user.userMetadata?['avatar_url'],
          'preferred_grade_system': 'YDS',
        });
      }
    } catch (e) {
      // Log error but don't throw - profile creation shouldn't block auth
      debugPrint('Error creating user profile: $e');
    }
  }
  
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return UserProfile(
        id: response['id'],
        email: response['email'],
        fullName: response['full_name'],
        avatarUrl: response['avatar_url'],
        climbingStylePreference: response['climbing_style_preference'],
        preferredGradeSystem: response['preferred_grade_system'],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
      );
    } catch (e) {
      throw AppAuthException('Failed to get profile: ${e.toString()}');
    }
  }
  
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    } catch (e) {
      throw AppAuthException('Failed to update profile: ${e.toString()}');
    }
  }
  
  void dispose() {
    _stateController.close();
  }
} 