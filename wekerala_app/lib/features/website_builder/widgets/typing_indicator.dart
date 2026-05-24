import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

/// Three animated dots that indicate the AI is typing.
/// Uses flutter_animate for staggered bounce animation.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  static const _dotSize = 8.0;
  static const _dotSpacing = 5.0;
  static const _dotColor = AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(0),
          const SizedBox(width: _dotSpacing),
          _dot(1),
          const SizedBox(width: _dotSpacing),
          _dot(2),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return Container(
      width: _dotSize,
      height: _dotSize,
      decoration: const BoxDecoration(
        color: _dotColor,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -4,
          duration: 500.ms,
          curve: Curves.easeInOut,
          delay: (index * 150).ms,
        );
  }
}
