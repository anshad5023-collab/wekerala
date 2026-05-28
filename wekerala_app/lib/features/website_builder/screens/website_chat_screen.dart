import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../models/chat_message.dart';
import '../providers/website_chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_bubble.dart';

/// The AI chat tab inside the Website Builder flow.
///
/// [webViewController] — the WebViewController from the parent screen;
///   used to call `window.__applyAiPatch(...)` when changes are ready.
/// [shopId] / [uid] — passed straight to the provider / API.
/// [onPreviewRequested] — switches the parent to the Preview tab.
class WebsiteChatScreen extends ConsumerStatefulWidget {
  final WebViewController? webViewController;
  final String shopId;
  final String uid;
  final VoidCallback onPreviewRequested;

  const WebsiteChatScreen({
    super.key,
    required this.webViewController,
    required this.shopId,
    required this.uid,
    required this.onPreviewRequested,
  });

  @override
  ConsumerState<WebsiteChatScreen> createState() => _WebsiteChatScreenState();
}

class _WebsiteChatScreenState extends ConsumerState<WebsiteChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Patch application ────────────────────────────────────────────────────────

  void _applyPatch(Map<String, dynamic> patch) {
    final wvc = widget.webViewController;
    if (wvc == null) return;
    try {
      final js = 'window.__applyAiPatch(${jsonEncode(patch)})';
      wvc.runJavaScript(js);
    } catch (_) {
      // If JS execution fails silently, the chat still shows the message.
    }
  }

  // ── Send / chip ──────────────────────────────────────────────────────────────

  void _send(String text) {
    ref.read(websiteChatProvider.notifier).sendMessage(
          text,
          widget.shopId,
          widget.uid,
          _applyPatch,
        );
    _scrollToBottom();
  }

  void _chipSelected(String chip) {
    ref.read(websiteChatProvider.notifier).selectChip(
          chip,
          widget.shopId,
          widget.uid,
          _applyPatch,
        );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Confirmation dialog ──────────────────────────────────────────────────────

  Future<void> _showConfirmationDialog(String prompt) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Confirm Change',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          prompt,
          style: const TextStyle(
            fontSize: 14.5,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == true) {
      ref
          .read(websiteChatProvider.notifier)
          .confirmAction(_applyPatch);
    } else {
      ref.read(websiteChatProvider.notifier).discardAction();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(websiteChatProvider);

    // Show confirmation dialog whenever the state flips to requiresConfirmation
    ref.listen<WebsiteChatState>(websiteChatProvider, (prev, next) {
      if (next.requiresConfirmation &&
          !(prev?.requiresConfirmation ?? false) &&
          next.confirmPrompt != null) {
        _showConfirmationDialog(next.confirmPrompt!);
      }
      // Auto-scroll when a new message is added
      if ((next.messages.length) > (prev?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      // resizeToAvoidBottomInset ensures the chat scrolls above the keyboard
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Pending-draft banner ────────────────────────────────────────
          if (chatState.hasPendingDraft) _PendingDraftBanner(
            onPreview: widget.onPreviewRequested,
          ),

          // ── Message list ───────────────────────────────────────────────
          Expanded(
            child: chatState.messages.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    itemCount: chatState.messages.length,
                    itemBuilder: (_, index) {
                      final msg = chatState.messages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ChatMessageBubble(
                          message: msg,
                          onChipSelected: (opt) => _send(opt),
                          onNavigate: msg.type == ChatMessageType.navigateCard
                              ? () => _handleNavigate(
                                  msg.navigateTab ?? 'preview')
                              : null,
                          onRetry: msg.type == ChatMessageType.error
                              ? () => ref
                                  .read(websiteChatProvider.notifier)
                                  .clearError()
                              : null,
                        ),
                      );
                    },
                  ),
          ),

          // ── Input bar ──────────────────────────────────────────────────
          ChatInputBar(
            chips: chatState.chips,
            isLoading: chatState.isLoading,
            onSend: _send,
            onChipSelected: _chipSelected,
          ),
        ],
      ),
    );
  }

  void _handleNavigate(String tab) {
    switch (tab.toLowerCase()) {
      case 'preview':
        widget.onPreviewRequested();
      case 'orders':
        context.push('/orders');
      case 'products':
        context.push('/products');
      case 'analytics':
        context.push('/analytics');
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigate to $tab'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }
}

// ── Pending draft banner ─────────────────────────────────────────────────────

class _PendingDraftBanner extends StatelessWidget {
  final VoidCallback onPreview;

  const _PendingDraftBanner({required this.onPreview});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight.withOpacity(0.18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.edit_note, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'You have unsaved changes — tap Preview to see them',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onPreview,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: const Text(
              'Preview',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI Website Assistant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell me what you want to change about your website — colors, announcements, delivery charges and more.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
