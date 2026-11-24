import 'package:equatable/equatable.dart';

enum GameCategory {
  who,
  what,
  where,
  custom;

  String get displayName => switch (this) {
    GameCategory.who => 'WHO',
    GameCategory.what => 'WHAT',
    GameCategory.where => 'WHERE',
    GameCategory.custom => 'CUSTOM',
  };

  int get minimumCards => switch (this) {
    GameCategory.who => 10,
    GameCategory.what => 10,
    GameCategory.where => 10,
    GameCategory.custom => 6,
  };

  static GameCategory fromString(String value) {
    return GameCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => GameCategory.who,
    );
  }
}

enum CardDifficulty {
  easy,
  medium,
  hard,
  legendary;

  String get label => switch (this) {
    CardDifficulty.easy => 'Common',
    CardDifficulty.medium => 'Popular',
    CardDifficulty.hard => 'Tricky',
    CardDifficulty.legendary => 'Iconic',
  };

  static CardDifficulty fromString(String value) {
    return CardDifficulty.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CardDifficulty.medium,
    );
  }
}

enum GameMode { local, online }

enum MatchStatus {
  waiting,
  selectingSecrets,
  active,
  completed,
  cancelled,
  expired;

  static MatchStatus fromString(String value) {
    return MatchStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MatchStatus.waiting,
    );
  }
}

enum ChatMessageType {
  question,
  yesAnswer,
  noAnswer,
  customAnswer,
  guess,
  system;

  static ChatMessageType fromString(String value) {
    return ChatMessageType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ChatMessageType.question,
    );
  }
}

/// A single collectible guessing card.
class GameCard extends Equatable {
  const GameCard({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.subcategory = '',
    this.imageUrl = '',
    this.iconName = 'sparkles',
    this.accentHex = 0xFF8B5CF6,
    this.keywords = const [],
    this.attributes = const {},
    this.difficulty = CardDifficulty.medium,
    this.isActive = true,
  });

  final String id;
  final String name;
  final GameCategory category;
  final String subcategory;
  final String imageUrl;
  final String iconName;
  final int accentHex;
  final String description;
  final List<String> keywords;
  final Map<String, String> attributes;
  final CardDifficulty difficulty;
  final bool isActive;

  GameCard copyWith({String? subcategory, String? imageUrl, bool? isActive}) =>
      GameCard(
        id: id,
        name: name,
        category: category,
        subcategory: subcategory ?? this.subcategory,
        imageUrl: imageUrl ?? this.imageUrl,
        iconName: iconName,
        accentHex: accentHex,
        description: description,
        keywords: keywords,
        attributes: attributes,
        difficulty: difficulty,
        isActive: isActive ?? this.isActive,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'subcategory': subcategory,
    'imageUrl': imageUrl,
    'iconName': iconName,
    'accentHex': accentHex,
    'description': description,
    'keywords': keywords,
    'attributes': attributes,
    'difficulty': difficulty.name,
    'isActive': isActive,
  };

