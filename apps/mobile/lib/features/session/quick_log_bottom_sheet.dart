import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/models/climb.dart';
import 'package:core/models/grade.dart';
import 'package:ui/theme/climbing_colors.dart';
import 'package:ui/theme/climbing_spacing.dart';
import 'package:ui/widgets/grade_selector.dart';
import '../../providers/climb_provider.dart';

class QuickLogBottomSheet extends ConsumerStatefulWidget {
  final String sessionId;

  const QuickLogBottomSheet({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<QuickLogBottomSheet> createState() => _QuickLogBottomSheetState();
}

class _QuickLogBottomSheetState extends ConsumerState<QuickLogBottomSheet> {
  Grade? selectedGrade;
  ClimbStyle selectedStyle = ClimbStyle.sport;
  ClimbResult selectedResult = ClimbResult.redpoint;
  int attempts = 1;
  final notesController = TextEditingController();

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(ClimbingSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Quick Log Climb',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: ClimbingSpacing.lg),
            
            // Grade Selection
            Text(
              'Grade',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ClimbingSpacing.sm),
            GradeSelector(
              selectedGrade: selectedGrade?.value,
              grades: _getGradesForStyle(selectedStyle),
              onGradeSelected: (grade) {
                setState(() {
                  selectedGrade = Grade.parse(grade);
                });
              },
            ),
            const SizedBox(height: ClimbingSpacing.xl),
            
            // Style Selection
            Text(
              'Style',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ClimbingSpacing.sm),
            Wrap(
              spacing: ClimbingSpacing.sm,
              children: ClimbStyle.values.map((style) {
                final isSelected = style == selectedStyle;
                return ChoiceChip(
                  label: Text(_getStyleLabel(style)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedStyle = style;
                        selectedGrade = null; // Reset grade when style changes
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: ClimbingSpacing.xl),
            
            // Result Selection
            Text(
              'Result',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ClimbingSpacing.sm),
            Wrap(
              spacing: ClimbingSpacing.sm,
              children: ClimbResult.values.map((result) {
                final isSelected = result == selectedResult;
                return ChoiceChip(
                  label: Text(_getResultLabel(result)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedResult = result;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: ClimbingSpacing.xl),
            
            // Attempts
            Row(
              children: [
                Text(
                  'Attempts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: attempts > 1
                      ? () => setState(() => attempts--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  attempts.toString(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => setState(() => attempts++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: ClimbingSpacing.xl),
            
            // Log Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedGrade != null ? _logClimb : null,
                child: const Text('Log Climb'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getGradesForStyle(ClimbStyle style) {
    if (style == ClimbStyle.boulder) {
      return Grade.vScaleGrades;
    } else {
      return Grade.ydsGrades;
    }
  }

  String _getStyleLabel(ClimbStyle style) {
    switch (style) {
      case ClimbStyle.sport:
        return 'Sport';
      case ClimbStyle.trad:
        return 'Trad';
      case ClimbStyle.boulder:
        return 'Boulder';
      case ClimbStyle.topRope:
        return 'Top Rope';
    }
  }

  String _getResultLabel(ClimbResult result) {
    switch (result) {
      case ClimbResult.flash:
        return 'Flash';
      case ClimbResult.redpoint:
        return 'Redpoint';
      case ClimbResult.onsight:
        return 'Onsight';
      case ClimbResult.attempt:
        return 'Attempt';
      case ClimbResult.project:
        return 'Project';
    }
  }

  void _logClimb() async {
    if (selectedGrade == null) return;

    try {
      await ref.read(climbControllerProvider.notifier).logClimb(
        sessionId: widget.sessionId,
        grade: selectedGrade!,
        style: selectedStyle,
        result: selectedResult,
        attempts: attempts,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Climb logged successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging climb: $e')),
        );
      }
    }
  }
}