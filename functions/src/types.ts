import * as admin from "firebase-admin";

export type GameCategory = "who" | "what" | "where" | "custom";

export type RoomStatus =
  | "waiting"
  | "selectingSecrets"
  | "active"
  | "completed"
  | "cancelled"
  | "expired";

export type BoardVisibility = "private" | "shared";

export interface CustomBoardDocument {
  packId: string;
  ownerUid: string;
  category: "custom";
  name: string;
  description: string;
  visibility: BoardVisibility;
  shareCode: string | null;
  allowedPlayerUids: string[];
  cards: Array<{ id: string; name: string; isActive?: boolean }>;
  updatedAt: admin.firestore.Timestamp;
}

export interface RoomDocument {
  roomId: string;
  roomCode: string;
  hostUid: string;
  hostName: string;
  guestUid: string | null;
  guestName: string | null;
  status: RoomStatus;
  category: GameCategory;
  boardPackId: string;
  boardCardIds: string[];
  currentTurnUid: string | null;
  winnerUid: string | null;
  winReason: string | null;
  turnTimerSeconds: number | null;
  turnDeadlineAt: admin.firestore.Timestamp | null;
  questionsCount: number;
  pendingQuestionId: string | null;
  lastAnsweredQuestionId: string | null;
  guessAttemptedThisTurn: boolean;
  rematchRequestedBy: string[];
  processedRequestIds: string[];
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp;
}

export interface RoomPlayerDocument {
  playerUid: string;
  roomId: string;
  displayName: string;
  avatarId: string;
  ready: boolean;
  connected: boolean;
  hearts: number;
  eliminatedCardIds: string[];
  incorrectGuesses: number;
  questionsAsked: number;
  secretSubmitted: boolean;
}

export interface PrivateSelectionDocument {
  roomId: string;
  playerUid: string;
  secretCardId: string;
  updatedAt: admin.firestore.Timestamp;
}

export interface GameHistoryDocument {
  gameId: string;
  roomId: string;
  playerIds: string[];
  winnerUid: string;
  loserUid: string;
  winnerHeartsRemaining: number;
  category: GameCategory;
  boardPackId: string;
  duration: number;
  questionsCount: number;
  incorrectGuesses: number;
  winReason: string;
  completedAt: admin.firestore.Timestamp;
}
