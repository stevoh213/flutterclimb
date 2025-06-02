import 'package:flutter/material.dart';
import 'package:db/database/app_database.dart';
import 'package:ui/theme/climbing_colors.dart';
import 'package:ui/theme/climbing_spacing.dart';
import 'package:intl/intl.dart';

class SessionHeader extends StatelessWidget {
  final Session session;

  const SessionHeader({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.MMMd();
    final timeFormat = DateFormat.jm();
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : DateTime.now().difference(session.startTime);

    return Container(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      padding: const EdgeInsets.all(ClimbingSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session.isOutdoor ? Icons.landscape : Icons.home_work,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: ClimbingSpacing.sm),
              Expanded(
                child: Text(
                  session.location,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (session.endTime == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClimbingSpacing.sm,
                    vertical: ClimbingSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: ClimbingColors.successGreen,
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
            ],
          ),
          const SizedBox(height: ClimbingSpacing.md),
          Wrap(
            spacing: ClimbingSpacing.lg,
            runSpacing: ClimbingSpacing.sm,
            children: [
              _InfoChip(
                icon: Icons.calendar_today,
                label: dateFormat.format(session.startTime),
              ),
              _InfoChip(
                icon: Icons.access_time,
                label: '${timeFormat.format(session.startTime)} - ${session.endTime != null ? timeFormat.format(session.endTime!) : 'Now'}',
              ),
              _InfoChip(
                icon: Icons.timer,
                label: _formatDuration(duration),
              ),
            ],
          ),
          const SizedBox(height: ClimbingSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Climbs',
                  value: session.climbCount.toString(),
                  icon: Icons.terrain,
                ),
              ),
              const SizedBox(width: ClimbingSpacing.md),
              Expanded(
                child: _StatCard(
                  label: 'Completed',
                  value: session.completedCount.toString(),
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: ClimbingSpacing.md),
              Expanded(
                child: _StatCard(
                  label: 'Success Rate',
                  value: session.climbCount > 0
                      ? '${(session.completedCount / session.climbCount * 100).round()}%'
                      : '0%',
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: ClimbingSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ClimbingSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: ClimbingSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}