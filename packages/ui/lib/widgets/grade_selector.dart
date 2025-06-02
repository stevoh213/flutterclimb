import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/climbing_colors.dart';
import '../theme/climbing_spacing.dart';

class GradeSelector extends StatelessWidget {
  final String? selectedGrade;
  final Function(String) onGradeSelected;
  final List<String> grades;

  const GradeSelector({
    super.key,
    required this.selectedGrade,
    required this.onGradeSelected,
    required this.grades,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: grades.length,
        itemBuilder: (context, index) {
          final grade = grades[index];
          final isSelected = grade == selectedGrade;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onGradeSelected(grade);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: ClimbingSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: ClimbingSpacing.lg,
                vertical: ClimbingSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected ? ClimbingColors.cliffOrange : Colors.transparent,
                border: Border.all(
                  color: isSelected 
                      ? ClimbingColors.cliffOrange 
                      : Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  grade,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}