import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/chat_message.dart';
import 'typing_indicator.dart';

/// Renders a single [ChatMessage] with the correct visual style and behaviour.
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String)? onChipSelected;
  final VoidCallback? onRetry;
  final VoidCallback? onNavigate;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onChipSelected,
    this.onRetry,
    this.onNavigate,
  });

  // ── shared constants ────────────────────────────────────────────────────────
  static const _userBg = AppColors.primary;
  static const _aiBg = Color(0xFFEDEDED);
  static const _userTextStyle =
      TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45);
  static const _aiTextStyle =
      TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.45);
  static final _userRadius = BorderRadius.circular(18).copyWith(
    bottomRight: const Radius.circular(4),
  );
  static final _aiRadius = BorderRadius.circular(18).copyWith(
    bottomLeft: const Radius.circular(4),
  );

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case ChatMessageType.user:
        return _userBubble();
      case ChatMessageType.typing:
        return _typingBubble();
      case ChatMessageType.ai:
        return _aiBubble(message.text);
      case ChatMessageType.actionCard:
        return _actionCard();
      case ChatMessageType.clarifyCard:
        return _clarifyCard();
      case ChatMessageType.navigateCard:
        return _navigateCard(context);
      case ChatMessageType.error:
        return _errorBubble();
    }
  }

  // ── User bubble ─────────────────────────────────────────────────────────────

  Widget _userBubble() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: _userBg, borderRadius: _userRadius),
        child: Text(message.text, style: _userTextStyle),
      ),
    );
  }

  // ── Typing indicator ─────────────────────────────────────────────────────────

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 60),
        child: const TypingIndicator(),
      ),
    );
  }

  // ── Plain AI text bubble ─────────────────────────────────────────────────────

  Widget _aiBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: _aiBg, borderRadius: _aiRadius),
        child: Text(text, style: _aiTextStyle),
      ),
    );
  }

  // ── Action card (UPDATE_CONFIG) ──────────────────────────────────────────────

  Widget _actionCard() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _aiBg,
          borderRadius: _aiRadius,
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text, style: _aiTextStyle),
            const SizedBox(height: 8),
            _badge(),
          ],
        ),
      ),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_outline,
              size: 13, color: AppColors.success),
          SizedBox(width: 4),
          Text(
            'Applied',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Clarify card (CLARIFY_NEEDED) ────────────────────────────────────────────

  Widget _clarifyCard() {
    final options = message.clarifyOptions ?? [];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: _aiBg, borderRadius: _aiRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text, style: _aiTextStyle),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: options
                    .map((opt) => _optionChip(opt))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _optionChip(String label) {
    return InkWell(
      onTap: () => onChipSelected?.call(label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Navigate card (NAVIGATE) ─────────────────────────────────────────────────

  Widget _navigateCard(BuildContext context) {
    final tab = message.navigateTab ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: _aiBg, borderRadius: _aiRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text, style: _aiTextStyle),
            if (tab.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onNavigate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  'Open ${_tabLabel(tab)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _tabLabel(String tab) {
    switch (tab.toLowerCase()) {
      case 'preview':
        return 'Preview';
      case 'orders':
        return 'Orders';
      case 'products':
        return 'Products';
      case 'analytics':
        return 'Analytics';
      default:
        return tab;
    }
  }

  // ── Error bubble ─────────────────────────────────────────────────────────────

  Widget _errorBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: _aiRadius,
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.errorText ?? message.text,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onRetry,
                child: const Text(
                  'Tap to retry',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
