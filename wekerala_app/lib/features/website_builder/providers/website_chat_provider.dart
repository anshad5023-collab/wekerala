import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_config.dart';
import '../models/chat_message.dart';

// ---------- initial suggestion chips ----------
const List<String> kInitialChips = [
  'Change theme color',
  'Switch theme',
  'Add announcement',
  'Show today\'s orders',
  'Set delivery charge',
];

// ---------- state ----------

@immutable
class WebsiteChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final List<String> chips;
  final bool hasPendingDraft;
  final String? error;
  /// When true, the UI should show a confirmation dialog.
  final bool requiresConfirmation;
  final String? confirmPrompt;
  /// Holds the pending action that needs user confirmation.
  final Map<String, dynamic>? pendingAction;

  const WebsiteChatState({
    this.messages = const [],
    this.isLoading = false,
    this.chips = kInitialChips,
    this.hasPendingDraft = false,
    this.error,
    this.requiresConfirmation = false,
    this.confirmPrompt,
    this.pendingAction,
  });

  WebsiteChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    List<String>? chips,
    bool? hasPendingDraft,
    String? error,
    bool clearError = false,
    bool? requiresConfirmation,
    String? confirmPrompt,
    Map<String, dynamic>? pendingAction,
    bool clearPending = false,
  }) {
    return WebsiteChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      chips: chips ?? this.chips,
      hasPendingDraft: hasPendingDraft ?? this.hasPendingDraft,
      error: clearError ? null : (error ?? this.error),
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      confirmPrompt: confirmPrompt ?? this.confirmPrompt,
      pendingAction: clearPending ? null : (pendingAction ?? this.pendingAction),
    );
  }
}

// ---------- notifier ----------

class WebsiteChatNotifier extends StateNotifier<WebsiteChatState> {
  WebsiteChatNotifier() : super(const WebsiteChatState());

