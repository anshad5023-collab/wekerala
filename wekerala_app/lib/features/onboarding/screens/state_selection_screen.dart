import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';

class _StateOption {
  final String name;
  final String key;
  final String domain;
  final bool active;
  const _StateOption({
    required this.name,
    required this.key,
    required this.domain,
    this.active = false,
  });
}

const _states = [
  _StateOption(name: 'Kerala',           key: 'kerala',      domain: 'wekerala.in',      active: true),
  _StateOption(name: 'Tamil Nadu',       key: 'tamil_nadu',  domain: 'wetamilnadu.in'),
  _StateOption(name: 'Karnataka',        key: 'karnataka',   domain: 'wekarnataka.in'),
  _StateOption(name: 'Andhra Pradesh',   key: 'andhra',      domain: 'weandhra.in'),
  _StateOption(name: 'Telangana',        key: 'telangana',   domain: 'wetelangana.in'),
  _StateOption(name: 'Maharashtra',      key: 'maharashtra', domain: 'wemaharashtra.in'),
  _StateOption(name: 'Gujarat',          key: 'gujarat',     domain: 'wegujarat.in'),
  _StateOption(name: 'Punjab',           key: 'punjab',      domain: 'wepunjab.in'),
  _StateOption(name: 'Delhi / NCR',      key: 'delhi',       domain: 'wedelhi.in'),
  _StateOption(name: 'Other State',      key: 'other',       domain: 'oratas.in'),
];

class StateSelectionScreen extends StatefulWidget {
  const StateSelectionScreen({super.key});

  @override
  State<StateSelectionScreen> createState() => _StateSelectionScreenState();
}

class _StateSelectionScreenState extends State<StateSelectionScreen> {
  String _selected = '';

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pre_login_state', _selected);
    // Domain is derived from state at runtime — stored as state key
    if (mounted) context.go('/language');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Which state are\nyou in?',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, height: 1.2,
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 6),
              const Text(
                'Your shop will be listed on the local Oratas storefront for your state',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _states.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final state = _states[i];
                    final selected = _selected == state.key;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = state.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppColors.primary : Colors.grey.shade200,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(state.name,
                                    style: TextStyle(
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 15,
                                      color: selected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    state.active ? state.domain : '${state.domain} — coming soon',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: state.active
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.active)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Live',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: selected ? AppColors.primary : Colors.grey.shade400,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 50 * i));
                  },
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Continue',
                onPressed: _selected.isEmpty ? null : _continue,
              ).animate().fadeIn(delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
