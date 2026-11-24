import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/desi_states.dart';
import '../../../core/widgets/game_card_widget.dart';
import '../../../core/widgets/hearts_indicator.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';
import '../domain/game_engine.dart';

/// Main interactive DESI GUESS game board supporting both Local Pass-and-Play
/// and Online Multiplayer (when [roomId] is provided).
class MainGameBoardScreen extends ConsumerStatefulWidget {
  const MainGameBoardScreen({super.key, this.roomId});

  final String? roomId;

  @override
  ConsumerState<MainGameBoardScreen> createState() =>
      _MainGameBoardScreenState();
}

class _MainGameBoardScreenState extends ConsumerState<MainGameBoardScreen> {
  bool _hideEliminated = false;
  bool _peekingSecret = false;
  String? _myOnlineSecretId;
  bool _submittingOnlineGuess = false;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    if (FeatureFlags.enableOnlineMultiplayer && widget.roomId != null) {
      _loadMyOnlineSecret();
    }
  }

  Future<void> _loadMyOnlineSecret() async {
    final myUid = ref.read(authProvider)?.uid;
    if (myUid == null || widget.roomId == null) return;
    final secret = await ref
        .read(multiplayerRepositoryProvider)
        .fetchMySecretCardId(roomId: widget.roomId!, myUid: myUid);
    if (mounted) setState(() => _myOnlineSecretId = secret);
  }

  @override
  Widget build(BuildContext context) {
    if (FeatureFlags.enableOnlineMultiplayer && widget.roomId != null) {
      return _buildOnlineBoard(context, widget.roomId!);
    }
    return _buildLocalBoard(context);
  }

  // -------------------- LOCAL MODE --------------------

  Widget _buildLocalBoard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final match = ref.watch(localMatchProvider);

    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game Board')),
        body: DesiEmptyState(
          icon: Icons.sports_esports_outlined,
          title: 'No Active Match',
          subtitle: FeatureFlags.enableOnlineMultiplayer
              ? 'Start a Local or Online game from the dashboard.'
              : 'Start a Pass-and-Play match from the dashboard.',
          actionLabel: 'Go Home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    if (match.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/game/results');
      });
    } else if (match.requiresPrivacyHandoff) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/game/handoff');
      });
    }

    final active = match.activePlayer;
    final opponent = match.waitingPlayer;
    final mySecretCard = match.cardById(active.secretCardId);
    final eliminatedSet = active.eliminatedCardIds.toSet();
    final opponentCandidates = match.opponentGuessCandidatesFor(
      active.playerId,
    );
    final visibleCards = _hideEliminated
        ? match.pack.activeCards
              .where((c) => !eliminatedSet.contains(c.id))
              .toList()
        : match.pack.activeCards;

    return _buildBoardScaffold(
      context: context,
      pack: match.pack,
      currentPlayer: active,
      opponent: opponent,
      isMyTurn: true,
      turnLabel: '${active.displayName}\'s Turn â€¢ #${match.turnNumber}',
      mySecretCard: mySecretCard,
      cards: visibleCards,
      eliminatedIds: eliminatedSet,
      totalOpponentCandidates: opponentCandidates.length,
      remainingCount: match.remainingCardsFor(active.playerId),
      guessAlreadyUsed: match.guessAttemptedThisTurn,
      isOnline: false,
      onCardTap: (card) {
        if (card.id == active.secretCardId) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: Text(
                '${card.name} is YOUR secret card (MY CARD) and cannot be eliminated.',
              ),
            ),
          );
          return;
        }
        ref.read(localMatchProvider.notifier).toggleEliminateCard(card.id);
      },
      onRestoreAll: () {
        ref.read(localMatchProvider.notifier).restoreAllEliminated();
      },
      onOpenHistory: () => context.push('/game/history'),
      onOpenGuessDialog: () => _openFinalGuessSheet(
        context: context,
        candidates: opponentCandidates,
        eliminatedIds: eliminatedSet,
        onSubmitGuess: (card) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final eval = await ref
                .read(localMatchProvider.notifier)
                .submitFinalGuess(card.id);
            if (!context.mounted || eval == null) return;
            _handleLocalGuessFeedback(context, eval, messenger);
          } on AppFailure catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
      ),
      onLogVerbalNote: () => _showVerbalQuestionDialog(context),
      onForfeit: () async {
        final ok = await showDesiConfirmDialog(
          context,
          title: 'End Match?',
          message:
              '${active.displayName} will forfeit and ${opponent.displayName} will win.',
          confirmLabel: 'Forfeit',
          isDestructive: true,
        );
        if (!ok) return;
        await ref.read(localMatchProvider.notifier).forfeitCurrentPlayer();
        if (!context.mounted) return;
        context.go('/game/results');
      },
      l10n: l10n,
    );
  }

  void _handleLocalGuessFeedback(
    BuildContext context,
    GuessEvaluation evaluation,
    ScaffoldMessengerState messenger,
  ) {
    switch (evaluation.outcome) {
      case GuessOutcome.correctWin:
        context.go('/game/results');
      case GuessOutcome.incorrectDefeat:
        // Game over: show final results instead of switching turns.
        context.go('/game/results');
      case GuessOutcome.incorrectHeartLost:
        // The turn has ALREADY switched automatically. The root messenger
        // keeps the message visible across the privacy handoff screen.
        final nextName = evaluation.state.activePlayer.displayName;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Incorrect Guess! 1 Heart Lost. It\'s $nextName\'s Turn.',
              ),
            ),
          );
        context.go('/game/handoff');
    }
  }

  Future<void> _showVerbalQuestionDialog(BuildContext context) async {
    final qCtrl = TextEditingController();
    String? selectedAnswer;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Optional Question Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'In Local Mode you ask questions out loud â€” log them here only if you want a memory trail.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g., Are they a cricketer?',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: ['Yes', 'No'].map((ans) {
                  final active = selectedAnswer == ans;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Center(child: Text(ans)),
                        selected: active,
                        onSelected: (_) =>
                            setDialogState(() => selectedAnswer = ans),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (qCtrl.text.trim().isNotEmpty) {
                  ref
                      .read(localMatchProvider.notifier)
                      .logVerbalQuestion(qCtrl.text, answer: selectedAnswer);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    qCtrl.dispose();
  }

  // -------------------- ONLINE MODE --------------------

  Widget _buildOnlineBoard(BuildContext context, String roomId) {
    final l10n = AppLocalizations.of(context);
    final myUid = ref.watch(authProvider)?.uid ?? '';
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final playersAsync = ref.watch(roomPlayersStreamProvider(roomId));
    final chatAsync = ref.watch(chatMessagesStreamProvider(roomId));

    return roomAsync.when(
      loading: () => const Scaffold(
        body: DesiLoadingView(message: 'Syncing online match...'),
      ),
      error: (e, _) => Scaffold(body: DesiErrorState(message: e.toString())),
      data: (room) {
        if (room == null) {
          return const Scaffold(
            body: DesiErrorState(message: 'Room closed or expired.'),
          );
        }
        final pack = ref
            .watch(cardRepositoryProvider)
            .buildBoardPackFromCardIds(
              category: room.category,
              cardIds: room.boardCardIds,
              customPackId: room.boardPackId,
            );
        if (pack == null) {
          return const Scaffold(
            body: DesiErrorState(message: 'Board pack unavailable.'),
          );
        }

        final players = playersAsync.valueOrNull ?? const [];
        final me =
            players.where((p) => p.playerId == myUid).firstOrNull ??
            PlayerMatchState(playerId: myUid, displayName: 'You');
        final opponent =
            players.where((p) => p.playerId != myUid).firstOrNull ??
            const PlayerMatchState(playerId: 'opp', displayName: 'Opponent');

        if (room.status == MatchStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final winnerName = room.winnerUid == me.playerId
                ? me.displayName
                : opponent.displayName;
            final loserName = room.winnerUid == me.playerId
                ? opponent.displayName
                : me.displayName;
            ref.read(lastMatchResultProvider.notifier).state = MatchResult(
              matchId: room.roomId,
              mode: GameMode.online,
              category: room.category,
              packName: pack.name,
              winnerId: room.winnerUid ?? '',
              winnerName: winnerName,
              loserName: loserName,
              winnerHeartsRemaining: room.winnerUid == me.playerId
                  ? me.hearts
                  : opponent.hearts,
              loserHeartsRemaining: room.winnerUid == me.playerId
                  ? opponent.hearts
                  : me.hearts,
              questionsAsked: room.questionsCount,
              incorrectGuesses: me.incorrectGuesses + opponent.incorrectGuesses,
              durationSeconds: room.updatedAt
                  .difference(room.createdAt)
                  .inSeconds
                  .clamp(1, 7200),
              winReason: room.winReason ?? 'Match Completed',
              completedAt: room.updatedAt,
              roomId: roomId,
            );
            context.go('/game/results');
          });
        }

        final isMyTurn = room.currentTurnUid == myUid;
        final eliminatedSet = me.eliminatedCardIds.toSet();
        final visibleCards = _hideEliminated
            ? pack.activeCards
                  .where((c) => !eliminatedSet.contains(c.id))
                  .toList()
            : pack.activeCards;
        final unreadCount = (chatAsync.valueOrNull ?? const [])
            .where((m) => m.senderUid != myUid && !m.isRead)
            .length;
        final mySecretCard = pack.activeCards
            .where((c) => c.id == _myOnlineSecretId)
            .firstOrNull;
        final opponentCandidates = pack.activeCards
            .where((c) => c.id != _myOnlineSecretId)
            .toList(growable: false);
        final remainingOnline = opponentCandidates
            .where((c) => !eliminatedSet.contains(c.id))
            .length;

        return _buildBoardScaffold(
          context: context,
          pack: pack,
          currentPlayer: me,
          opponent: opponent,
          isMyTurn: isMyTurn,
          turnLabel: isMyTurn ? l10n.t('your_turn') : l10n.t('opponent_turn'),
          mySecretCard: mySecretCard,
          cards: visibleCards,
          eliminatedIds: eliminatedSet,
          totalOpponentCandidates: opponentCandidates.length,
          remainingCount: remainingOnline,
          guessAlreadyUsed:
              room.guessAttemptedThisTurn || _submittingOnlineGuess,
          isOnline: true,
          unreadChatCount: unreadCount,
          onOpenChat: () => context.push('/game/chat/$roomId'),
          onCardTap: (card) async {
            if (card.id == _myOnlineSecretId) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text(
                    '${card.name} is YOUR secret card (MY CARD) and cannot be eliminated.',
                  ),
                ),
              );
              return;
            }
            ref.read(audioServiceProvider).play(GameSfx.cardEliminate);
            final next = eliminatedSet.toList();
            if (next.contains(card.id)) {
              next.remove(card.id);
            } else {
              next.add(card.id);
            }
            await ref
                .read(multiplayerRepositoryProvider)
                .updateEliminatedCards(
                  roomId: roomId,
                  uid: myUid,
                  eliminatedCardIds: next,
                );
          },
          onRestoreAll: () async {
            await ref
                .read(multiplayerRepositoryProvider)
                .updateEliminatedCards(
                  roomId: roomId,
                  uid: myUid,
                  eliminatedCardIds: const [],
                );
          },
          onOpenHistory: () => context.push('/game/chat/$roomId'),
          onOpenGuessDialog: () => _openFinalGuessSheet(
            context: context,
            candidates: opponentCandidates,
            eliminatedIds: eliminatedSet,
            onSubmitGuess: (card) async {
              setState(() => _submittingOnlineGuess = true);
              try {
                final res = await ref
                    .read(multiplayerRepositoryProvider)
                    .submitFinalGuess(
                      roomId: roomId,
                      guessedCardId: card.id,
                      requestId: _uuid.v4(),
                    );
                if (!context.mounted) return;
                final isCorrect = res['correct'] == true;
                ref
                    .read(audioServiceProvider)
                    .play(isCorrect ? GameSfx.victory : GameSfx.heartLoss);
                if (!isCorrect) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Wrong guess! "${card.name}" was incorrect (-1 Heart).',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              } finally {
                if (mounted) setState(() => _submittingOnlineGuess = false);
              }
            },
          ),
          onForfeit: () async {
            final ok = await showDesiConfirmDialog(
              context,
              title: 'Leave Online Match?',
              message: 'Leaving will forfeit the match to your opponent.',
              confirmLabel: 'Leave Match',
              isDestructive: true,
            );
            if (!ok) return;
            await ref.read(multiplayerRepositoryProvider).leaveRoom(roomId);
            if (!context.mounted) return;
            context.go('/home');
          },
          l10n: l10n,
        );
      },
    );
  }

  // -------------------- SHARED BOARD LAYOUT --------------------

  Widget _buildBoardScaffold({
    required BuildContext context,
    required BoardPack pack,
    required PlayerMatchState currentPlayer,
    required PlayerMatchState opponent,
    required bool isMyTurn,
    required String turnLabel,
    required GameCard? mySecretCard,
    required List<GameCard> cards,
    required Set<String> eliminatedIds,
    required int totalOpponentCandidates,
    required int remainingCount,
    required bool guessAlreadyUsed,
    required bool isOnline,
    int unreadChatCount = 0,
    VoidCallback? onOpenChat,
    VoidCallback? onLogVerbalNote,
    required void Function(GameCard card) onCardTap,
    required VoidCallback onRestoreAll,
    required VoidCallback onOpenHistory,
    required VoidCallback onOpenGuessDialog,
    required VoidCallback onForfeit,
    required AppLocalizations l10n,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Forfeit / Exit',
          onPressed: onForfeit,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pack.name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              turnLabel,
              style: TextStyle(
                fontSize: 12,
                color: isMyTurn
                    ? AppColors.turquoiseAccent
                    : AppColors.saffronAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Question History',
            onPressed: onOpenHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: _hideEliminated ? 'Show Eliminated' : 'Hide Eliminated',
            onPressed: () => setState(() => _hideEliminated = !_hideEliminated),
            icon: Icon(
              _hideEliminated
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score & Hearts Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        PlayerAvatar(
                          avatarId: currentPlayer.avatarId,
                          size: 34,
                          isActiveTurn: isMyTurn,
                          isOnline: isOnline ? currentPlayer.isConnected : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentPlayer.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              HeartsIndicator(
                                hearts: currentPlayer.hearts,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                opponent.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              HeartsIndicator(
                                hearts: opponent.hearts,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PlayerAvatar(
                          avatarId: opponent.avatarId,
                          size: 34,
                          isActiveTurn: !isMyTurn,
                          isOnline: isOnline ? opponent.isConnected : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryAccent.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                ),
                                child: Text(
                                  '$remainingCount / $totalOpponentCandidates ${l10n.t('remaining_cards')}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondaryAccent,
                                  ),
                                ),
                              ),
                              if (eliminatedIds.isNotEmpty)
                                TextButton(
                                  onPressed: onRestoreAll,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Restore All',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          // Hold-to-peek secret pill (prevents accidental exposure!)
                          GestureDetector(
                            onTapDown: (_) =>
                                setState(() => _peekingSecret = true),
                            onTapUp: (_) =>
                                setState(() => _peekingSecret = false),
                            onTapCancel: () =>
                                setState(() => _peekingSecret = false),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 168),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _peekingSecret
                                      ? AppColors.saffronAccent
                                      : AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                  border: Border.all(
                                    color: AppColors.saffronAccent.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _peekingSecret
                                          ? Icons.visibility_rounded
                                          : Icons.lock_rounded,
                                      size: 14,
                                      color: _peekingSecret
                                          ? AppColors.primaryBackground
                                          : AppColors.saffronAccent,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        _peekingSecret
                                            ? (mySecretCard?.name ?? 'Hidden')
                                            : 'Hold Secret',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: _peekingSecret
                                              ? AppColors.primaryBackground
                                              : AppColors.saffronAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card Grid
            Expanded(
              child: cards.isEmpty
                  ? DesiEmptyState(
                      icon: Icons.filter_none_rounded,
                      title: 'All cards eliminated',
                      subtitle:
                          'Tap Restore All or toggle Show Eliminated to bring cards back.',
                      actionLabel: 'Restore All',
                      onAction: onRestoreAll,
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.80,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (_, idx) {
                        final card = cards[idx];
                        final isElim = eliminatedIds.contains(card.id);
                        final isMine = mySecretCard?.id == card.id;
                        return GameCardWidget(
                          card: card,
                          isEliminated: isElim,
                          isMySecretCard: isMine,
                          onTap: () => onCardTap(card),
                          onLongPress: () => _showCardDetails(context, card),
                        );
                      },
                    ),
            ),

            // Bottom Gameplay Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: AppColors.secondaryBackground,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  if (isOnline && onOpenChat != null)
                    Badge(
                      isLabelVisible: unreadChatCount > 0,
                      label: Text('$unreadChatCount'),
                      child: IconButton.filledTonal(
                        onPressed: onOpenChat,
                        icon: const Icon(Icons.chat_bubble_rounded),
                        tooltip: 'Live Chat',
                      ),
                    )
                  else if (onLogVerbalNote != null)
                    IconButton.filledTonal(
                      onPressed: onLogVerbalNote,
                      icon: const Icon(Icons.note_add_outlined),
                      tooltip: 'Log Optional Question Note',
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DesiPrimaryButton(
                      label: guessAlreadyUsed
                          ? 'Guess Used'
                          : l10n.t('make_final_guess'),
                      icon: Icons.psychology_alt_rounded,
                      gradient: AppColors.saffronGradient,
                      height: 48,
                      onPressed: (isMyTurn && !guessAlreadyUsed)
                          ? onOpenGuessDialog
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardDetails(BuildContext context, GameCard card) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(card.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: card.attributes.entries
                  .map(
                    (e) => Chip(
                      label: Text('${e.key}: ${e.value}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFinalGuessSheet({
    required BuildContext context,
    required List<GameCard> candidates,
    required Set<String> eliminatedIds,
    required Future<void> Function(GameCard card) onSubmitGuess,
  }) async {
    // Show non-eliminated suspects first for fast deduction!
    final sorted = [
      ...candidates.where((c) => !eliminatedIds.contains(c.id)),
      ...candidates.where((c) => eliminatedIds.contains(c.id)),
    ];
    GameCard? chosen;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Make Your Final Guess',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Correct = Instant Victory! Wrong = -1 Heart (max 1 guess per turn).',
                  style: TextStyle(
                    color: AppColors.saffronAccent,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, idx) {
                      final card = sorted[idx];
                      final isSelected = chosen?.id == card.id;
                      final isElim = eliminatedIds.contains(card.id);
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.saffronAccent
                                : AppColors.borderSubtle,
                          ),
                        ),
                        tileColor: isSelected
                            ? AppColors.saffronAccent.withValues(alpha: 0.18)
                            : AppColors.cardBackground,
                        title: Text(
                          card.name,
                          style: TextStyle(
                            color: isElim ? AppColors.textMuted : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          card.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.saffronAccent,
                              )
                            : (isElim
                                  ? const Text(
                                      'Eliminated',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    )
                                  : null),
                        onTap: () => setModalState(() => chosen = card),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DesiPrimaryButton(
                  label: chosen == null
                      ? 'Select a Suspect Above'
                      : 'Lock Final Guess: ${chosen!.name}',
                  gradient: AppColors.saffronGradient,
                  onPressed: chosen == null
                      ? null
                      : () async {
                          final selected = chosen!;
                          Navigator.of(ctx).pop();
                          await onSubmitGuess(selected);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