  String get _baseUrl => AppConfig.storefrontBaseUrl;

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> sendMessage(
    String text,
    String shopId,
    String uid,
    Function(Map<String, dynamic>) onApplyPatch,
  ) async {
    if (text.trim().isEmpty) return;

    // 1. Capture conversation history BEFORE adding the new user message
    final priorMessages = state.messages
        .where((m) =>
            m.type != ChatMessageType.typing &&
            m.type != ChatMessageType.error)
        .toList();
    final historySlice = priorMessages.length > 8
        ? priorMessages.sublist(priorMessages.length - 8)
        : priorMessages;
    final history = historySlice
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'text': m.text})
        .toList();

    // 2. Add user bubble (optimistic)
    final userMsg = ChatMessage.user(text.trim());
    _addMessage(userMsg.markDone());

    // 3. Add typing indicator
    final typingMsg = ChatMessage.typing();
    _addMessage(typingMsg);

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 4. POST to /api/chat-builder
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/api/chat-builder'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'shopId': shopId,
              'uid': uid,
              'message': text.trim(),
              'history': history,
            }),
          )
          .timeout(const Duration(seconds: 30));

      // 5. Remove typing indicator
      _removeTyping();

      if (resp.statusCode != 200) {
        _addMessage(ChatMessage.error(
          'Server error (${resp.statusCode}). Please try again.',
        ));
        state = state.copyWith(isLoading: false);
        return;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final requiresConfirmation = body['requiresConfirmation'] == true;
      final confirmPrompt = body['confirmPrompt'] as String?;
      // analyticsMessage is embedded in action.humanMessage by the server,
      // but keep this fallback for older deployments.
      final analyticsMessage = body['analyticsMessage'] as String?;
      var action = body['action'] as Map<String, dynamic>?;
      // Patch analyticsMessage into action so _handleAction can display it
      if (action != null && analyticsMessage != null && action['humanMessage'] == null) {
        action = {...action, 'humanMessage': analyticsMessage};
      }

      if (action == null) {
        _addMessage(ChatMessage.aiText('I didn\'t understand that. Try again.'));
        state = state.copyWith(isLoading: false);
        return;
      }

      // 6. If confirmation required, hold in pending state
      if (requiresConfirmation && confirmPrompt != null) {
        state = state.copyWith(
          isLoading: false,
          requiresConfirmation: true,
          confirmPrompt: confirmPrompt,
          pendingAction: action,
        );
        return;
      }

      // 7. Handle action types
      await _handleAction(action, onApplyPatch);
    } catch (e) {
      _removeTyping();
      _addMessage(ChatMessage.error(
        'Connection error. Check your internet and try again.',
      ));
      state = state.copyWith(isLoading: false);
    }
  }

  /// Called when user taps a suggestion chip.
  Future<void> selectChip(
    String chip,
    String shopId,
    String uid,
    Function(Map<String, dynamic>) onApplyPatch,
  ) =>
      sendMessage(chip, shopId, uid, onApplyPatch);

  /// User confirmed a pending action.
  Future<void> confirmAction(
    Function(Map<String, dynamic>) onApplyPatch,
  ) async {
    final action = state.pendingAction;
    if (action == null) return;

    state = state.copyWith(
      requiresConfirmation: false,
      clearPending: true,
      confirmPrompt: null,
    );

    await _handleAction(action, onApplyPatch);
  }

  /// User discarded the pending action.
  void discardAction() {
    state = state.copyWith(
      requiresConfirmation: false,
      clearPending: true,
      confirmPrompt: null,
      isLoading: false,
    );
    _addMessage(ChatMessage.aiText('OK, I won\'t make that change.'));
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _handleAction(
    Map<String, dynamic> action,
    Function(Map<String, dynamic>) onApplyPatch,
  ) async {
    final type = action['type'] as String? ?? '';
    final humanMessage = action['humanMessage'] as String? ??
        action['userMessage'] as String? ??
        '';

    switch (type) {
      case 'UPDATE_CONFIG':
        final changes = action['changes'] as Map<String, dynamic>?;
        if (changes != null) {
          try {
            onApplyPatch(changes);
          } catch (_) {
            // Patch application is best-effort; don't crash the chat.
          }
        }
        _addMessage(ChatMessage.action(
          action: action,
          humanMessage: humanMessage.isNotEmpty
              ? humanMessage
              : 'Changes applied to your website.',
        ));
        state = state.copyWith(
          isLoading: false,
          hasPendingDraft: true,
          chips: _contextualChips(type),
        );

      case 'ANALYTICS_QUERY':
        _addMessage(ChatMessage.aiText(
          humanMessage.isNotEmpty ? humanMessage : 'Here are your analytics.',
        ));
        state = state.copyWith(
          isLoading: false,
          chips: _contextualChips(type),
        );

      case 'CLARIFY_NEEDED':
        final question = action['question'] as String? ?? humanMessage;
        final rawOptions = action['options'];
        final options = rawOptions is List
            ? rawOptions.map((e) => e.toString()).toList()
            : <String>[];
        _addMessage(ChatMessage.clarify(
          question: question.isNotEmpty ? question : 'What would you like?',
          options: options,
        ));
        state = state.copyWith(
          isLoading: false,
          chips: options.isNotEmpty ? options.take(5).toList() : kInitialChips,
        );

      case 'NAVIGATE':
        final tab = action['tab'] as String? ?? '';
        _addMessage(ChatMessage.navigate(
          message: humanMessage.isNotEmpty ? humanMessage : 'Navigate to $tab',
          tab: tab,
        ));
        state = state.copyWith(
          isLoading: false,
          chips: _contextualChips(type),
        );

      case 'ERROR':
      default:
        _addMessage(ChatMessage.aiText(
          humanMessage.isNotEmpty
              ? humanMessage
              : 'Something went wrong. Please try again.',
        ));
        state = state.copyWith(
          isLoading: false,
          chips: kInitialChips,
        );
    }
  }

  void _addMessage(ChatMessage msg) {
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void _removeTyping() {
    state = state.copyWith(
      messages: state.messages
          .where((m) => m.type != ChatMessageType.typing)
          .toList(),
    );
  }

  List<String> _contextualChips(String lastActionType) {
    switch (lastActionType) {
      case 'UPDATE_CONFIG':
        return [
          'Preview changes',
          'Change font',
          'Add announcement',
          'Update delivery charge',
          'Change theme',
        ];
      case 'ANALYTICS_QUERY':
        return [
          'Show weekly revenue',
          'Top selling products',
          'Show today\'s orders',
          'Monthly summary',
          'Change theme color',
        ];
      case 'NAVIGATE':
        return kInitialChips;
      default:
        return kInitialChips;
    }
  }
}

// ---------- provider ----------

final websiteChatProvider =
    StateNotifierProvider.autoDispose<WebsiteChatNotifier, WebsiteChatState>(
  (ref) => WebsiteChatNotifier(),
);
