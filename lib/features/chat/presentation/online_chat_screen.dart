import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

/// Real-time Online Chat & Question/Answer interface.
/// Normal questions never consume hearts; opponent can tap Yes, No, or send a custom reply.
class OnlineChatScreen extends ConsumerStatefulWidget {
  const OnlineChatScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<OnlineChatScreen> createState() => _OnlineChatScreenState();
}

class _OnlineChatScreenState extends ConsumerState<OnlineChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendQuestion() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .submitQuestion(roomId: widget.roomId, question: text);
      _inputController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAnswer(
    ChatMessageType type,
    String text, {
    String? questionId,
  }) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .submitAnswer(
            roomId: widget.roomId,
            answerType: type,
            message: text,
            questionId: questionId,
          );
      if (type == ChatMessageType.customAnswer) {
        _inputController.clear();
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myUid = ref.watch(authProvider)?.uid ?? '';
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.roomId));

    final room = roomAsync.valueOrNull;
    final isMyTurn = room?.currentTurnUid == myUid;
    final canAnswerNow = !isMyTurn && (room?.hasPendingQuestion ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Match Q&A Chat'),
            Text(
              isMyTurn
                  ? 'Your turn — Ask unlimited questions (0 heart cost)'
                  : 'Opponent\'s turn — Answer Yes, No, or Custom',
              style: TextStyle(
                fontSize: 11.5,
                color: isMyTurn
                    ? AppColors.turquoiseAccent
                    : AppColors.saffronAccent,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const DesiLoadingView(message: 'Loading chat...'),
                error: (e, _) => DesiErrorState(message: e.toString()),
                data: (messages) {
                  if (messages.isNotEmpty) {
                    ref
                        .read(chatRepositoryProvider)
                        .markMessagesRead(
                          roomId: widget.roomId,
                          myUid: myUid,
                          messages: messages,
                        );
                    _scrollToBottom();
                  }
                  if (messages.isEmpty) {
                    return const DesiEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Start Asking!',
                      subtitle:
                          'Example: "Are you a cricketer?" -> Opponent replies "Yes" or "No".',
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    itemCount: messages.length,
                    itemBuilder: (_, idx) {
                      final msg = messages[idx];
                      return ChatBubble(
                        message: msg,
                        isMe: msg.senderUid == myUid,
                      );
                    },
                  );
                },
              ),
            ),

            // Quick Yes / No Response Bar for Answering Player
            if (!isMyTurn)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                color: AppColors.secondaryBackground,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!canAnswerNow)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Waiting for opponent to ask a question...',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: (_sending || !canAnswerNow)
                                ? null
                                : () => _sendAnswer(
                                    ChatMessageType.yesAnswer,
                                    l10n.t('yes'),
                                    questionId: room?.pendingQuestionId,
                                  ),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(l10n.t('yes')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: (_sending || !canAnswerNow)
                                ? null
                                : () => _sendAnswer(
                                    ChatMessageType.noAnswer,
                                    l10n.t('no'),
                                    questionId: room?.pendingQuestionId,
                                  ),
                            icon: const Icon(Icons.close_rounded),
                            label: Text(l10n.t('no')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Composer Bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: AppColors.secondaryBackground,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: isMyTurn || canAnswerNow,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => isMyTurn
                          ? _sendQuestion()
                          : (canAnswerNow
                                ? _sendAnswer(
                                    ChatMessageType.customAnswer,
                                    _inputController.text,
                                    questionId: room?.pendingQuestionId,
                                  )
                                : null),
                      decoration: InputDecoration(
                        hintText: isMyTurn
                            ? l10n.t('ask_question_hint')
                            : (canAnswerNow
                                  ? 'Optional custom reply...'
                                  : 'Wait for a question to reply...'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                    ),
                    onPressed: (_sending || (!isMyTurn && !canAnswerNow))
                        ? null
                        : () {
                            if (isMyTurn) {
                              _sendQuestion();
                            } else if (_inputController.text
                                .trim()
                                .isNotEmpty) {
                              _sendAnswer(
                                ChatMessageType.customAnswer,
                                _inputController.text,
                                questionId: room?.pendingQuestionId,
                              );
                            }
                          },
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
