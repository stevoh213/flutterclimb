import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/widgets/quick_log_fab.dart';
import 'package:ui/theme/climbing_colors.dart';
import '../../providers/session_provider.dart';
import '../../providers/auth_provider.dart';
import '../session/session_screen.dart';
import '../session/quick_log_bottom_sheet.dart';
import 'widgets/active_session_card.dart';
import 'widgets/recent_sessions_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSession = ref.watch(currentSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Climbing Logbook'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'signout') {
                await _handleSignOut(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh providers
          ref.invalidate(currentSessionProvider);
          ref.invalidate(sessionListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            currentSession.when(
              data: (session) {
                if (session != null) {
                  return ActiveSessionCard(
                    session: session,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionScreen(sessionId: session.id),
                        ),
                      );
                    },
                  );
                } else {
                  return _buildStartSessionCard(context, ref);
                }
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Sessions',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const RecentSessionsList(),
          ],
        ),
      ),
      floatingActionButton: currentSession.when(
        data: (session) => session != null
            ? QuickLogFAB(
                onPressed: () => _showQuickLogSheet(context, session.id),
                showPulse: true,
              )
            : const SizedBox.shrink(),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildStartSessionCard(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () => _showStartSessionDialog(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 48,
                color: ClimbingColors.cliffOrange,
              ),
              const SizedBox(height: 16),
              Text(
                'Start New Session',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to begin logging your climbs',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStartSessionDialog(BuildContext context, WidgetRef ref) {
    final locationController = TextEditingController();
    bool isOutdoor = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Start New Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g., Movement Boulder, Red Rocks',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Outdoor Session'),
                value: isOutdoor,
                onChanged: (value) => setState(() => isOutdoor = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (locationController.text.isNotEmpty) {
                  Navigator.pop(context);
                  try {
                    final session = await ref
                        .read(sessionControllerProvider.notifier)
                        .startSession(
                          location: locationController.text,
                          isOutdoor: isOutdoor,
                        );
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionScreen(sessionId: session.id),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error starting session: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    bool dialogShown = false;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Signing out...'),
            ],
          ),
        ),
      );
      dialogShown = true;

      // Attempt signout with timeout and proper error handling
      await Future.any([
        ref.read(authNotifierProvider.notifier).signOut(),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException('Signout took too long', const Duration(seconds: 10));
        }),
      ]);

      // Close loading dialog safely
      await _closeDialogSafely(context);
      dialogShown = false;

      // Success feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      // Close loading dialog safely
      if (dialogShown) {
        await _closeDialogSafely(context);
      }

      // Show success message even on timeout/error since local state is cleared
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      debugPrint('SignOut completed with warning: $e');
    }
  }

  /// Safely close dialog with multiple fallback attempts
  Future<void> _closeDialogSafely(BuildContext context) async {
    try {
      // First attempt: immediate pop
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        return;
      }

      // Second attempt: wait a bit and try again
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        return;
      }

      // Third attempt: force pop until we can't anymore
      while (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 50));
      }

    } catch (e) {
      debugPrint('Error closing dialog: $e');
      // If all else fails, try one more time after a longer delay
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } catch (e2) {
        debugPrint('Final attempt to close dialog failed: $e2');
      }
    }
  }

  void _showQuickLogSheet(BuildContext context, String sessionId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickLogBottomSheet(sessionId: sessionId),
    );
  }
}