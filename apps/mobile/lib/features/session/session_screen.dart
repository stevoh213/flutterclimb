import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:db/database/app_database.dart';
import 'package:ui/theme/climbing_colors.dart';
import 'package:ui/theme/climbing_spacing.dart';
import 'package:ui/widgets/quick_log_fab.dart';
import '../../providers/session_provider.dart';
import '../../providers/climb_provider.dart';
import 'quick_log_bottom_sheet.dart';
import 'widgets/session_header.dart';
import 'widgets/climb_list_item.dart';

class SessionScreen extends ConsumerWidget {
  final String sessionId;

  const SessionScreen({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(
      currentSessionProvider.select((value) => value.whenData((s) => s?.id == sessionId ? s : null)),
    );
    final climbsAsync = ref.watch(sessionClimbsProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
        actions: [
          sessionAsync.when(
            data: (session) => session != null && session.endTime == null
                ? TextButton(
                    onPressed: () => _endSession(context, ref),
                    child: const Text('End Session'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentSessionProvider);
          ref.invalidate(sessionClimbsProvider(sessionId));
        },
        child: ListView(
          children: [
            sessionAsync.when(
              data: (session) => session != null
                  ? SessionHeader(session: session)
                  : const SizedBox.shrink(),
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Error: $err'),
            ),
            Padding(
              padding: const EdgeInsets.all(ClimbingSpacing.lg),
              child: Row(
                children: [
                  Text(
                    'Climbs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  climbsAsync.when(
                    data: (climbs) => Text(
                      '${climbs.length} total',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            climbsAsync.when(
              data: (climbs) {
                if (climbs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(ClimbingSpacing.xl),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.terrain,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: ClimbingSpacing.lg),
                          Text(
                            'No climbs logged yet',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: ClimbingSpacing.sm),
                          Text(
                            'Tap the + button to log your first climb',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: climbs.map((climb) {
                    return ClimbListItem(
                      climb: climb,
                      onTap: () => _showClimbDetails(context, climb),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading climbs: $err'),
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: sessionAsync.when(
        data: (session) => session != null && session.endTime == null
            ? QuickLogFAB(
                onPressed: () => _showQuickLogSheet(context),
                showPulse: true,
              )
            : const SizedBox.shrink(),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  void _showQuickLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickLogBottomSheet(sessionId: sessionId),
    );
  }

  void _showClimbDetails(BuildContext context, Climb climb) {
    // TODO: Implement climb details screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Climb: ${climb.gradeValue}')),
    );
  }

  void _endSession(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('Are you sure you want to end this climbing session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(sessionControllerProvider.notifier).endSession(sessionId);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error ending session: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ClimbingColors.errorRed,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}