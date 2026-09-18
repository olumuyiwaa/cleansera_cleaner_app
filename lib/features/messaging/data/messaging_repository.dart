import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/message.dart';

class MessagingRepository {
  MessagingRepository(this._dio);

  final Dio _dio;

  /// A cleaner only ever has one conversation — themself <-> the business.
  /// GET /messaging?limit=1 is enough to find it if it already exists.
  Future<Conversation?> findMyConversation() async {
    final res = await _dio.get(
      ApiConstants.conversations,
      queryParameters: {'limit': 1},
    );
    final list = unwrapListEnvelope(res.data);
    if (list.isEmpty) return null;
    return Conversation.fromJson(list.first as Map<String, dynamic>);
  }
  /// List conversations (for a cleaner this is usually just one: them ↔ business)
  Future<List<Conversation>> listConversations({int page = 1, int limit = 20}) async {
    final res = await _dio.get(
      ApiConstants.conversations,
      queryParameters: {'page': page, 'limit': limit},
    );
    final list = unwrapListEnvelope(res.data);
    return list
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /messaging with no body is enough for a CLEANER caller — the
  /// backend ignores whatever subjectType/subjectId a cleaner sends and
  /// forces it to their own profile (see messaging.service.js:
  /// getOrCreateConversation). Passing CLEANER/self here anyway keeps the
  /// request self-explanatory and still valid for any other caller shape.
  Future<Conversation> getOrCreateMyConversation() async {
    final res = await _dio.post(
      ApiConstants.conversations,
      data: {'subjectType': 'CLEANER', 'subjectId': 'self'},
    );
    return Conversation.fromJson(unwrapEnvelope(res.data));
  }

  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '${ApiConstants.conversations}/$conversationId/messages',
      queryParameters: {'page': page, 'limit': limit},
    );
    final list = unwrapListEnvelope(res.data);
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage(String conversationId, String body) async {
    final res = await _dio.post(
      '${ApiConstants.conversations}/$conversationId/messages',
      data: {'body': body},
    );
    return ChatMessage.fromJson(unwrapEnvelope(res.data));
  }

  Future<void> markRead(String messageId) async {
    await _dio.patch('${ApiConstants.messagesReadPath}/$messageId/read');
  }
}

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(ref.watch(dioProvider));
});
