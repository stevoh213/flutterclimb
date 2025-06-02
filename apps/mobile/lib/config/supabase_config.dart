import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ovdmzajbulsevlrqyscb.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92ZG16YWpidWxzZXZscnF5c2NiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg4MzYzMDksImV4cCI6MjA2NDQxMjMwOX0.R511VsA-DrQD16-O7VrNUSsOtmsZaVeplw06SfZNl-U';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;
} 