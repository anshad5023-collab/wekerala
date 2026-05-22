import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/role_provider.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'w',
                    style: TextStyle(
                      color: AppColors.background,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 20),
              Text(
                'wekerala',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                'How will you use wekerala?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 160.ms),
              const SizedBox(height: 6),
              Text(
                'Choose your role to get started',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ).animate().fadeIn(duration: 400.ms, delay: 220.ms),
              const SizedBox(height: 48),

              _RoleCard(
                emoji: '🛒',
                title: "I'm a Customer",
                subtitle: 'Browse local shops, services, hotels & more near you',
                color: AppColors.accent,
                delay: 300,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ref.read(roleProvider.notifier).setRole('customer');
                  if (context.mounted) context.go('/customer/home');
                },
              ),

              const SizedBox(height: 16),

              _RoleCard(
                emoji: '🏪',
                title: 'I have a Business',
                subtitle: 'List your shop, service, hotel, or restaurant on wekerala',
                color: AppColors.primary,
                delay: 400,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.go('/google-signin');
                },
              ),

              const Spacer(),
              Center(
                child: Text(
                  'You can switch anytime from Settings',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final int delay;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        FadeEffect(duration: 500.ms, delay: Duration(milliseconds: widget.delay)),
        SlideEffect(
          begin: const Offset(0, 0.08),
          duration: 400.ms,
          delay: Duration(milliseconds: widget.delay),
          curve: Curves.easeOut,
        ),
      ],
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _scale = 0.96);
        },
        onTapUp: (_) {
          setState(() => _scale = 1.0);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
