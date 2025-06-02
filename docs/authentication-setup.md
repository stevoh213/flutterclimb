# Unified Authentication System with Supabase

## Overview

This document outlines the unified authentication system built with Supabase that provides consistent authentication across web and mobile platforms. The system follows the modular architecture principles outlined in the design documents, ensuring clean, maintainable, and AI-friendly code.

## Architecture

### Core Components

1. **Shared Authentication Service** (`packages/core/lib/auth/`)
   - Platform-agnostic authentication interfaces
   - Validation utilities
   - Type definitions
   - Error handling

2. **Web Implementation** (`apps/web/src/`)
   - React hooks for authentication state
   - UI components for login/signup
   - Protected route components

3. **Database Schema** (`packages/db/supabase/`)
   - User profiles and preferences
   - Row Level Security (RLS) policies
   - Database triggers and functions

## Setup Instructions

### 1. Supabase Project Setup

1. **Create a new Supabase project**:
   - Go to [supabase.com](https://supabase.com)
   - Create a new project
   - Note your project URL and anon key

2. **Run the database schema**:
   ```sql
   -- Copy and paste the contents of packages/db/supabase/schema.sql
   -- into the Supabase SQL editor and execute
   ```

3. **Configure authentication providers** (optional):
   - Go to Authentication > Settings in Supabase dashboard
   - Enable desired providers (Google, GitHub, etc.)

### 2. Environment Configuration

1. **Web App** (`apps/web/`):
   ```bash
   # Copy the example environment file
   cp env.example .env.local
   
   # Edit .env.local with your Supabase credentials
   VITE_SUPABASE_URL=https://your-project.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-key
   ```

2. **Mobile App** (Future):
   ```dart
   // lib/config/supabase_config.dart
   const supabaseUrl = 'https://your-project.supabase.co';
   const supabaseAnonKey = 'your-anon-key';
   ```

### 3. Running the Web Application

```bash
# Navigate to web app directory
cd apps/web

# Install dependencies (if not already done)
npm install

# Start development server
npm run dev
```

## Usage Guide

### Web Application

#### Basic Authentication Flow

```typescript
import { useAuth } from './hooks/useAuth'

function MyComponent() {
  const { user, signIn, signUp, signOut, loading, error } = useAuth()

  const handleSignIn = async () => {
    try {
      await signIn('user@example.com', 'password123')
    } catch (error) {
      console.error('Sign in failed:', error)
    }
  }

  if (loading) return <div>Loading...</div>
  if (user) return <div>Welcome, {user.email}!</div>
  
  return <button onClick={handleSignIn}>Sign In</button>
}
```

#### Protected Routes

```typescript
import { ProtectedRoute } from './components/auth/ProtectedRoute'

function App() {
  return (
    <ProtectedRoute>
      <Dashboard />
    </ProtectedRoute>
  )
}
```

#### Custom Authentication Form

```typescript
import { AuthForm } from './components/auth/AuthForm'

function LoginPage() {
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  
  return (
    <AuthForm 
      mode={mode} 
      onModeChange={setMode}
    />
  )
}
```

### Shared Core Services

#### Using Validation Utilities

```typescript
import { validateEmail, validatePassword, validateAuthCredentials } from '@climbing-logbook/core/auth'

// Validate individual fields
const isValidEmail = validateEmail('user@example.com')
const passwordCheck = validatePassword('mypassword123')

// Validate complete credentials
const credentialsCheck = validateAuthCredentials({
  email: 'user@example.com',
  password: 'mypassword123',
  fullName: 'John Doe'
})

if (!credentialsCheck.valid) {
  console.error('Validation errors:', credentialsCheck.errors)
}
```

## Database Schema

### Core Tables

#### Profiles
Extends Supabase's built-in `auth.users` table with climbing-specific data:

```sql
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    climbing_style_preference climbing_style DEFAULT 'lead',
    preferred_grade_system grade_system DEFAULT 'YDS',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### User Preferences
Stores app-specific user preferences:

```sql
CREATE TABLE user_preferences (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) UNIQUE,
    default_location TEXT,
    auto_start_session BOOLEAN DEFAULT false,
    voice_logging_enabled BOOLEAN DEFAULT true,
    -- ... other preferences
);
```

### Security

#### Row Level Security (RLS)
All tables have RLS enabled with policies ensuring users can only access their own data:

```sql
-- Example policy
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);
```

#### Data Validation
Database constraints ensure data integrity:

```sql
-- Quality ratings must be 1-5
quality_rating INTEGER CHECK (quality_rating >= 1 AND quality_rating <= 5)

-- Progress percentage must be 0-100
progress_percentage INTEGER CHECK (progress_percentage >= 0 AND progress_percentage <= 100)
```

## Error Handling

### Custom Error Types

```typescript
import { AuthServiceError } from '@climbing-logbook/core/auth'

