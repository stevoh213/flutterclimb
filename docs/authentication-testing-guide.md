# Authentication Testing Guide

## Overview

This guide will help you test the unified authentication system across both web and iOS platforms to ensure everything is working correctly.

## Prerequisites

- **Web App**: Running on http://localhost:5174/ (or similar port)
- **iOS App**: Running in iOS Simulator or device
- **Supabase Backend**: Configured and accessible
- **Email Access**: To test email verification

## Test Scenarios

### 1. Cross-Platform Account Creation

**Objective**: Verify that accounts created on one platform work on the other.

#### Test Steps:
1. **Create Account on Web**:
   - Open web app at http://localhost:5174/
   - Click "Need an account? Sign up"
   - Fill in: Email, Password, Full Name
   - Click "Create Account"
   - Check email for verification link
   - Click verification link

2. **Sign In on iOS**:
   - Open iOS app in simulator
   - Should show authentication screen
   - Enter same email/password from web signup
   - Tap "Sign In"
   - Should successfully authenticate and show home screen

3. **Verify Data Sync**:
   - Both platforms should show the same user profile
   - Any sessions created on one platform should appear on the other

### 2. Password Reset Flow

**Objective**: Test password reset functionality.

#### Test Steps:
1. **Initiate Reset on iOS**:
   - On iOS auth screen, tap "Forgot Password?"
   - Enter your email address
   - Tap "Send Reset Email"
   - Check email for reset link

2. **Complete Reset on Web**:
   - Click the reset link in email
   - Should open web browser with reset form
   - Enter new password
   - Submit form

3. **Test New Password**:
   - Try signing in on iOS with old password (should fail)
   - Try signing in on iOS with new password (should work)
   - Try signing in on web with new password (should work)

### 3. Session Management

**Objective**: Verify session persistence and sign-out behavior.

#### Test Steps:
1. **Sign In on Both Platforms**:
   - Sign in on web app
   - Sign in on iOS app
   - Both should show authenticated state

2. **Test Session Persistence**:
   - Close and reopen web browser
   - Should remain signed in
   - Force-quit and reopen iOS app
   - Should remain signed in

3. **Test Sign Out**:
   - Sign out on web app
   - Refresh web app - should show auth screen
   - Check iOS app - should still be signed in (sessions are independent)
   - Sign out on iOS app
   - Both platforms should now show auth screens

### 4. Error Handling

**Objective**: Test various error scenarios.

#### Test Steps:
1. **Invalid Credentials**:
   - Try signing in with wrong password
   - Should show appropriate error message
   - Error should be user-friendly

2. **Network Issues**:
   - Disconnect internet
   - Try to sign in
   - Should show network error
   - Reconnect and retry - should work

3. **Validation Errors**:
   - Try invalid email format
   - Try password less than 6 characters
   - Try mismatched passwords on signup
   - Should show validation errors

### 5. Profile Management

**Objective**: Test user profile creation and updates.

#### Test Steps:
1. **Profile Creation**:
   - Create new account
   - Check Supabase dashboard - profile should be created automatically
   - Profile should have correct email and full name

2. **Profile Data Consistency**:
   - Sign in on both platforms
   - User information should be consistent
   - Any profile updates should sync across platforms

## Expected Results

### ✅ Success Criteria

- [ ] Account created on one platform works on the other
- [ ] Password reset works across platforms
- [ ] Sessions persist correctly
- [ ] Sign out works properly
- [ ] Error messages are clear and helpful
- [ ] Profile data syncs between platforms
- [ ] Email verification works
- [ ] Form validation prevents invalid input

### ❌ Common Issues and Solutions

#### "Supabase not initialized" Error
- **Cause**: Supabase configuration issue
- **Solution**: Check environment variables and initialization code

#### Authentication state not updating
- **Cause**: Provider state management issue
- **Solution**: Check Riverpod provider implementation

#### Email verification not working
- **Cause**: Email configuration in Supabase
- **Solution**: Check Supabase email settings and templates

#### Cross-platform data not syncing
- **Cause**: Different user IDs or RLS policy issues
- **Solution**: Verify database policies and user creation

## Database Verification

### Supabase Dashboard Checks

1. **Authentication Tab**:
   - Users should appear after signup
   - Email verification status should be correct
   - Sessions should be active for signed-in users

2. **Table Editor**:
   - `profiles` table should have user records
   - User IDs should match between auth and profiles
   - Profile data should be complete

3. **Logs Tab**:
   - Check for any error messages
   - Verify API calls are successful
   - Monitor authentication events

## Performance Testing

### Load Testing
1. **Multiple Sign-ins**: Test rapid sign-in/sign-out cycles
2. **Concurrent Sessions**: Test multiple devices with same account
3. **Network Conditions**: Test on slow/unstable connections

### Memory Testing
1. **iOS Memory**: Monitor memory usage during auth operations
2. **Web Memory**: Check for memory leaks in browser
3. **Background Behavior**: Test app backgrounding/foregrounding

## Security Testing

### Basic Security Checks
1. **Token Storage**: Verify tokens are stored securely
2. **Session Timeout**: Test automatic session expiration
3. **HTTPS**: Ensure all auth requests use HTTPS
4. **Input Sanitization**: Test SQL injection attempts

## Automated Testing

### Unit Tests
```bash
# Run Flutter unit tests
cd apps/mobile
flutter test

# Run web unit tests
cd apps/web
npm test
```

### Integration Tests
```bash
# Run Flutter integration tests
cd apps/mobile
flutter test integration_test/

# Run web e2e tests
cd apps/web
npm run test:e2e
```

## Troubleshooting

### Debug Mode
Enable debug logging to see detailed authentication flow:

**iOS (Flutter)**:
```dart
// Add to auth service
print('Auth state changed: ${state.user?.email}');
```

**Web (React)**:
```javascript
// Add to auth hook
console.log('Auth state:', { user, session, loading, error });
```

### Common Debug Commands
```bash
# Clear Flutter cache
flutter clean && flutter pub get

# Clear web cache
rm -rf node_modules && npm install

# Reset Supabase local state
# Clear browser storage and app data
```

## Conclusion

This testing guide ensures that the unified authentication system works correctly across all platforms and scenarios. Regular testing of these scenarios will help maintain system reliability and user experience quality.

Remember to test on both development and production environments, and consider setting up automated tests for critical authentication flows. 