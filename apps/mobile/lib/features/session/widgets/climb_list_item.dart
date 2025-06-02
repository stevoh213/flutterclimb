import 'package:flutter/material.dart';
import 'package:db/database/app_database.dart';
import 'package:core/models/climb.dart' as core;
import 'package:ui/theme/climbing_colors.dart';
import 'package:ui/theme/climbing_spacing.dart';
import 'package:intl/intl.dart';

class ClimbListItem extends StatelessWidget {
  final Climb climb;
  final VoidCallback onTap;

  const ClimbListItem({
    super.key,
    required this.climb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat.jm();
    final result = core.ClimbResult.values.firstWhere(
      (r) => r.name == climb.result,
    );
    final style = core.ClimbStyle.values.firstWhere(
      (s) => s.name == climb.style,
    );

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: ClimbingSpacing.lg,
        vertical: ClimbingSpacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(ClimbingSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getResultColor(result).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    climb.gradeValue,
                    style: TextStyle(
                      color: _getResultColor(result),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ClimbingSpacing.md),
              Expanded(
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
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStyleLabel(style),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: ClimbingSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ClimbingSpacing.sm,
                            vertical: ClimbingSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _getResultColor(result).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getResultLabel(result),
                            style: TextStyle(
                              color: _getResultColor(result),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ClimbingSpacing.xs),
                    Text(
                      '${timeFormat.format(climb.timestamp)} • ${climb.attempts} ${climb.attempts == 1 ? 'attempt' : 'attempts'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (climb.notes != null && climb.notes!.isNotEmpty) ...[
                      const SizedBox(height: ClimbingSpacing.xs),
                      Text(
                        climb.notes!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (climb.rating != null)
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < climb.rating!.round()
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: ClimbingColors.warningAmber,
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getResultColor(core.ClimbResult result) {
    switch (result) {
      case core.ClimbResult.flash:
      case core.ClimbResult.onsight:
        return ClimbingColors.successGreen;
      case core.ClimbResult.redpoint:
        return ClimbingColors.cliffOrange;
      case core.ClimbResult.attempt:
        return ClimbingColors.warningAmber;
      case core.ClimbResult.project:
        return ClimbingColors.infoBlue;
    }
  }

  String _getResultLabel(core.ClimbResult result) {
    switch (result) {
      case core.ClimbResult.flash:
        return 'Flash';
      case core.ClimbResult.redpoint:
        return 'Redpoint';
      case core.ClimbResult.onsight:
        return 'Onsight';
      case core.ClimbResult.attempt:
        return 'Attempt';
      case core.ClimbResult.project:
        return 'Project';
    }
  }

  String _getStyleLabel(core.ClimbStyle style) {
    switch (style) {
      case core.ClimbStyle.sport:
        return 'Sport';
      case core.ClimbStyle.trad:
        return 'Trad';
      case core.ClimbStyle.boulder:
        return 'Boulder';
      case core.ClimbStyle.topRope:
        return 'Top Rope';
    }
  }
}