  factory GameCard.fromJson(Map<String, dynamic> json) => GameCard(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    category: GameCategory.fromString(json['category'] as String? ?? 'who'),
    subcategory: json['subcategory'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    iconName: json['iconName'] as String? ?? 'sparkles',
    accentHex: json['accentHex'] as int? ?? 0xFF8B5CF6,
    description: json['description'] as String? ?? '',
    keywords: (json['keywords'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    attributes: (json['attributes'] as Map<dynamic, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
    difficulty: CardDifficulty.fromString(
      json['difficulty'] as String? ?? 'medium',
    ),
    isActive: json['isActive'] as bool? ?? true,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    subcategory,
    imageUrl,
    iconName,
    accentHex,
    description,
    keywords,
    attributes,
    difficulty,
    isActive,
  ];
}

enum BoardVisibility {
  private,
  shared;

  static BoardVisibility fromString(String value) {
    return value.toLowerCase() == 'shared'
        ? BoardVisibility.shared
        : BoardVisibility.private;
  }
}

/// A themed collection of playable cards for a category.
class BoardPack extends Equatable {
  const BoardPack({
    required this.packId,
    required this.category,
    required this.name,
    required this.description,
    required this.cards,
    this.subtitle = '',
    this.accentHex = 0xFF8B5CF6,
    this.iconName = 'cards',
    this.isCustom = false,
    this.isFeatured = false,
    this.ownerUid,
    this.visibility = BoardVisibility.private,
    this.shareCode,
    this.allowedPlayerUids = const [],
  });

  final String packId;
  final GameCategory category;
  final String name;
  final String subtitle;
  final String description;
  final List<GameCard> cards;
  final int accentHex;
  final String iconName;
  final bool isCustom;
  final bool isFeatured;
  final String? ownerUid;
  final BoardVisibility visibility;
  final String? shareCode;
  final List<String> allowedPlayerUids;

  List<GameCard> get activeCards =>
      cards.where((card) => card.isActive).toList(growable: false);

  bool get meetsMinimumSize => activeCards.length >= category.minimumCards;
  bool get isShared => visibility == BoardVisibility.shared;

  bool canBeAccessedBy(String uid) {
    if (!isCustom) return true;
    if (ownerUid == null || ownerUid == uid) return true;
    return isShared && allowedPlayerUids.contains(uid);
  }

  BoardPack copyWith({
    String? name,
    String? subtitle,
    String? description,
    List<GameCard>? cards,
    int? accentHex,
    String? iconName,
    BoardVisibility? visibility,
    String? shareCode,
    bool clearShareCode = false,
    List<String>? allowedPlayerUids,
  }) {
    return BoardPack(
      packId: packId,
      category: category,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      cards: cards ?? this.cards,
      accentHex: accentHex ?? this.accentHex,
      iconName: iconName ?? this.iconName,
      isCustom: isCustom,
      isFeatured: isFeatured,
      ownerUid: ownerUid,
      visibility: visibility ?? this.visibility,
      shareCode: clearShareCode ? null : (shareCode ?? this.shareCode),
      allowedPlayerUids: allowedPlayerUids ?? this.allowedPlayerUids,
    );
  }

  Map<String, dynamic> toJson() => {
    'packId': packId,
    'category': category.name,
    'name': name,
    'subtitle': subtitle,
    'description': description,
    'cards': cards.map((c) => c.toJson()).toList(),
    'accentHex': accentHex,
    'iconName': iconName,
    'isCustom': isCustom,
    'isFeatured': isFeatured,
    'ownerUid': ownerUid,
    'visibility': visibility.name,
    'shareCode': shareCode,
    'allowedPlayerUids': allowedPlayerUids,
  };

  factory BoardPack.fromJson(Map<String, dynamic> json) => BoardPack(
    packId: json['packId'] as String? ?? '',
    category: GameCategory.fromString(json['category'] as String? ?? 'custom'),
    name: json['name'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    description: json['description'] as String? ?? '',
    cards: (json['cards'] as List<dynamic>? ?? const [])
        .map((e) => GameCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    accentHex: json['accentHex'] as int? ?? 0xFF8B5CF6,
    iconName: json['iconName'] as String? ?? 'cards',
    isCustom: json['isCustom'] as bool? ?? false,
    isFeatured: json['isFeatured'] as bool? ?? false,
    ownerUid: json['ownerUid'] as String?,
    visibility: BoardVisibility.fromString(
      json['visibility'] as String? ?? 'private',
    ),
    shareCode: json['shareCode'] as String?,
    allowedPlayerUids: (json['allowedPlayerUids'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );

  @override
  List<Object?> get props => [
    packId,
    category,
    name,
    subtitle,
    description,
    cards,
    accentHex,
    iconName,
    isCustom,
    isFeatured,
    ownerUid,
    visibility,
    shareCode,
    allowedPlayerUids,
  ];
}

class PlayerMatchState extends Equatable {
  const PlayerMatchState({
    required this.playerId,
    required this.displayName,
    this.avatarId = 'avatar_1',
    this.hearts = 5,
    this.eliminatedCardIds = const [],
    this.secretCardId,
    this.isReady = false,
    this.isConnected = true,
    this.incorrectGuesses = 0,
    this.questionsAsked = 0,
  });

  final String playerId;
  final String displayName;
  final String avatarId;
  final int hearts;
  final List<String> eliminatedCardIds;
  final String? secretCardId;
  final bool isReady;
  final bool isConnected;
  final int incorrectGuesses;
  final int questionsAsked;

  bool get hasSelectedSecret =>
      secretCardId != null && secretCardId!.isNotEmpty;
  bool get isOutOfHearts => hearts <= 0;

  PlayerMatchState copyWith({
    String? displayName,
    String? avatarId,
    int? hearts,
    List<String>? eliminatedCardIds,
    String? secretCardId,
    bool clearSecret = false,
    bool? isReady,
    bool? isConnected,
    int? incorrectGuesses,
    int? questionsAsked,
  }) {
    return PlayerMatchState(
      playerId: playerId,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      hearts: hearts ?? this.hearts,
      eliminatedCardIds: eliminatedCardIds ?? this.eliminatedCardIds,
      secretCardId: clearSecret ? null : (secretCardId ?? this.secretCardId),
      isReady: isReady ?? this.isReady,
      isConnected: isConnected ?? this.isConnected,
      incorrectGuesses: incorrectGuesses ?? this.incorrectGuesses,
      questionsAsked: questionsAsked ?? this.questionsAsked,
    );
  }

  Map<String, dynamic> toJson({bool includeSecret = true}) => {
    'playerId': playerId,
    'displayName': displayName,
    'avatarId': avatarId,
    'hearts': hearts,
    'eliminatedCardIds': eliminatedCardIds,
    if (includeSecret) 'secretCardId': secretCardId,
    'isReady': isReady,
    'isConnected': isConnected,
    'incorrectGuesses': incorrectGuesses,
    'questionsAsked': questionsAsked,
  };

  factory PlayerMatchState.fromJson(
    Map<String, dynamic> json,
  ) => PlayerMatchState(
    playerId: json['playerId'] as String? ?? json['playerUid'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'Player',
    avatarId: json['avatarId'] as String? ?? 'avatar_1',
    hearts: json['hearts'] as int? ?? 5,
    eliminatedCardIds: (json['eliminatedCardIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    secretCardId: json['secretCardId'] as String?,
    isReady: json['isReady'] as bool? ?? json['ready'] as bool? ?? false,
    isConnected:
        json['isConnected'] as bool? ?? json['connected'] as bool? ?? true,
    incorrectGuesses: json['incorrectGuesses'] as int? ?? 0,
    questionsAsked: json['questionsAsked'] as int? ?? 0,
  );

  @override
  List<Object?> get props => [
    playerId,
    displayName,
    avatarId,
    hearts,
    eliminatedCardIds,
    secretCardId,
    isReady,
    isConnected,
    incorrectGuesses,
    questionsAsked,
  ];
}

class QuestionEntry extends Equatable {
  const QuestionEntry({
    required this.id,
    required this.askerId,
    required this.askerName,
    required this.question,
    required this.timestamp,
    this.answer,
    this.answeredBy,
    this.isFinalGuess = false,
    this.wasCorrectGuess,
  });

  final String id;
  final String askerId;
  final String askerName;
  final String question;
  final String? answer;
  final String? answeredBy;
  final DateTime timestamp;
  final bool isFinalGuess;
  final bool? wasCorrectGuess;

  QuestionEntry copyWith({String? answer, String? answeredBy}) => QuestionEntry(
    id: id,
    askerId: askerId,
    askerName: askerName,
    question: question,
    timestamp: timestamp,
    answer: answer ?? this.answer,
    answeredBy: answeredBy ?? this.answeredBy,
    isFinalGuess: isFinalGuess,
    wasCorrectGuess: wasCorrectGuess,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'askerId': askerId,
    'askerName': askerName,
    'question': question,
    'answer': answer,
    'answeredBy': answeredBy,
    'timestamp': timestamp.toIso8601String(),
    'isFinalGuess': isFinalGuess,
    'wasCorrectGuess': wasCorrectGuess,
  };

  factory QuestionEntry.fromJson(Map<String, dynamic> json) => QuestionEntry(
    id: json['id'] as String? ?? '',
    askerId: json['askerId'] as String? ?? '',
    askerName: json['askerName'] as String? ?? '',
    question: json['question'] as String? ?? '',
    answer: json['answer'] as String?,
    answeredBy: json['answeredBy'] as String?,
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    isFinalGuess: json['isFinalGuess'] as bool? ?? false,
    wasCorrectGuess: json['wasCorrectGuess'] as bool?,
  );

  @override
  List<Object?> get props => [
    id,
    askerId,
    askerName,
    question,
    answer,
    answeredBy,
    timestamp,
    isFinalGuess,
    wasCorrectGuess,
  ];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.messageId,
    required this.roomId,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.messageType,
    required this.timestamp,
    this.isRead = false,
    this.isDelivered = true,
  });

  final String messageId;
  final String roomId;
  final String senderUid;
  final String senderName;
  final String message;
  final ChatMessageType messageType;
  final DateTime timestamp;
  final bool isRead;
  final bool isDelivered;

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'roomId': roomId,
    'senderUid': senderUid,
    'senderName': senderName,
    'message': message,
    'messageType': messageType.name,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'isDelivered': isDelivered,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    messageId: json['messageId'] as String? ?? '',
    roomId: json['roomId'] as String? ?? '',
    senderUid: json['senderUid'] as String? ?? '',
    senderName: json['senderName'] as String? ?? 'Player',
    message: json['message'] as String? ?? '',
    messageType: ChatMessageType.fromString(
      json['messageType'] as String? ?? 'question',
    ),
    timestamp: _parseDate(json['timestamp']),
    isRead: json['isRead'] as bool? ?? false,
    isDelivered: json['isDelivered'] as bool? ?? true,
  );

  @override
  List<Object?> get props => [
    messageId,
    roomId,
    senderUid,
    senderName,
    message,
    messageType,
    timestamp,
    isRead,
    isDelivered,
  ];
}

class RoomData extends Equatable {
  const RoomData({
    required this.roomId,
    required this.roomCode,
    required this.hostUid,
    required this.hostName,
    this.guestUid,
    this.guestName,
    required this.status,
    required this.category,
    required this.boardPackId,
    this.boardCardIds = const [],
    this.currentTurnUid,
    this.winnerUid,
    this.winReason,
    this.turnTimerSeconds,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.questionsCount = 0,
    this.pendingQuestionId,
    this.guessAttemptedThisTurn = false,
    this.rematchRequestedBy = const [],
  });

  final String roomId;
  final String roomCode;
  final String hostUid;
  final String hostName;
  final String? guestUid;
  final String? guestName;
  final MatchStatus status;
  final GameCategory category;
  final String boardPackId;
  final List<String> boardCardIds;
  final String? currentTurnUid;
  final String? winnerUid;
  final String? winReason;
  final int? turnTimerSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final int questionsCount;
  final String? pendingQuestionId;
  final bool guessAttemptedThisTurn;
  final List<String> rematchRequestedBy;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get hasGuest => guestUid != null && guestUid!.isNotEmpty;
  bool get hasPendingQuestion =>
      pendingQuestionId != null && pendingQuestionId!.isNotEmpty;

  factory RoomData.fromJson(Map<String, dynamic> json) => RoomData(
    roomId: json['roomId'] as String? ?? '',
    roomCode: json['roomCode'] as String? ?? '',
    hostUid: json['hostUid'] as String? ?? '',
    hostName: json['hostName'] as String? ?? 'Host',
    guestUid: json['guestUid'] as String?,
    guestName: json['guestName'] as String?,
    status: MatchStatus.fromString(json['status'] as String? ?? 'waiting'),
    category: GameCategory.fromString(json['category'] as String? ?? 'who'),
    boardPackId: json['boardPackId'] as String? ?? 'random_who',
    boardCardIds: (json['boardCardIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    currentTurnUid: json['currentTurnUid'] as String?,
    winnerUid: json['winnerUid'] as String?,
    winReason: json['winReason'] as String?,
    turnTimerSeconds: json['turnTimerSeconds'] as int?,
    createdAt: _parseDate(json['createdAt']),
    updatedAt: _parseDate(json['updatedAt']),
    expiresAt: _parseDate(json['expiresAt']),
    questionsCount: json['questionsCount'] as int? ?? 0,
    pendingQuestionId: json['pendingQuestionId'] as String?,
    guessAttemptedThisTurn: json['guessAttemptedThisTurn'] as bool? ?? false,
    rematchRequestedBy:
        (json['rematchRequestedBy'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
  );

  @override
  List<Object?> get props => [
    roomId,
    roomCode,
    hostUid,
    guestUid,
    status,
    category,
    boardPackId,
    currentTurnUid,
    winnerUid,
    winReason,
    turnTimerSeconds,
    questionsCount,
    guessAttemptedThisTurn,
    rematchRequestedBy,
  ];
}

class MatchResult extends Equatable {
  const MatchResult({
    required this.matchId,
    required this.mode,
    required this.category,
    required this.packName,
    required this.winnerId,
    required this.winnerName,
    required this.loserName,
    required this.winnerHeartsRemaining,
    required this.loserHeartsRemaining,
    required this.questionsAsked,
    required this.incorrectGuesses,
    required this.durationSeconds,
    required this.winReason,
    required this.completedAt,
    this.player1SecretName,
    this.player2SecretName,
    this.roomId,
  });

  final String matchId;
  final GameMode mode;
  final GameCategory category;
  final String packName;
  final String winnerId;
  final String winnerName;
  final String loserName;
  final int winnerHeartsRemaining;
  final int loserHeartsRemaining;
  final int questionsAsked;
  final int incorrectGuesses;
  final int durationSeconds;
  final String winReason;
  final DateTime completedAt;
  final String? player1SecretName;
  final String? player2SecretName;
  final String? roomId;

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mode': mode.name,
    'category': category.name,
    'packName': packName,
    'winnerId': winnerId,
    'winnerName': winnerName,
    'loserName': loserName,
    'winnerHeartsRemaining': winnerHeartsRemaining,
    'loserHeartsRemaining': loserHeartsRemaining,
    'questionsAsked': questionsAsked,
    'incorrectGuesses': incorrectGuesses,
    'durationSeconds': durationSeconds,
    'winReason': winReason,
    'completedAt': completedAt.toIso8601String(),
    'player1SecretName': player1SecretName,
    'player2SecretName': player2SecretName,
    'roomId': roomId,
  };

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
    matchId: json['matchId'] as String? ?? '',
    mode: (json['mode'] as String?) == 'online'
        ? GameMode.online
        : GameMode.local,
    category: GameCategory.fromString(json['category'] as String? ?? 'who'),
    packName: json['packName'] as String? ?? '',
    winnerId: json['winnerId'] as String? ?? '',
    winnerName: json['winnerName'] as String? ?? '',
    loserName: json['loserName'] as String? ?? '',
    winnerHeartsRemaining: json['winnerHeartsRemaining'] as int? ?? 0,
    loserHeartsRemaining: json['loserHeartsRemaining'] as int? ?? 0,
    questionsAsked: json['questionsAsked'] as int? ?? 0,
    incorrectGuesses: json['incorrectGuesses'] as int? ?? 0,
    durationSeconds: json['durationSeconds'] as int? ?? 0,
    winReason: json['winReason'] as String? ?? 'Correct Guess',
    completedAt: _parseDate(json['completedAt']),
    player1SecretName: json['player1SecretName'] as String?,
    player2SecretName: json['player2SecretName'] as String?,
    roomId: json['roomId'] as String?,
  );

  @override
  List<Object?> get props => [
    matchId,
    mode,
    category,
    packName,
    winnerId,
    winnerName,
    loserName,
    winnerHeartsRemaining,
    loserHeartsRemaining,
    questionsAsked,
    incorrectGuesses,
    durationSeconds,
    winReason,
    completedAt,
  ];
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.username,
    this.email = '',
    this.avatarId = 'avatar_1',
    this.isGuest = true,
    this.totalGames = 0,
    this.wins = 0,
    this.losses = 0,
    this.rating = 1000,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.perfectGuesses = 0,
    this.comebackWins = 0,
    this.unlockedAchievements = const [],
    this.friends = const [],
    required this.createdAt,
  });

  final String uid;
  final String username;
  final String email;
  final String avatarId;
  final bool isGuest;
  final int totalGames;
  final int wins;
  final int losses;
  final int rating;
  final int currentWinStreak;
  final int bestWinStreak;
  final int perfectGuesses;
  final int comebackWins;
  final List<String> unlockedAchievements;
  final List<String> friends;
  final DateTime createdAt;

  double get winRate => totalGames == 0 ? 0 : (wins / totalGames) * 100;

  UserProfile copyWith({
    String? username,
    String? email,
    String? avatarId,
    bool? isGuest,
    int? totalGames,
    int? wins,
    int? losses,
    int? rating,
    int? currentWinStreak,
    int? bestWinStreak,
    int? perfectGuesses,
    int? comebackWins,
    List<String>? unlockedAchievements,
    List<String>? friends,
  }) => UserProfile(
    uid: uid,
    username: username ?? this.username,
    email: email ?? this.email,
    avatarId: avatarId ?? this.avatarId,
    isGuest: isGuest ?? this.isGuest,
    totalGames: totalGames ?? this.totalGames,
    wins: wins ?? this.wins,
    losses: losses ?? this.losses,
    rating: rating ?? this.rating,
    currentWinStreak: currentWinStreak ?? this.currentWinStreak,
    bestWinStreak: bestWinStreak ?? this.bestWinStreak,
    perfectGuesses: perfectGuesses ?? this.perfectGuesses,
    comebackWins: comebackWins ?? this.comebackWins,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    friends: friends ?? this.friends,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'email': email,
    'avatar': avatarId,
    'isGuest': isGuest,
    'totalGames': totalGames,
    'wins': wins,
    'losses': losses,
    'rating': rating,
    'currentWinStreak': currentWinStreak,
    'bestWinStreak': bestWinStreak,
    'perfectGuesses': perfectGuesses,
    'comebackWins': comebackWins,
    'unlockedAchievements': unlockedAchievements,
    'friends': friends,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    uid: json['uid'] as String? ?? 'guest_local',
    username: json['username'] as String? ?? 'Desi Player',
    email: json['email'] as String? ?? '',
    avatarId: json['avatar'] as String? ?? 'avatar_1',
    isGuest: json['isGuest'] as bool? ?? true,
    totalGames: json['totalGames'] as int? ?? 0,
    wins: json['wins'] as int? ?? 0,
    losses: json['losses'] as int? ?? 0,
    rating: json['rating'] as int? ?? 1000,
    currentWinStreak: json['currentWinStreak'] as int? ?? 0,
    bestWinStreak: json['bestWinStreak'] as int? ?? 0,
    perfectGuesses: json['perfectGuesses'] as int? ?? 0,
    comebackWins: json['comebackWins'] as int? ?? 0,
    unlockedAchievements:
        (json['unlockedAchievements'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
    friends: (json['friends'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    createdAt: _parseDate(json['createdAt']),
  );

  @override
  List<Object?> get props => [
    uid,
    username,
    email,
    avatarId,
    isGuest,
    totalGames,
    wins,
    losses,
    rating,
    currentWinStreak,
    bestWinStreak,
    perfectGuesses,
    comebackWins,
    unlockedAchievements,
    friends,
  ];
}

class Achievement extends Equatable {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.accentHex,
    this.isUnlocked = false,
  });

  final String id;
  final String title;
  final String description;
  final String iconName;
  final int accentHex;
  final bool isUnlocked;

  Achievement copyWith({bool? isUnlocked}) => Achievement(
    id: id,
    title: title,
    description: description,
    iconName: iconName,
    accentHex: accentHex,
    isUnlocked: isUnlocked ?? this.isUnlocked,
  );

  @override
  List<Object?> get props => [id, title, isUnlocked];
}

class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.username,
    required this.avatarId,
    required this.rating,
    required this.wins,
    required this.totalGames,
  });

  final int rank;
  final String uid;
  final String username;
  final String avatarId;
  final int rating;
  final int wins;
  final int totalGames;

  @override
  List<Object?> get props => [rank, uid, username, rating, wins];
}

class FriendInvite extends Equatable {
  const FriendInvite({
    required this.id,
    required this.fromUid,
    required this.fromUsername,
    required this.toUid,
    required this.toUsername,
    required this.status,
    required this.createdAt,
    this.roomCode,
  });

  final String id;
  final String fromUid;
  final String fromUsername;
  final String toUid;
  final String toUsername;
  final String status; // pending, accepted, declined, cancelled
  final DateTime createdAt;
  final String? roomCode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromUid': fromUid,
    'fromUsername': fromUsername,
    'toUid': toUid,
    'toUsername': toUsername,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'roomCode': roomCode,
  };

  factory FriendInvite.fromJson(Map<String, dynamic> json) => FriendInvite(
    id: json['id'] as String? ?? '',
    fromUid: json['fromUid'] as String? ?? '',
    fromUsername: json['fromUsername'] as String? ?? '',
    toUid: json['toUid'] as String? ?? '',
    toUsername: json['toUsername'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    createdAt: _parseDate(json['createdAt']),
    roomCode: json['roomCode'] as String?,
  );

  @override
  List<Object?> get props => [id, fromUid, toUid, toUsername, status, roomCode];
}

class AppSettings extends Equatable {
  const AppSettings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.musicEnabled = false,
    this.darkMode = true,
    this.languageCode = 'en',
    this.analyticsEnabled = true,
    this.allowFriendInvites = true,
  });

  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool musicEnabled;
  final bool darkMode;
  final String languageCode;
  final bool analyticsEnabled;
  final bool allowFriendInvites;

  AppSettings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? musicEnabled,
    bool? darkMode,
    String? languageCode,
    bool? analyticsEnabled,
    bool? allowFriendInvites,
  }) => AppSettings(
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    musicEnabled: musicEnabled ?? this.musicEnabled,
    darkMode: darkMode ?? this.darkMode,
    languageCode: languageCode ?? this.languageCode,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    allowFriendInvites: allowFriendInvites ?? this.allowFriendInvites,
  );

  @override
  List<Object?> get props => [
    soundEnabled,
    vibrationEnabled,
    musicEnabled,
    darkMode,
    languageCode,
    analyticsEnabled,
    allowFriendInvites,
  ];
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    // Supports Firestore Timestamp.toDate() dynamically without hard coupling.
    final dynamic converted = (value as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  return DateTime.now();
}
