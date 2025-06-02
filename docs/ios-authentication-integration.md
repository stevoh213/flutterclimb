# iOS Authentication Integration

## Overview

The iOS app (Flutter) now includes unified authentication with the same Supabase backend as the web application. This ensures consistent user experience and data synchronization across platforms.

## Architecture

### Key Components

1. **Supabase Configuration** (`lib/config/supabase_config.dart`)
   - Centralized Supabase client configuration
   - Shared credentials with web app
   - PKCE authentication flow for mobile security

2. **Authentication Models** (`lib/features/auth/models/auth_models.dart`)
   - Freezed data classes for type safety
   - AuthState, AuthCredentials, UserProfile models
   - Custom exception handling

3. **Authentication Service** (`lib/features/auth/services/auth_service.dart`)
   - Platform-specific implementation of unified auth interface
   - Automatic profile creation on signup
   - Stream-based state management

4. **Riverpod Providers** (`lib/providers/auth_provider.dart`)
   - Reactive state management
   - Authentication actions (signIn, signUp, signOut)
   - Convenience providers for UI

5. **UI Components**
   - `AuthScreen`: Main authentication interface
   - `AuthForm`: Reusable form with validation
   - Integrated with existing home screen

## Features

### Authentication Flow
- **Sign In**: Email/password authentication
- **Sign Up**: Account creation with email verification
- **Password Reset**: Email-based password recovery
- **Auto Profile Creation**: Automatic user profile setup
- **Session Management**: Persistent authentication state

### Security Features
- **PKCE Flow**: Secure authentication for mobile apps
- **Token Management**: Automatic refresh and storage
- **Row Level Security**: Database-level access control
- **Input Validation**: Client-side form validation

### User Experience
- **Splash Screen**: Loading state during initialization
- **Error Handling**: User-friendly error messages
- **Form Validation**: Real-time input validation
- **Responsive Design**: Works on all iOS device sizes

## Setup Instructions

### 1. Dependencies
The following packages have been added to `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.8.0
  shared_preferences: ^2.3.2
```

### 2. Configuration
Supabase credentials are configured in `lib/config/supabase_config.dart` using the same project as the web app.

### 3. Initialization
Supabase is initialized in `main.dart` before the app starts:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: ClimbingLogbookApp()));
}
```

### 4. Authentication Routing
The main app now routes based on authentication state:
- **Loading**: Shows splash screen
- **Authenticated**: Shows home screen
- **Unauthenticated**: Shows authentication screen

## Usage Examples

### Sign In
```dart
final authNotifier = ref.read(authNotifierProvider.notifier);
await authNotifier.signIn('user@example.com', 'password123');
```

### Sign Up
```dart
await authNotifier.signUp(
  'user@example.com', 
  'password123',
  fullName: 'John Doe',
);
```

### Check Authentication Status
```dart
final isAuthenticated = ref.watch(isAuthenticatedProvider);
if (isAuthenticated) {
  // User is signed in
}
```

### Sign Out
```dart
await authNotifier.signOut();
```

## Testing

### Manual Testing Steps
1. **Launch App**: Should show splash screen then auth screen
2. **Sign Up**: Create new account with valid email
3. **Email Verification**: Check email for verification link
4. **Sign In**: Use credentials to sign in
5. **Home Screen**: Should show authenticated home screen
6. **Sign Out**: Use menu to sign out, should return to auth screen
7. **Password Reset**: Test forgot password functionality

### Error Scenarios
- Invalid email format
- Weak password
- Network connectivity issues
- Existing account signup
- Wrong credentials

## Integration with Existing Features

### Session Management
- Sessions are now tied to authenticated users
- User ID is automatically included in session data
- RLS policies ensure users only see their own data

### Data Synchronization
- All climbing data syncs with Supabase backend
- Offline-first architecture with eventual consistency
- Automatic conflict resolution

### Profile Management
- User profiles created automatically on signup
- Climbing preferences stored in database
- Avatar and display name support

## Future Enhancements

### Planned Features
1. **Biometric Authentication**: Face ID / Touch ID support
2. **Social Login**: Google, Apple Sign In
3. **Multi-Factor Authentication**: SMS/TOTP support
4. **Account Linking**: Link multiple auth providers
5. **Profile Customization**: Enhanced user preferences

### Technical Improvements
1. **Offline Authentication**: Cached credentials for offline use
2. **Background Sync**: Automatic data synchronization
3. **Push Notifications**: Session reminders and updates
4. **Deep Linking**: Direct links to specific features

## Troubleshooting

### Common Issues

#### "Supabase not initialized" Error
- Ensure `SupabaseConfig.initialize()` is called in `main()`
- Check that credentials are correctly configured

#### Authentication State Not Updating
- Verify Riverpod providers are properly watched
- Check for proper error handling in auth service

#### Profile Creation Failures
- Verify database schema is deployed
- Check RLS policies are correctly configured
- Ensure user has proper permissions

#### Build Errors
- Run `flutter packages get` to install dependencies
- Run `flutter packages pub run build_runner build` for code generation
- Clear build cache if needed: `flutter clean`

### Debug Mode
Enable debug logging by adding print statements in the auth service or using Flutter's debugging tools.

## Conclusion

The iOS authentication integration provides a seamless, secure authentication experience that matches the web application. The unified backend ensures data consistency while the Flutter implementation provides native iOS performance and user experience.

The modular architecture allows for easy extension and maintenance, following the same design principles as the overall application architecture. 