try {
  await authService.signIn(credentials)
} catch (error) {
  if (error instanceof AuthServiceError) {
    // Handle specific auth errors
    console.error(`Auth error [${error.code}]:`, error.message)
  } else {
    // Handle unexpected errors
    console.error('Unexpected error:', error)
  }
}
```

### Common Error Codes

- `INVALID_CREDENTIALS`: Wrong email/password
- `USER_NOT_FOUND`: Account doesn't exist
- `EMAIL_NOT_CONFIRMED`: Email verification required
- `WEAK_PASSWORD`: Password doesn't meet requirements
- `RATE_LIMIT_EXCEEDED`: Too many attempts

## Testing

### Unit Tests

```typescript
import { validateEmail, validatePassword } from '@climbing-logbook/core/auth'

describe('Auth Validation', () => {
  test('validates email correctly', () => {
    expect(validateEmail('user@example.com')).toBe(true)
    expect(validateEmail('invalid-email')).toBe(false)
  })

  test('validates password strength', () => {
    const result = validatePassword('weak')
    expect(result.valid).toBe(false)
    expect(result.errors).toContain('Password must be at least 6 characters long')
  })
})
```

### Integration Tests

```typescript
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { AuthForm } from './AuthForm'

test('sign in form submission', async () => {
  render(<AuthForm mode="signin" onModeChange={() => {}} />)
  
  fireEvent.change(screen.getByLabelText(/email/i), {
    target: { value: 'test@example.com' }
  })
  fireEvent.change(screen.getByLabelText(/password/i), {
    target: { value: 'password123' }
  })
  
  fireEvent.click(screen.getByRole('button', { name: /sign in/i }))
  
  await waitFor(() => {
    expect(screen.queryByText(/loading/i)).not.toBeInTheDocument()
  })
})
```

## Security Best Practices

### 1. Environment Variables
- Never commit `.env` files to version control
- Use different keys for development and production
- Rotate keys regularly

### 2. Password Requirements
- Minimum 6 characters (configurable)
- Must contain letters and numbers
- Consider implementing additional complexity rules

### 3. Session Management
- Automatic token refresh
- Secure session storage
- Proper cleanup on sign out

### 4. Rate Limiting
- Implement client-side rate limiting
- Use Supabase's built-in rate limiting
- Monitor for suspicious activity

## Deployment Considerations

### Environment-Specific Configuration

#### Development
```bash
VITE_SUPABASE_URL=https://dev-project.supabase.co
VITE_SUPABASE_ANON_KEY=dev-anon-key
```

#### Production
```bash
VITE_SUPABASE_URL=https://prod-project.supabase.co
VITE_SUPABASE_ANON_KEY=prod-anon-key
```

### Database Migrations
- Use Supabase migrations for schema changes
- Test migrations in staging environment
- Backup database before production migrations

## Monitoring and Analytics

### Authentication Metrics
- Sign-up conversion rates
- Sign-in success rates
- Password reset frequency
- Session duration

### Error Tracking
- Authentication failures
- Network connectivity issues
- Token refresh failures

## Future Enhancements

### Planned Features
1. **Social Authentication**
   - Google OAuth
   - Apple Sign In
   - GitHub OAuth

2. **Multi-Factor Authentication**
   - SMS verification
   - TOTP (Time-based One-Time Password)
   - Email verification

3. **Advanced Security**
   - Device fingerprinting
   - Suspicious activity detection
   - Account lockout policies

4. **Mobile Integration**
   - Biometric authentication
   - Secure keychain storage
   - Background session refresh

## Troubleshooting

### Common Issues

#### "Missing Supabase environment variables"
- Ensure `.env.local` file exists in web app directory
- Verify environment variable names match exactly
- Restart development server after adding variables

#### "User not found" errors
- Check if user has confirmed their email
- Verify user exists in Supabase auth dashboard
- Ensure RLS policies are correctly configured

#### Profile creation failures
- Check database triggers are properly set up
- Verify profiles table permissions
- Review Supabase logs for detailed errors

### Debug Mode
Enable debug logging by setting:
```bash
VITE_DEBUG_AUTH=true
```

This will log authentication events to the browser console for troubleshooting.

## Support

For issues related to:
- **Supabase**: Check [Supabase documentation](https://supabase.com/docs)
- **React hooks**: Review React documentation and common patterns
- **Database schema**: Refer to PostgreSQL documentation
- **Authentication flows**: Consult OAuth 2.0 and JWT specifications

## Conclusion

This unified authentication system provides a solid foundation for the climbing logbook application, ensuring secure, scalable, and maintainable user authentication across all platforms. The modular design allows for easy extension and modification while maintaining consistency with the overall application architecture. 