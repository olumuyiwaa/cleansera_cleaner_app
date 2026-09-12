import 'package:equatable/equatable.dart';

class ChatSender extends Equatable {
  const ChatSender({required this.id, this.firstName, this.lastName});

  final String id;
  final String? firstName;
  final String? lastName;

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory ChatSender.fromJson(Map<String, dynamic> json) {
    return ChatSender(
      id: json['id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, firstName, lastName];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    this.sender,
    this.body,
    this.attachmentKey,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final ChatSender? sender;
  final String? body;
  final String? attachmentKey;
  final DateTime? readAt;
  final DateTime createdAt;

  /// The cleaner app only ever has one thread (itself <-> the business), so
  /// "mine" just means this message's sender is the signed-in user.
  bool isMine(String currentUserId) => senderUserId == currentUserId;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderUserId: json['senderUserId'] as String,
      sender: json['sender'] is Map<String, dynamic>
          ? ChatSender.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      // The backend sends both `body` and a `content` alias for the same
      // value — prefer `body`, since that's the canonical field name.
      body: json['body'] as String? ?? json['content'] as String?,
      attachmentKey: json['attachmentKey'] as String?,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)?.toLocal()
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, conversationId, senderUserId, body, attachmentKey, readAt, createdAt];
}

class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.businessId,
    this.lastMessage,
  });

  final String id;
  final String businessId;
  final ChatMessage? lastMessage;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      lastMessage: json['lastMessage'] is Map<String, dynamic>
          ? ChatMessage.fromJson({
              ...json['lastMessage'] as Map<String, dynamic>,
              // listConversations' lastMessage summary omits conversationId
              // (it's implied by the parent object) — fill it back in so
              // ChatMessage.fromJson doesn't choke on a missing field.
              'conversationId': json['id'],
            })
          : null,
    );
  }

  @override
  List<Object?> get props => [id, businessId, lastMessage];
}
