import 'package:flutter/foundation.dart';

enum ChatMessageType { user, ai, typing, actionCard, clarifyCard, navigateCard, error }

enum ChatMessageStatus { sending, done, error }

@immutable
class ChatMessage {
  final String id;
  final ChatMessageType type;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageStatus status;
  final Map<String, dynamic>? action;
  final List<String>? clarifyOptions;
  final String? errorText;
  final String? navigateTab;

  const ChatMessage({
    required this.id,
    required this.type,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.status,
    this.action,
    this.clarifyOptions,
    this.errorText,
    this.navigateTab,
  });

  // ---------- factory constructors ----------

  factory ChatMessage.user(String text) => ChatMessage(
        id: _uid(),
        type: ChatMessageType.user,
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.sending,
      );

  factory ChatMessage.aiText(String text) => ChatMessage(
        id: _uid(),
        type: ChatMessageType.ai,
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.done,
      );

  factory ChatMessage.typing() => ChatMessage(
        id: _uid(),
        type: ChatMessageType.typing,
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.sending,
      );

  factory ChatMessage.error(String text) => ChatMessage(
        id: _uid(),
        type: ChatMessageType.error,
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.error,
        errorText: text,
      );

  factory ChatMessage.action({
    required Map<String, dynamic> action,
    required String humanMessage,
  }) =>
      ChatMessage(
        id: _uid(),
        type: ChatMessageType.actionCard,
        text: humanMessage,
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.done,
        action: action,
      );

  factory ChatMessage.clarify({
    required String question,
    required List<String> options,
  }) =>
      ChatMessage(
        id: _uid(),
        type: ChatMessageType.clarifyCard,
        text: question,
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.done,
        clarifyOptions: options,
      );

  factory ChatMessage.navigate({
    required String message,
    required String tab,
  }) =>
      ChatMessage(
        id: _uid(),
        type: ChatMessageType.navigateCard,
        text: message,
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.done,
        navigateTab: tab,
      );

  // Mark user message as done (sent successfully)
  ChatMessage markDone() => ChatMessage(
        id: id,
        type: type,
        text: text,
        isUser: isUser,
        timestamp: timestamp,
        status: ChatMessageStatus.done,
        action: action,
        clarifyOptions: clarifyOptions,
        errorText: errorText,
        navigateTab: navigateTab,
      );

  static String _uid() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}
