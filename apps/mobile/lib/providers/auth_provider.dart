import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';
import '../features/auth/models/auth_models.dart';
import '../features/auth/services/auth_service.dart';

part 'auth_provider.g.dart';

// Auth service provider
@riverpod
AuthService authService(AuthServiceRef ref) {
  final service = AuthService();
  ref.onDispose(() => service.dispose());
  return service;
}

// Auth state provider
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AppAuthState build() {
    final service = ref.watch(authServiceProvider);
    
    // Listen to auth state changes from the service
    service.stateStream.listen((authState) {
      // Update state when auth service state changes
      state = authState;
    });
    
    return service.currentState;
  }
  
  Future<void> signIn(String email, String password) async {
    try {
      final service = ref.read(authServiceProvider);
      final credentials = AuthCredentials(email: email, password: password);
      await service.signIn(credentials);
      state = service.currentState;
    } catch (e) {
      debugPrint('SignIn error in provider: $e');
      rethrow;
    }
  }
  
  Future<void> signUp(String email, String password, {String? fullName}) async {
    try {
      final service = ref.read(authServiceProvider);
      final credentials = AuthCredentials(
        email: email, 
        password: password, 
        fullName: fullName,
      );
      await service.signUp(credentials);
      state = service.currentState;
    } catch (e) {
      debugPrint('SignUp error in provider: $e');
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    try {
      final service = ref.read(authServiceProvider);
      
      // Add timeout for iOS signout issues (increased to 15 seconds for iOS)
      await Future.any([
        service.signOut(),
        Future.delayed(const Duration(seconds: 15), () {
          throw Exception('SignOut timeout - forcing local state clear');
        }),
      ]);
      
      // Wait a moment for service state to propagate
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Sync with service state
      state = service.currentState;
      
      debugPrint('Provider signOut completed successfully');
      
    } catch (e) {
      debugPrint('SignOut error in provider: $e');
      
      // Even if signout fails, clear local state to prevent stuck auth state
      state = const AppAuthState(
        user: null,
        session: null,
        loading: false,
        error: null,
      );
      
      debugPrint('Provider state forcibly cleared due to error');
    }
  }
  
  Future<void> resetPassword(String email) async {
    try {
      final service = ref.read(authServiceProvider);
      await service.resetPassword(email);
      state = service.currentState;
    } catch (e) {
      debugPrint('ResetPassword error in provider: $e');
      rethrow;
    }
  }
  
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
  
  /// Force refresh auth state - useful for iOS issues
  void refreshAuthState() {
    final service = ref.read(authServiceProvider);
    state = service.currentState;
  }
}

// User profile provider
@riverpod
Future<UserProfile?> userProfile(UserProfileRef ref) async {
  final authState = ref.watch(authNotifierProvider);
  final service = ref.watch(authServiceProvider);
  
  if (authState.user == null) return null;
  
  try {
    return await service.getProfile(authState.user!.id);
  } catch (e) {
    debugPrint('Error loading user profile: $e');
    return null;
  }
}

// Convenience providers
@riverpod
bool isAuthenticated(IsAuthenticatedRef ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.user != null && authState.session != null;
}

@riverpod
bool isLoading(IsLoadingRef ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.loading;
} 