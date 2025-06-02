import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/theme/climbing_theme.dart';
import 'config/supabase_config.dart';
import 'providers/database_provider.dart';
import 'providers/auth_provider.dart';
import 'features/home/home_screen.dart';
import 'features/auth/screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  runApp(const ProviderScope(child: ClimbingLogbookApp()));
}

class ClimbingLogbookApp extends ConsumerWidget {
  const ClimbingLogbookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isLoading = ref.watch(isLoadingProvider);

    return MaterialApp(
      title: 'Climbing Logbook',
      theme: ClimbingTheme.lightTheme(),
      darkTheme: ClimbingTheme.darkTheme(),
      home: isLoading
          ? const SplashScreen()
          : isAuthenticated
              ? const HomeScreen()
              : const AuthScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.terrain,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Climbing Logbook',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}