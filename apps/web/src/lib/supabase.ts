import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
})

// Database types for type safety
export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          email: string
          full_name: string | null
          avatar_url: string | null
          climbing_style_preference: string | null
          preferred_grade_system: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          email: string
          full_name?: string | null
          avatar_url?: string | null
          climbing_style_preference?: string | null
          preferred_grade_system?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          email?: string
          full_name?: string | null
          avatar_url?: string | null
          climbing_style_preference?: string | null
          preferred_grade_system?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      sessions: {
        Row: {
          id: string
          user_id: string
          start_time: string
          end_time: string | null
          location_name: string
          location_type: 'gym' | 'outdoor'
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          start_time: string
          end_time?: string | null
          location_name: string
          location_type: 'gym' | 'outdoor'
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          start_time?: string
          end_time?: string | null
          location_name?: string
          location_type?: 'gym' | 'outdoor'
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      climbs: {
        Row: {
          id: string
          session_id: string
          user_id: string
          grade: string
          style: string
          attempts: number
          result: string
          quality_rating: number | null
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          session_id: string
          user_id: string
          grade: string
          style: string
          attempts: number
          result: string
          quality_rating?: number | null
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          session_id?: string
          user_id?: string
          grade?: string
          style?: string
          attempts?: number
          result?: string
          quality_rating?: number | null
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
      }
    }
  }
} 