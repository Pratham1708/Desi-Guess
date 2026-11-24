import * as crypto from "crypto";

export const STARTING_HEARTS = 5;
export const RANDOM_BOARD_SIZE = 10;
export const ROOM_EXPIRATION_MS = 60 * 60 * 1000; // 60 minutes
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function secureShuffle<T>(items: T[]): T[] {
  const arr = [...items];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

/**
 * Balanced multi-subcategory random sampling producing exactly `boardSize` unique card IDs.
 */
export function generateBalancedRandomBoard(
  subcategories: Record<string, ReadonlySet<string>>,
  boardSize = RANDOM_BOARD_SIZE
): string[] {
  const pools: Record<string, string[]> = {};
  const seen = new Set<string>();
  let total = 0;

  for (const [subKey, cardSet] of Object.entries(subcategories)) {
    const uniqueForSub: string[] = [];
    for (const id of cardSet) {
      if (id && !seen.has(id)) {
        seen.add(id);
        uniqueForSub.push(id);
      }
    }
    if (uniqueForSub.length > 0) {
      pools[subKey] = secureShuffle(uniqueForSub);
      total += uniqueForSub.length;
    }
  }

  if (total < boardSize) {
    throw new Error(`Insufficient active cards (${total}) to build a ${boardSize}-card board.`);
  }

  const subKeys = secureShuffle(Object.keys(pools));
  const selected: string[] = [];
  const cursors: Record<string, number> = {};
  for (const k of subKeys) cursors[k] = 0;

  let progress = true;
  while (selected.length < boardSize && progress) {
    progress = false;
    for (const key of secureShuffle(subKeys)) {
      if (selected.length >= boardSize) break;
      const list = pools[key];
      const idx = cursors[key];
      if (idx < list.length) {
        selected.push(list[idx]);
        cursors[key] = idx + 1;
        progress = true;
      }
    }
  }

  return secureShuffle(selected);
}

/**
 * Assigns two guaranteed-distinct secret card IDs from the active board.
 */
export function assignDistinctSecretCards(
  boardCardIds: string[]
): { hostSecretId: string; guestSecretId: string } {
  if (boardCardIds.length < 2) {
    throw new Error("Board must contain at least 2 cards to assign secrets.");
  }
  const shuffled = secureShuffle(boardCardIds);
  if (shuffled[0] === shuffled[1]) {
    throw new Error("Failed to assign distinct secret cards.");
  }
  return { hostSecretId: shuffled[0], guestSecretId: shuffled[1] };
}

export function generateRoomCode(length = 6): string {
  const bytes = crypto.randomBytes(length);
  let code = "";
  for (let i = 0; i < length; i++) {
    code += CODE_CHARS[bytes[i] % CODE_CHARS.length];
  }
  return code;
}

export function isValidRoomCode(code: string): boolean {
  return /^[A-Z0-9]{6}$/.test(code.trim().toUpperCase());
}

export function assertCardInValidPack(
  validCardIds: ReadonlySet<string>,
  cardId: string,
  contextLabel: string
): void {
  if (!cardId || !validCardIds.has(cardId)) {
    throw new Error(`${contextLabel} card "${cardId}" does not belong to the selected board pack.`);
  }
}

export function validateAnswerSubmission(params: {
  pendingQuestionId: string | null;
  lastAnsweredQuestionId: string | null;
  requestedQuestionId?: string | null;
}): string {
  const { pendingQuestionId, lastAnsweredQuestionId, requestedQuestionId } = params;
  if (!pendingQuestionId) {
    throw new Error("There is no pending question to answer.");
  }
  if (pendingQuestionId === lastAnsweredQuestionId) {
    throw new Error("This question has already been answered.");
  }
  if (requestedQuestionId && requestedQuestionId !== pendingQuestionId) {
    throw new Error("Answer does not match the current pending question.");
  }
  return pendingQuestionId;
}

export function canAccessCustomBoard(
  board: {
    ownerUid: string;
    visibility: "private" | "shared";
    allowedPlayerUids?: string[];
  },
  uid: string
): boolean {
  if (board.ownerUid === uid) return true;
  if (board.visibility !== "shared") return false;
  return (board.allowedPlayerUids ?? []).includes(uid);
}

export function isTurnTimerExpired(
  turnDeadlineMs: number | null,
  nowMs: number
): boolean {
  if (turnDeadlineMs === null) return false;
  return nowMs >= turnDeadlineMs;
}

export interface GuessEvalInput {
  guesserHearts: number;
  guessedCardId: string;
  opponentSecretCardId: string;
}

export interface GuessEvalResult {
  correct: boolean;
  newHearts: number;
  matchEnded: boolean;
  guesserWon: boolean;
  winReason: string | null;
}

/**
 * Pure server-side evaluation of a final guess attempt.
 * - Correct guess: immediate win, hearts unchanged.
 * - Incorrect guess: deduct 1 heart. At 0 hearts, opponent wins immediately.
 */
export function evaluateFinalGuess(input: GuessEvalInput): GuessEvalResult {
  if (input.guesserHearts <= 0) {
    throw new Error("Guesser already has 0 hearts.");
  }
  if (!input.guessedCardId || !input.opponentSecretCardId) {
    throw new Error("Missing card IDs for evaluation.");
  }

  if (input.guessedCardId === input.opponentSecretCardId) {
    return {
      correct: true,
      newHearts: input.guesserHearts,
      matchEnded: true,
      guesserWon: true,
      winReason: "Correct Final Guess!",
    };
  }

  const newHearts = Math.max(0, input.guesserHearts - 1);
  if (newHearts === 0) {
    return {
      correct: false,
      newHearts: 0,
      matchEnded: true,
      guesserWon: false,
      winReason: "Opponent ran out of hearts!",
    };
  }

  return {
    correct: false,
    newHearts,
    matchEnded: false,
    guesserWon: false,
    winReason: null,
  };
}

export interface PlayerStatsUpdate {
  totalGames: number;
  wins: number;
  losses: number;
  rating: number;
  currentWinStreak: number;
  bestWinStreak: number;
  perfectGuesses: number;
  comebackWins: number;
  unlockedAchievements: string[];
}

export function computeUpdatedPlayerStats(
  current: Partial<PlayerStatsUpdate>,
  didWin: boolean,
  heartsRemaining: number
): PlayerStatsUpdate {
  const totalGames = (current.totalGames ?? 0) + 1;
  const wins = (current.wins ?? 0) + (didWin ? 1 : 0);
  const losses = (current.losses ?? 0) + (didWin ? 0 : 1);
  const currentWinStreak = didWin ? (current.currentWinStreak ?? 0) + 1 : 0;
  const bestWinStreak = Math.max(current.bestWinStreak ?? 0, currentWinStreak);
  const perfectGuesses =
    (current.perfectGuesses ?? 0) + (didWin && heartsRemaining === STARTING_HEARTS ? 1 : 0);
  const comebackWins =
    (current.comebackWins ?? 0) + (didWin && heartsRemaining === 1 ? 1 : 0);
  const rating = Math.max(
    600,
    Math.min(3000, (current.rating ?? 1000) + (didWin ? 25 : -12))
  );

  const achievements = new Set(current.unlockedAchievements ?? []);
  if (wins >= 1) achievements.add("first_victory");
  if (bestWinStreak >= 5) achievements.add("five_streak");
  if (perfectGuesses >= 1) achievements.add("perfect_guess");
  if (comebackWins >= 1) achievements.add("comeback_king");
  if (rating >= 1200 || wins >= 10) achievements.add("desi_champion");

  return {
    totalGames,
    wins,
    losses,
    rating,
    currentWinStreak,
    bestWinStreak,
    perfectGuesses,
    comebackWins,
    unlockedAchievements: Array.from(achievements),
  };
}
