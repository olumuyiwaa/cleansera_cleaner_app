import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../models/message.dart';
import '../../../providers/messaging_provider.dart';
import '../data/messaging_repository.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Could not load messages'),
              TextButton(
                onPressed: () => ref.invalidate(conversationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  const Text('No conversations yet'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final repo = ref.read(messagingRepositoryProvider);
                      final conv = await repo.getOrCreateMyConversation();
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ConversationScreen(conversationId: conv.id),
                        ),
                      );
                      ref.invalidate(conversationsProvider);
                    },
                    child: const Text('Message your business'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = conversations[index];
                final last = c.lastMessage;
                final title = c.lastMessage?.sender?.fullName ?? 'Business';
                final preview = last?.body?.trim().isNotEmpty == true
                    ? last!.body!
                    : (last?.attachmentKey != null ? 'Attachment' : 'No messages yet');
                final time = last?.createdAt;

                return Padding(padding: EdgeInsetsGeometry.all(8),child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: const Icon(Icons.business, color: AppColors.primary),
                  ),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    timeago.format(time!),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(8)),
                  tileColor: Colors.white,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConversationScreen(conversationId: c.id),
                      ),
                    );
                  },
                ),);
              },
            ),
          );
        },
      ),
    );
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await ref
        .read(messageActionsProvider.notifier)
        .send(widget.conversationId, text);
    setState(() => _sending = false);
    if (ok) {
      _controller.clear();
      _scrollToBottom();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message failed to send — try again')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation details')),
      body: Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(messagesProvider(widget.conversationId)),
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: TextButton(
                      onPressed: () => ref
                          .invalidate(messagesProvider(widget.conversationId)),
                      child: const Text('Could not load messages — retry'),
                    ),
                  ),
                ],
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 48, color: AppColors.textSecondary),
                            SizedBox(height: 12),
                            Text('No messages yet'),
                            SizedBox(height: 4),
                            Text(
                              'Send a message to your business below',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final mine =
                        currentUserId != null && msg.isMine(currentUserId);
                    return _MessageBubble(message: msg, mine: mine);
                  },
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message your business…',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),);
  }
}


class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = mine ? AppColors.primary : AppColors.surface;
    final textColor = mine ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.body != null && message.body!.isNotEmpty)
              Text(message.body!, style: TextStyle(color: textColor)),
            if (message.attachmentKey != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_file,
                        size: 14,
                        color: mine ? Colors.white70 : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Attachment',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            mine ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            Text(
              timeago.format(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: mine ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
