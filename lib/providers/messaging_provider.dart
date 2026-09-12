import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/messaging/data/messaging_repository.dart';
import '../models/message.dart';
import 'auth_provider.dart';

/// Resolves (finding or creating) the cleaner's single thread with the
/// business. Cached for the life of the provider — call
/// ref.invalidate(myConversationProvider) if it ever needs a hard refresh.
final myConversationProvider =
    FutureProvider.autoDispose<Conversation>((ref) async {
  final repo = ref.watch(messagingRepositoryProvider);
  final existing = await repo.findMyConversation();
  if (existing != null) return existing;
  return repo.getOrCreateMyConversation();
});

final messagesProvider =
    FutureProvider.autoDispose.family<List<ChatMessage>, String>(
  (ref, conversationId) async {
    final repo = ref.watch(messagingRepositoryProvider);
    return repo.fetchMessages(conversationId);
  },
);

class MessageActionsNotifier extends StateNotifier<AsyncValue<void>> {
  MessageActionsNotifier(this._repo, this._ref) : super(const AsyncData(null));

  final MessagingRepository _repo;
  final Ref _ref;

  Future<bool> send(String conversationId, String body) async {
    if (body.trim().isEmpty) return false;
    state = const AsyncLoading();
    try {
      await _repo.sendMessage(conversationId, body.trim());
      _ref.invalidate(messagesProvider(conversationId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> markRead(String messageId, String conversationId) async {
    try {
      await _repo.markRead(messageId);
    } catch (_) {
      // Non-fatal — read receipts are a nicety, not worth surfacing an
      // error banner over.
    }
  }
}

final messageActionsProvider =
    StateNotifierProvider<MessageActionsNotifier, AsyncValue<void>>((ref) {
  return MessageActionsNotifier(ref.watch(messagingRepositoryProvider), ref);
});

/// Convenience accessor for "is this message mine" checks in the UI.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).user?.id;
});
