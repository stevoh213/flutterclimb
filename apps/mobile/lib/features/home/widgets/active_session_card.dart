import 'package:flutter/material.dart';
import 'package:db/database/app_database.dart';
import 'package:ui/theme/climbing_colors.dart';
import 'package:ui/theme/climbing_spacing.dart';
import 'package:intl/intl.dart';

class ActiveSessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const ActiveSessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(session.startTime);
    final durationText = _formatDuration(duration);

    return Card(
      elevation: 4,
      color: ClimbingColors.cliffOrange,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(ClimbingSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ClimbingSpacing.sm,
                      vertical: ClimbingSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    session.isOutdoor ? Icons.landscape : Icons.home_work,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: ClimbingSpacing.md),
              Text(
                session.location,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: ClimbingSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                  const SizedBox(width: ClimbingSpacing.xs),
                  Text(
                    durationText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: ClimbingSpacing.lg),
                  Icon(
                    Icons.trending_up,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                  const SizedBox(width: ClimbingSpacing.xs),
                  Text(
                    '${session.climbCount} climbs',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (session.completedCount > 0) ...[
                const SizedBox(height: ClimbingSpacing.sm),
                LinearProgressIndicator(
                  value: session.climbCount > 0
                      ? session.completedCount / session.climbCount
                      : 0,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ],
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