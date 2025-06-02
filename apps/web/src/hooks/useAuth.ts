import { useState, useEffect } from 'react'
import type { User, Session, AuthError } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

export interface AuthState {
  user: User | null
  session: Session | null
  loading: boolean
  error: AuthError | null
}

export interface AuthActions {
  signIn: (email: string, password: string) => Promise<void>
  signUp: (email: string, password: string, fullName?: string) => Promise<void>
  signOut: () => Promise<void>
  resetPassword: (email: string) => Promise<void>
  clearError: () => void
}

export function useAuth(): AuthState & AuthActions {
  const [state, setState] = useState<AuthState>({
    user: null,
    session: null,
    loading: true,
    error: null
  })

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session }, error }) => {
      setState(prev => ({
        ...prev,
        session,
        user: session?.user ?? null,
        loading: false,
        error: error as AuthError | null
      }))
    })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        setState(prev => ({
          ...prev,
          session,
          user: session?.user ?? null,
          loading: false,
          error: null
        }))

        // Create profile on sign up
        if (event === 'SIGNED_IN' && session?.user) {
          // Check if this is a new user by trying to fetch their profile
          const { data: existingProfile } = await supabase
            .from('profiles')
            .select('id')
            .eq('id', session.user.id)
            .single()
          
          if (!existingProfile) {
            await createUserProfile(session.user)
          }
        }
      }
    )

    return () => subscription.unsubscribe()
  }, [])

  const signIn = async (email: string, password: string): Promise<void> => {
    setState(prev => ({ ...prev, loading: true, error: null }))
    
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password
    })

    if (error) {
      setState(prev => ({ ...prev, loading: false, error }))
      throw error
    }

    setState(prev => ({ ...prev, loading: false }))
  }

  const signUp = async (email: string, password: string, fullName?: string): Promise<void> => {
    setState(prev => ({ ...prev, loading: true, error: null }))
    
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName
        }
      }
    })

    if (error) {
      setState(prev => ({ ...prev, loading: false, error }))
      throw error
    }

    setState(prev => ({ ...prev, loading: false }))
  }

  const signOut = async (): Promise<void> => {
    setState(prev => ({ ...prev, loading: true, error: null }))
    
    const { error } = await supabase.auth.signOut()

    if (error) {
      setState(prev => ({ ...prev, loading: false, error }))
      throw error
    }

    setState(prev => ({ ...prev, loading: false }))
  }

  const resetPassword = async (email: string): Promise<void> => {
    setState(prev => ({ ...prev, loading: true, error: null }))
    
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`
    })

    if (error) {
      setState(prev => ({ ...prev, loading: false, error }))
      throw error
    }

    setState(prev => ({ ...prev, loading: false }))
  }

  const clearError = (): void => {
    setState(prev => ({ ...prev, error: null }))
  }

  return {
    ...state,
    signIn,
    signUp,
    signOut,
    resetPassword,
    clearError
  }
}

// Helper function to create user profile
async function createUserProfile(user: User): Promise<void> {
  const { error } = await supabase
    .from('profiles')
    .insert({
      id: user.id,
      email: user.email!,
      full_name: user.user_metadata?.full_name || null,
      avatar_url: user.user_metadata?.avatar_url || null,
      preferred_grade_system: 'YDS' // Default to YDS grading system
    })

  if (error) {
    console.error('Error creating user profile:', error)
  }
} 