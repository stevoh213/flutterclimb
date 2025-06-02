import type { User, Session, AuthError } from '@supabase/supabase-js'

export interface AuthState {
  user: User | null
  session: Session | null
  loading: boolean
  error: AuthError | null
}

export interface AuthCredentials {
  email: string
  password: string
  fullName?: string
}

export interface AuthService {
  // State management
  getState(): AuthState
  onStateChange(callback: (state: AuthState) => void): () => void
  
  // Authentication methods
  signIn(credentials: AuthCredentials): Promise<void>
  signUp(credentials: AuthCredentials): Promise<void>
  signOut(): Promise<void>
  resetPassword(email: string): Promise<void>
  
  // Session management
  getSession(): Promise<Session | null>
  refreshSession(): Promise<Session | null>
  
  // Profile management
  createProfile(user: User): Promise<void>
  updateProfile(updates: Partial<UserProfile>): Promise<void>
  getProfile(userId: string): Promise<UserProfile | null>
}

export interface UserProfile {
  id: string
  email: string
  full_name: string | null
  avatar_url: string | null
  climbing_style_preference: ClimbingStyle | null
  preferred_grade_system: GradeSystem | null
  created_at: string
  updated_at: string
}

export type ClimbingStyle = 'lead' | 'toprope' | 'boulder' | 'aid' | 'solo'
export type GradeSystem = 'YDS' | 'French' | 'V-Scale' | 'UIAA'

export class AuthServiceError extends Error {
  constructor(
    message: string,
    public code: string,
    public originalError?: Error
  ) {
    super(message)
    this.name = 'AuthServiceError'
  }
}

// Validation utilities
export const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  return emailRegex.test(email)
}

export const validatePassword = (password: string): { valid: boolean; errors: string[] } => {
  const errors: string[] = []
  
  if (password.length < 6) {
    errors.push('Password must be at least 6 characters long')
  }
  
  if (!/[A-Za-z]/.test(password)) {
    errors.push('Password must contain at least one letter')
  }
  
  if (!/\d/.test(password)) {
    errors.push('Password must contain at least one number')
  }
  
  return {
    valid: errors.length === 0,
    errors
  }
}

export const validateAuthCredentials = (credentials: AuthCredentials): { valid: boolean; errors: string[] } => {
  const errors: string[] = []
  
  if (!validateEmail(credentials.email)) {
    errors.push('Please enter a valid email address')
  }
  
  const passwordValidation = validatePassword(credentials.password)
  if (!passwordValidation.valid) {
    errors.push(...passwordValidation.errors)
  }
  
  if (credentials.fullName !== undefined && credentials.fullName.trim().length === 0) {
    errors.push('Full name cannot be empty')
  }
  
  return {
    valid: errors.length === 0,
    errors
  }
}

// Auth event types for cross-platform consistency
export type AuthEvent = 
  | 'SIGNED_IN'
  | 'SIGNED_OUT' 
  | 'SIGNED_UP'
  | 'PASSWORD_RECOVERY'
  | 'TOKEN_REFRESHED'
  | 'USER_UPDATED'

export interface AuthEventData {
  event: AuthEvent
  session: Session | null
  user: User | null
  error?: AuthError
}

// Storage interface for platform-specific implementations
export interface AuthStorage {
  getItem(key: string): Promise<string | null>
  setItem(key: string, value: string): Promise<void>
  removeItem(key: string): Promise<void>
}

// Default storage keys
export const AUTH_STORAGE_KEYS = {
  SESSION: 'supabase.auth.token',
  USER: 'supabase.auth.user',
  REFRESH_TOKEN: 'supabase.auth.refresh_token'
} as const 