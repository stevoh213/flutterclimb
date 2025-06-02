import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/theme/climbing_theme.dart';
import 'providers/database_provider.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const ProviderScope(child: ClimbingLogbookApp()));
}

class ClimbingLogbookApp extends ConsumerWidget {
  const ClimbingLogbookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Climbing Logbook',
      theme: ClimbingTheme.lightTheme(),
      darkTheme: ClimbingTheme.darkTheme(),
      home: const HomeScreen(),
    );
  }
}