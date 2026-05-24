import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// The input area rendered at the bottom of the AI chat.
///
/// Layout (top → bottom):
///   1. Horizontally-scrollable suggestion chips row (always visible)
///   2. TextField + send button row
class ChatInputBar extends StatefulWidget {
  final List<String> chips;
  final bool isLoading;
  final Function(String) onSend;
  final Function(String) onChipSelected;

  const ChatInputBar({
    super.key,
    required this.chips,
    required this.isLoading,
    required this.onSend,
    required this.onChipSelected,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.primary.withOpacity(0.25);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: borderColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chip row ──────────────────────────────────────────────────────
          if (widget.chips.isNotEmpty)
            _ChipRow(
              chips: widget.chips,
              isLoading: widget.isLoading,
              onSelected: widget.onChipSelected,
            ),
          // ── Text input row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !widget.isLoading,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ask me anything about your website...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(
                  isLoading: widget.isLoading,
                  onTap: _handleSend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip row ─────────────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  final List<String> chips;
  final bool isLoading;
  final Function(String) onSelected;

  const _ChipRow({
    required this.chips,
    required this.isLoading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _SuggestionChip(
          label: chips[i],
          enabled: !isLoading,
          onTap: () => onSelected(chips[i]),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: enabled ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Send button ───────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SendButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isLoading
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}
