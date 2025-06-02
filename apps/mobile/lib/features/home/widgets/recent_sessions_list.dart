import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:db/database/app_database.dart';
import 'package:intl/intl.dart';
import 'package:ui/theme/climbing_spacing.dart';
import '../../../providers/session_provider.dart';
import '../../session/session_screen.dart';

class RecentSessionsList extends ConsumerWidget {
  const RecentSessionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionListProvider);

    return sessionsAsync.when(
      data: (sessions) {
        final recentSessions = sessions
            .where((s) => s.endTime != null)
            .take(10)
            .toList();

        if (recentSessions.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(ClimbingSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: ClimbingSpacing.md),
                    Text(
                      'No sessions yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: recentSessions.map((session) {
            return _SessionListItem(session: session);
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error loading sessions: $err'),
    );
  }
}

class _SessionListItem extends StatelessWidget {
  final Session session;

  const _SessionListItem({required this.session});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.MMMd();
    final timeFormat = DateFormat.jm();
    final duration = session.endTime!.difference(session.startTime);

    return Card(
      margin: const EdgeInsets.only(bottom: ClimbingSpacing.sm),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionScreen(sessionId: session.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(ClimbingSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    session.isOutdoor ? Icons.landscape : Icons.home_work,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: ClimbingSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.location,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: ClimbingSpacing.xs),
                    Text(
                      '${dateFormat.format(session.startTime)} • ${_formatDuration(duration)} • ${session.climbCount} climbs',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (session.completedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClimbingSpacing.sm,
                    vertical: ClimbingSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(session.completedCount / session.climbCount * 100).round()}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}