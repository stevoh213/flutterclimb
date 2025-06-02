import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/climbing_colors.dart';

class QuickLogFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final bool showPulse;

  const QuickLogFAB({
    super.key,
    required this.onPressed,
    this.showPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: ClimbingColors.cliffOrange,
      elevation: showPulse ? 8 : 4,
      child: Icon(
        Icons.add,
        size: showPulse ? 28 : 24,
        color: Colors.white,
      ),
    ).animate(
      onPlay: (controller) => showPulse ? controller.repeat() : null,
    ).scale(
      duration: const Duration(seconds: 1),
      begin: const Offset(1, 1),
      end: showPulse ? const Offset(1.1, 1.1) : const Offset(1, 1),
    );
  }
}