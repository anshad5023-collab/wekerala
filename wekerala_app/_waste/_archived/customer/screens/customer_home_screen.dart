import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/role_provider.dart';

const _categories = [
  (id: 'shops', emoji: '🛒', label: 'Shops', icon: Icons.store),
  (id: 'services', emoji: '🔧', label: 'Services', icon: Icons.build),
  (id: 'restaurants', emoji: '🍽️', label: 'Restaurants', icon: Icons.restaurant),
  (id: 'hotels', emoji: '🏨', label: 'Hotels', icon: Icons.hotel),
  (id: 'doctors', emoji: '🩺', label: 'Doctors', icon: Icons.local_hospital),
  (id: 'hospitals', emoji: '🏥', label: 'Hospitals', icon: Icons.emergency),
  (id: 'education', emoji: '🎓', label: 'Education', icon: Icons.school),
  (id: 'home-services', emoji: '🏠', label: 'Home Services', icon: Icons.home_repair_service),
  (id: 'beauty', emoji: '💇', label: 'Beauty', icon: Icons.face),
  (id: 'theaters', emoji: '🎬', label: 'Theaters', icon: Icons.movie),
];

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'wekerala',
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        "Kerala's local discovery",
                        style: TextStyle(
                          color: AppColors.background.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Switch to Business
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await ref.read(roleProvider.notifier).setRole('owner');
                      if (context.mounted) context.go('/role-select');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.background.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏪', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            'Business',
                            style: TextStyle(
                              color: AppColors.background,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 16),

            // Search bar (tappable — opens search screen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => context.go('/customer/search'),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.background.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: AppColors.background.withValues(alpha: 0.7), size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Search businesses, services…',
                        style: TextStyle(
                          color: AppColors.background.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 80.ms),

            const SizedBox(height: 16),

            // Heading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Discover local\nbusinesses',
                style: TextStyle(
                  color: AppColors.background,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2),

            const SizedBox(height: 16),

            // Category grid + deals banner
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (context, i) {
                          final cat = _categories[i];
                          // Use 'homeServices' collection ID for home-services slug
                          final collectionId =
                              cat.id == 'home-services' ? 'homeServices' : cat.id;
                          return _CategoryTile(
                            emoji: cat.emoji,
                            label: cat.label,
                            delay: 200 + i * 60,
                            onTap: () =>
                                context.go('/customer/listings/$collectionId'),
                          );
                        },
                      ),
                    ),

                    // Deals & Offers banner
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: GestureDetector(
                        onTap: () => context.go('/customer/deals'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🎁', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Text(
                                'Deals & Offers',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_ios,
                                  size: 14, color: AppColors.accent),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final String emoji;
  final String label;
  final int delay;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.emoji,
    required this.label,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: Duration(milliseconds: widget.delay)),
        ScaleEffect(
          begin: const Offset(0.9, 0.9),
          duration: 400.ms,
          delay: Duration(milliseconds: widget.delay),
          curve: Curves.easeOut,
        ),
      ],
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _scale = 0.94);
        },
        onTapUp: (_) {
          setState(() => _scale = 1.0);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
