import 'package:flutter/material.dart';

import '../../models/game_models.dart';
import '../constants/app_colors.dart';
import '../utils/room_code_generator.dart';

/// Styled real-time chat bubble supporting questions, Yes/No answers, guesses, and system notices.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    if (message.messageType == ChatMessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              message.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final Color bubbleColor = switch (message.messageType) {
      ChatMessageType.yesAnswer => AppColors.success.withValues(alpha: 0.22),
      ChatMessageType.noAnswer => AppColors.danger.withValues(alpha: 0.22),
      ChatMessageType.guess => AppColors.saffronAccent.withValues(alpha: 0.22),
      _ => isMe ? AppColors.primaryAccent : AppColors.cardBackground,
    };

    final Color borderColor = switch (message.messageType) {
      ChatMessageType.yesAnswer => AppColors.success.withValues(alpha: 0.6),
      ChatMessageType.noAnswer => AppColors.danger.withValues(alpha: 0.6),
      ChatMessageType.guess => AppColors.saffronAccent.withValues(alpha: 0.7),
      _ =>
        isMe
            ? AppColors.secondaryAccent.withValues(alpha: 0.4)
            : AppColors.borderSubtle,
    };

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.senderName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              message.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight:
                    message.messageType == ChatMessageType.yesAnswer ||
                        message.messageType == ChatMessageType.noAnswer
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppUtils.formatTimestamp(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 13,
                    color: message.isRead
                        ? AppColors.turquoiseAccent
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
