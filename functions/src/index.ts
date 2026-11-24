import * as admin from "firebase-admin";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import {
  STARTING_HEARTS,
  RANDOM_BOARD_SIZE,
  ROOM_EXPIRATION_MS,
  generateRoomCode,
  isValidRoomCode,
  generateBalancedRandomBoard,
  assignDistinctSecretCards,
  assertCardInValidPack,
  validateAnswerSubmission,
  canAccessCustomBoard,
  isTurnTimerExpired,
  evaluateFinalGuess,
  computeUpdatedPlayerStats,
} from "./gameLogic";
import { BUILT_IN_PACK_CARDS } from "./packCatalog";
import {
  BoardVisibility,
  CustomBoardDocument,
  GameCategory,
  GameHistoryDocument,
  RoomDocument,
  RoomPlayerDocument,
} from "./types";

admin.initializeApp();
const db = admin.firestore();

const COL = {
  users: "users",
  publicProfiles: "publicProfiles",
  rooms: "rooms",
  roomPlayers: "roomPlayers",
  privateSelections: "privateSelections",
  messages: "messages",
  gameHistory: "gameHistory",
  customBoards: "customBoards",
};

function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

async function getUserDisplayInfo(uid: string): Promise<{ name: string; avatarId: string }> {
  const pubSnap = await db.collection(COL.publicProfiles).doc(uid).get();
  const data = pubSnap.exists
    ? pubSnap.data()
    : (await db.collection(COL.users).doc(uid).get()).data();
  return {
    name: (data?.username as string) || "Desi Player",
    avatarId: (data?.avatar as string) || "avatar_1",
  };
}

function assertMembership(room: RoomDocument, uid: string): void {
  if (room.hostUid !== uid && room.guestUid !== uid) {
    throw new HttpsError("permission-denied", "You are not a member of this room.");
  }
}

function assertNotExpired(room: RoomDocument, now: admin.firestore.Timestamp): void {
  if (room.status === "expired" || room.expiresAt.toMillis() < now.toMillis()) {
    throw new HttpsError("failed-precondition", "This room has expired.");
  }
}

function getOpponentUid(room: RoomDocument, uid: string): string {
  if (room.hostUid === uid && room.guestUid) return room.guestUid;
  if (room.guestUid === uid) return room.hostUid;
  throw new HttpsError("failed-precondition", "Opponent is not in the room.");
}

function computeNextDeadline(
  now: admin.firestore.Timestamp,
  turnTimerSeconds: number | null
): admin.firestore.Timestamp | null {
  if (!turnTimerSeconds || turnTimerSeconds <= 0) return null;
  return admin.firestore.Timestamp.fromMillis(now.toMillis() + turnTimerSeconds * 1000);
}

function builtInSubcategoriesFor(category: GameCategory): Record<string, ReadonlySet<string>> {
  const prefix = `${category}_`;
  const result: Record<string, ReadonlySet<string>> = {};
  for (const [packId, cardSet] of Object.entries(BUILT_IN_PACK_CARDS)) {
    if (packId.startsWith(prefix)) {
      result[packId] = cardSet;
    }
  }
  return result;
}

/**
 * Generates a fresh 10-card randomized board for WHO/WHAT/WHERE (across ALL subcategories)
 * or samples from an authorized custom board.
 */
async function generateRoomBoardInTx(
  tx: admin.firestore.Transaction,
  category: GameCategory,
  boardPackId: string,
  uid: string
): Promise<string[]> {
  if (category !== "custom") {
    const subs = builtInSubcategoriesFor(category);
    return generateBalancedRandomBoard(subs, RANDOM_BOARD_SIZE);
  }
  const customCards = await resolvePackCardIdsInTx(tx, category, boardPackId, uid);
  const targetSize = Math.min(RANDOM_BOARD_SIZE, customCards.size);
  return generateBalancedRandomBoard({ [boardPackId]: customCards }, targetSize);
}

/**
 * Resolves valid card IDs for a room's boardPackId from either the built-in
 * server catalog or an authorized Firestore customBoards document.
 */
async function resolvePackCardIdsInTx(
  tx: admin.firestore.Transaction,
  category: GameCategory,
  boardPackId: string,
  uid: string
): Promise<ReadonlySet<string>> {
  if (category !== "custom" && boardPackId === `random_${category}`) {
    const combined = new Set<string>();
    for (const set of Object.values(builtInSubcategoriesFor(category))) {
      for (const id of set) combined.add(id);
    }
    return combined;
  }

  const builtIn = BUILT_IN_PACK_CARDS[boardPackId];
  if (builtIn) return builtIn;

  if (category !== "custom") {
    throw new HttpsError("not-found", `Board pack "${boardPackId}" does not exist.`);
  }

  const boardSnap = await tx.get(db.collection(COL.customBoards).doc(boardPackId));
  const board = boardSnap.data() as CustomBoardDocument | undefined;
  if (!board) {
    throw new HttpsError("not-found", "Custom board not found.");
  }
  if (!canAccessCustomBoard(board, uid)) {
    throw new HttpsError(
      "permission-denied",
      "You do not have permission to play this custom board."
    );
  }
  const activeIds = (board.cards ?? [])
    .filter((c) => c.isActive !== false && Boolean(c.id))
    .map((c) => c.id);
  if (activeIds.length < 6) {
    throw new HttpsError(
      "failed-precondition",
      "Custom board must contain at least 6 active cards."
    );
  }
  return new Set(activeIds);
}

// ============================================================================
// 1. createRoom
// ============================================================================
export const createRoom = onCall(async (request) => {
  const uid = requireAuth(request);
  const category = String(request.data?.category ?? "who") as GameCategory;
  const boardPackId = String(
    request.data?.boardPackId ?? (category === "custom" ? "" : `random_${category}`)
  );
  const turnTimerSeconds =
    typeof request.data?.turnTimerSeconds === "number" && request.data.turnTimerSeconds >= 15
      ? Math.min(300, Math.floor(request.data.turnTimerSeconds))
      : null;

  if (!["who", "what", "where", "custom"].includes(category)) {
    throw new HttpsError("invalid-argument", "Invalid category.");
  }

  const user = await getUserDisplayInfo(uid);
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + ROOM_EXPIRATION_MS
  );

  let roomCode = generateRoomCode();
  for (let attempt = 0; attempt < 5; attempt++) {
    const existing = await db
      .collection(COL.rooms)
      .where("roomCode", "==", roomCode)
      .where("status", "in", ["waiting", "selectingSecrets", "active"])
      .limit(1)
      .get();
    if (existing.empty) break;
    roomCode = generateRoomCode();
  }

  const roomRef = db.collection(COL.rooms).doc();
  const playerRef = db.collection(COL.roomPlayers).doc(`${roomRef.id}_${uid}`);

  await db.runTransaction(async (tx) => {
    await resolvePackCardIdsInTx(tx, category, boardPackId, uid);

    const roomDoc: RoomDocument = {
      roomId: roomRef.id,
      roomCode,
      hostUid: uid,
      hostName: user.name,
      guestUid: null,
      guestName: null,
      status: "waiting",
      category,
      boardPackId,
      boardCardIds: [],
      currentTurnUid: null,
      winnerUid: null,
      winReason: null,
      turnTimerSeconds,
      turnDeadlineAt: null,
      questionsCount: 0,
      pendingQuestionId: null,
      lastAnsweredQuestionId: null,
      guessAttemptedThisTurn: false,
      rematchRequestedBy: [],
      processedRequestIds: [],
      createdAt: now,
      updatedAt: now,
      expiresAt,
    };

    const playerDoc: RoomPlayerDocument = {
      playerUid: uid,
      roomId: roomRef.id,
      displayName: user.name,
      avatarId: user.avatarId,
      ready: true,
      connected: true,
      hearts: STARTING_HEARTS,
      eliminatedCardIds: [],
      incorrectGuesses: 0,
      questionsAsked: 0,
      secretSubmitted: false,
    };

    tx.set(roomRef, roomDoc);
    tx.set(playerRef, playerDoc);
  });

  return { roomId: roomRef.id, roomCode };
});

// ============================================================================
// 2. joinRoom (with reconnection & custom board permission verification)
// ============================================================================
export const joinRoom = onCall(async (request) => {
  const uid = requireAuth(request);
  const rawCode = String(request.data?.roomCode ?? "").trim().toUpperCase();
  if (!isValidRoomCode(rawCode)) {
    throw new HttpsError("invalid-argument", "Invalid 6-character room code.");
  }

  const query = await db
    .collection(COL.rooms)
    .where("roomCode", "==", rawCode)
    .limit(1)
    .get();

  if (query.empty) {
    throw new HttpsError("not-found", "Room not found. Check the code and try again.");
  }

  const roomRef = query.docs[0].ref;
  const user = await getUserDisplayInfo(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    const room = snap.data() as RoomDocument | undefined;
    if (!room) throw new HttpsError("not-found", "Room no longer exists.");

    const now = admin.firestore.Timestamp.now();
    assertNotExpired(room, now);

    // Reconnection path for existing room members
    if (room.hostUid === uid || room.guestUid === uid) {
      const pRef = db.collection(COL.roomPlayers).doc(`${roomRef.id}_${uid}`);
      tx.update(pRef, { connected: true });
      return;
    }

    if (room.status !== "waiting" || room.guestUid !== null) {
      throw new HttpsError("failed-precondition", "This room is already full or active.");
    }

    // If room uses a custom board, verify board is shared and grant room participant read access
    if (room.category === "custom") {
      const boardRef = db.collection(COL.customBoards).doc(room.boardPackId);
      const boardSnap = await tx.get(boardRef);
      const board = boardSnap.data() as CustomBoardDocument | undefined;
      if (!board) {
        throw new HttpsError("not-found", "Custom board for this room no longer exists.");
      }
      if (board.visibility !== "shared" && !canAccessCustomBoard(board, uid)) {
        throw new HttpsError(
          "permission-denied",
          "Host must set this custom board to Shared before others can join."
        );
      }
      if (!(board.allowedPlayerUids ?? []).includes(uid)) {
        tx.update(boardRef, {
          allowedPlayerUids: admin.firestore.FieldValue.arrayUnion(uid),
        });
      }
    }

    tx.update(roomRef, {
      guestUid: uid,
      guestName: user.name,
      updatedAt: now,
    });

    const guestDoc: RoomPlayerDocument = {
      playerUid: uid,
      roomId: roomRef.id,
      displayName: user.name,
      avatarId: user.avatarId,
      ready: false,
      connected: true,
      hearts: STARTING_HEARTS,
      eliminatedCardIds: [],
      incorrectGuesses: 0,
      questionsAsked: 0,
      secretSubmitted: false,
    };
    tx.set(db.collection(COL.roomPlayers).doc(`${roomRef.id}_${uid}`), guestDoc);
  });

  return { roomId: roomRef.id };
});

// ============================================================================
// 3. leaveRoom
// ============================================================================
export const leaveRoom = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  if (!roomId) throw new HttpsError("invalid-argument", "roomId is required.");

  const roomRef = db.collection(COL.rooms).doc(roomId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    const room = snap.data() as RoomDocument | undefined;
    if (!room) return;
    assertMembership(room, uid);

    const now = admin.firestore.Timestamp.now();

    if (room.status === "waiting") {
      if (room.hostUid === uid) {
        tx.update(roomRef, { status: "cancelled", updatedAt: now });
      } else {
        tx.update(roomRef, { guestUid: null, guestName: null, updatedAt: now });
        tx.delete(db.collection(COL.roomPlayers).doc(`${roomId}_${uid}`));
      }
      return;
    }

    if (room.status === "active" || room.status === "selectingSecrets") {
      const winnerUid = getOpponentUid(room, uid);
      await finalizeMatchInTx(tx, roomRef, room, winnerUid, "Opponent left the match.", now);
    }
  });

  return { ok: true };
});

// ============================================================================
// 4. startMatch (Generates randomized 10-card board & assigns 2 distinct secrets)
// ============================================================================
export const startMatch = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  const roomRef = db.collection(COL.rooms).doc(roomId);
  let generatedBoard: string[] = [];

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    const room = snap.data() as RoomDocument | undefined;
    if (!room) throw new HttpsError("not-found", "Room not found.");

    const now = admin.firestore.Timestamp.now();
    assertNotExpired(room, now);

    if (room.hostUid !== uid) {
      throw new HttpsError("permission-denied", "Only the room host can start the match.");
    }
    if (!room.guestUid) {
      throw new HttpsError("failed-precondition", "Wait for a second player to join.");
    }
    if (room.status !== "waiting") {
      throw new HttpsError("failed-precondition", "Match has already started.");
    }

    generatedBoard = await generateRoomBoardInTx(
      tx,
      room.category,
      room.boardPackId,
      uid
    );
    const { hostSecretId, guestSecretId } = assignDistinctSecretCards(generatedBoard);

    // Store secrets ONLY in privateSelections — NEVER in public room doc
    tx.set(db.collection(COL.privateSelections).doc(`${roomId}_${room.hostUid}`), {
      roomId,
      playerUid: room.hostUid,
      secretCardId: hostSecretId,
      updatedAt: now,
    });
    tx.set(db.collection(COL.privateSelections).doc(`${roomId}_${room.guestUid}`), {
      roomId,
      playerUid: room.guestUid,
      secretCardId: guestSecretId,
      updatedAt: now,
    });

    tx.update(db.collection(COL.roomPlayers).doc(`${roomId}_${room.hostUid}`), {
      secretSubmitted: true,
      ready: true,
    });
    tx.update(db.collection(COL.roomPlayers).doc(`${roomId}_${room.guestUid}`), {
      secretSubmitted: true,
      ready: true,
    });

    tx.update(roomRef, {
      status: "active",
      boardCardIds: generatedBoard,
      currentTurnUid: room.hostUid,
      turnDeadlineAt: computeNextDeadline(now, room.turnTimerSeconds),
      guessAttemptedThisTurn: false,
      pendingQuestionId: null,
      lastAnsweredQuestionId: null,
      updatedAt: now,
    });

    const sysMsgRef = db.collection(COL.messages).doc();
    tx.set(sysMsgRef, {
      messageId: sysMsgRef.id,
      roomId,
      senderUid: "system",
      senderName: "Referee",
      message: `Randomized 10-card ${room.category.toUpperCase()} board ready! Secret cards assigned. ${room.hostName} goes first.`,
      messageType: "system",
      isRead: false,
      isDelivered: true,
      timestamp: now,
    });
  });

  return { status: "active", boardCardIds: generatedBoard };
});

// ============================================================================
// 5. submitSecretSelection (Validated against selected pack, write-once, private)
// ============================================================================
export const submitSecretSelection = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  const secretCardId = String(request.data?.secretCardId ?? "").trim();

  if (!roomId || !secretCardId) {
    throw new HttpsError("invalid-argument", "roomId and secretCardId are required.");
  }

  const roomRef = db.collection(COL.rooms).doc(roomId);
  const myPlayerRef = db.collection(COL.roomPlayers).doc(`${roomId}_${uid}`);
  const privateRef = db.collection(COL.privateSelections).doc(`${roomId}_${uid}`);

  let started = false;

  await db.runTransaction(async (tx) => {
    const [roomSnap, myPrivateSnap] = await Promise.all([
      tx.get(roomRef),
      tx.get(privateRef),
    ]);
    const room = roomSnap.data() as RoomDocument | undefined;
    if (!room) throw new HttpsError("not-found", "Room not found.");

    const now = admin.firestore.Timestamp.now();
    assertMembership(room, uid);
    assertNotExpired(room, now);

    if (room.status !== "selectingSecrets") {
      throw new HttpsError("failed-precondition", "Secret selection phase is closed.");
    }
    if (myPrivateSnap.exists) {
      throw new HttpsError(
        "already-exists",
        "Your secret card is already locked for this match."
      );
    }

    const validCardIds = await resolvePackCardIdsInTx(
      tx,
      room.category,
      room.boardPackId,
      uid
    );
    try {
      assertCardInValidPack(validCardIds, secretCardId, "Secret");
    } catch (e) {
      throw new HttpsError("invalid-argument", (e as Error).message);
    }

    const oppUid = getOpponentUid(room, uid);
    const oppPrivateSnap = await tx.get(
      db.collection(COL.privateSelections).doc(`${roomId}_${oppUid}`)
    );

    tx.set(privateRef, {
      roomId,
      playerUid: uid,
      secretCardId,
      updatedAt: now,
    });
    tx.update(myPlayerRef, { secretSubmitted: true, ready: true });

    if (oppPrivateSnap.exists) {
      started = true;
      tx.update(roomRef, {
        status: "active",
        currentTurnUid: room.hostUid,
        turnDeadlineAt: computeNextDeadline(now, room.turnTimerSeconds),
        guessAttemptedThisTurn: false,
        pendingQuestionId: null,
        lastAnsweredQuestionId: null,
        updatedAt: now,
      });
      const sysMsgRef = db.collection(COL.messages).doc();
      tx.set(sysMsgRef, {
        messageId: sysMsgRef.id,
        roomId,
        senderUid: "system",
        senderName: "Referee",
        message: `Both secret cards are locked! ${room.hostName} goes first.`,
        messageType: "system",
        isRead: false,
        isDelivered: true,
        timestamp: now,
      });
    }
  });

  return { ok: true, matchStarted: started };
});

// ============================================================================
// 6. submitQuestion (Unlimited normal questions, idempotent, sets pendingQuestionId)
// ============================================================================
export const submitQuestion = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  const message = String(request.data?.message ?? "").trim();
  const requestId = String(request.data?.requestId ?? "").trim();

  if (!roomId || !message || message.length > 300) {
    throw new HttpsError("invalid-argument", "Question must be 1–300 characters.");
  }

  const roomRef = db.collection(COL.rooms).doc(roomId);
  const playerRef = db.collection(COL.roomPlayers).doc(`${roomId}_${uid}`);
  let messageId = "";

  await db.runTransaction(async (tx) => {
    const [roomSnap, playerSnap] = await Promise.all([
      tx.get(roomRef),
      tx.get(playerRef),
    ]);
    const room = roomSnap.data() as RoomDocument | undefined;
    const player = playerSnap.data() as RoomPlayerDocument | undefined;
    if (!room || !player) throw new HttpsError("not-found", "Room not found.");

    const now = admin.firestore.Timestamp.now();
    assertMembership(room, uid);
    assertNotExpired(room, now);

    if (room.status !== "active") {
      throw new HttpsError("failed-precondition", "Match is not active.");
    }
    if (room.currentTurnUid !== uid) {
      throw new HttpsError("permission-denied", "Wait for your turn to ask a question.");
    }
    if (requestId && (room.processedRequestIds ?? []).includes(requestId)) {
      throw new HttpsError("already-exists", "Duplicate question submission ignored.");
    }

    const msgRef = db.collection(COL.messages).doc();
    messageId = msgRef.id;
    const updatedRequestIds = requestId
      ? [...(room.processedRequestIds ?? []).slice(-30), requestId]
      : room.processedRequestIds ?? [];

    tx.set(msgRef, {
      messageId: msgRef.id,
      roomId,
      senderUid: uid,
      senderName: player.displayName,
      message,
      messageType: "question",
      isRead: false,
      isDelivered: true,
      timestamp: now,
    });
    tx.update(roomRef, {
      questionsCount: admin.firestore.FieldValue.increment(1),
      pendingQuestionId: msgRef.id,
      processedRequestIds: updatedRequestIds,
      updatedAt: now,
    });
    tx.update(playerRef, {
      questionsAsked: admin.firestore.FieldValue.increment(1),
    });
  });

  return { ok: true, questionId: messageId };
});

// ============================================================================
// 7. submitAnswer (Requires pending question, prevents duplicate answers, handles endTurn)
// ============================================================================
export const submitAnswer = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  const action = String(request.data?.action ?? "answer");
  const requestId = String(request.data?.requestId ?? "").trim();
  const requestedQuestionId =
    typeof request.data?.questionId === "string" ? request.data.questionId : null;

  if (!roomId) throw new HttpsError("invalid-argument", "roomId is required.");

  const roomRef = db.collection(COL.rooms).doc(roomId);
  const playerRef = db.collection(COL.roomPlayers).doc(`${roomId}_${uid}`);

  await db.runTransaction(async (tx) => {
    const [roomSnap, playerSnap] = await Promise.all([
      tx.get(roomRef),
      tx.get(playerRef),
    ]);
    const room = roomSnap.data() as RoomDocument | undefined;
    const player = playerSnap.data() as RoomPlayerDocument | undefined;
    if (!room || !player) throw new HttpsError("not-found", "Room not found.");

    const now = admin.firestore.Timestamp.now();
    assertMembership(room, uid);
    assertNotExpired(room, now);

    if (room.status !== "active") {
      throw new HttpsError("failed-precondition", "Match is not active.");
    }

    if (action === "endTurn") {
      if (room.currentTurnUid !== uid) {
        throw new HttpsError("permission-denied", "Only the active player can end their turn.");
      }
      const nextUid = getOpponentUid(room, uid);
      tx.update(roomRef, {
        currentTurnUid: nextUid,
        turnDeadlineAt: computeNextDeadline(now, room.turnTimerSeconds),
        guessAttemptedThisTurn: false,
        pendingQuestionId: null,
        updatedAt: now,
      });
      return;
    }

    if (room.currentTurnUid === uid) {
      throw new HttpsError("permission-denied", "You cannot answer your own turn's question.");
    }
    if (requestId && (room.processedRequestIds ?? []).includes(requestId)) {
      throw new HttpsError("already-exists", "Duplicate answer submission ignored.");
    }

    let answeredQuestionId: string;
    try {
      answeredQuestionId = validateAnswerSubmission({
        pendingQuestionId: room.pendingQuestionId ?? null,
        lastAnsweredQuestionId: room.lastAnsweredQuestionId ?? null,
        requestedQuestionId,
      });
    } catch (e) {
      throw new HttpsError("failed-precondition", (e as Error).message);
    }

    const message = String(request.data?.message ?? "").trim();
    const messageType = String(request.data?.messageType ?? "customAnswer");
    if (!["yesAnswer", "noAnswer", "customAnswer"].includes(messageType)) {
      throw new HttpsError("invalid-argument", "Invalid answer type.");
    }
    if (!message || message.length > 300) {
      throw new HttpsError("invalid-argument", "Answer must be 1–300 characters.");
    }

    const updatedRequestIds = requestId
      ? [...(room.processedRequestIds ?? []).slice(-30), requestId]
      : room.processedRequestIds ?? [];

    const msgRef = db.collection(COL.messages).doc();
    tx.set(msgRef, {
      messageId: msgRef.id,
      roomId,
      questionId: answeredQuestionId,
      senderUid: uid,
      senderName: player.displayName,
      message,
      messageType,
      isRead: false,
      isDelivered: true,
      timestamp: now,
    });
    tx.update(roomRef, {
      pendingQuestionId: null,
      lastAnsweredQuestionId: answeredQuestionId,
      processedRequestIds: updatedRequestIds,
      updatedAt: now,
    });
  });

  return { ok: true };
});

// ============================================================================
// 8. submitFinalGuess (Transactional + Idempotent + Pack & Secret Validation)
// ============================================================================
export const submitFinalGuess = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  const guessedCardId = String(request.data?.guessedCardId ?? "").trim();
  const requestId = String(request.data?.requestId ?? "").trim();

  if (!roomId || !guessedCardId) {
    throw new HttpsError("invalid-argument", "roomId and guessedCardId are required.");
  }

  const roomRef = db.collection(COL.rooms).doc(roomId);
  const guesserRef = db.collection(COL.roomPlayers).doc(`${roomId}_${uid}`);

  let outcomePayload = {
    correct: false,
    heartsRemaining: STARTING_HEARTS,
    matchEnded: false,
    winnerUid: null as string | null,
  };

  await db.runTransaction(async (tx) => {
    const [roomSnap, guesserSnap] = await Promise.all([
      tx.get(roomRef),
      tx.get(guesserRef),
    ]);
    const room = roomSnap.data() as RoomDocument | undefined;
    const guesser = guesserSnap.data() as RoomPlayerDocument | undefined;
    if (!room || !guesser) throw new HttpsError("not-found", "Room not found.");

    const now = admin.firestore.Timestamp.now();
    assertMembership(room, uid);
    assertNotExpired(room, now);

    if (room.status !== "active") {
      throw new HttpsError("failed-precondition", "Match is not active.");
    }
    if (room.currentTurnUid !== uid) {
      throw new HttpsError("permission-denied", "It is not your turn to submit a final guess.");
    }
    if (requestId && (room.processedRequestIds ?? []).includes(requestId)) {
      throw new HttpsError("already-exists", "Duplicate guess submission ignored.");
    }
    if (room.guessAttemptedThisTurn) {
      throw new HttpsError("failed-precondition", "Only one final guess is allowed per turn.");
    }
    if (guesser.hearts <= 0) {
      throw new HttpsError("failed-precondition", "No hearts remaining.");
    }

    // Validate guessed card belongs to the active 10-card board (or selected pack)
    const validCardIds =
      room.boardCardIds && room.boardCardIds.length > 0
        ? new Set(room.boardCardIds)
        : await resolvePackCardIdsInTx(tx, room.category, room.boardPackId, uid);
    try {
      assertCardInValidPack(validCardIds, guessedCardId, "Final guess");
    } catch (e) {
      throw new HttpsError("invalid-argument", (e as Error).message);
    }

    // Prevent guessing your own assigned secret card
    const myPrivateSnap = await tx.get(
      db.collection(COL.privateSelections).doc(`${roomId}_${uid}`)
    );
    if (myPrivateSnap.data()?.secretCardId === guessedCardId) {
      throw new HttpsError(
        "invalid-argument",
        "You cannot guess your own secret card."
      );
    }

    const oppUid = getOpponentUid(room, uid);
    const oppPrivateSnap = await tx.get(
      db.collection(COL.privateSelections).doc(`${roomId}_${oppUid}`)
    );
    const opponentSecretCardId = oppPrivateSnap.data()?.secretCardId as string | undefined;
    if (!opponentSecretCardId) {
      throw new HttpsError("failed-precondition", "Opponent secret card missing.");
    }

    const evalRes = evaluateFinalGuess({
      guesserHearts: guesser.hearts,
      guessedCardId,
      opponentSecretCardId,
    });

    const updatedRequestIds = requestId
      ? [...(room.processedRequestIds ?? []).slice(-30), requestId]
      : room.processedRequestIds ?? [];

    const msgRef = db.collection(COL.messages).doc();
    tx.set(msgRef, {
      messageId: msgRef.id,
      roomId,
      senderUid: uid,
      senderName: guesser.displayName,
      message: evalRes.correct
        ? `Guessed the secret card correctly and WON!`
        : `Made a wrong final guess! (${evalRes.newHearts} hearts left)`,
      messageType: "guess",
      isRead: false,
      isDelivered: true,
      timestamp: now,
    });

    if (!evalRes.correct) {
      tx.update(guesserRef, {
        hearts: evalRes.newHearts,
        incorrectGuesses: admin.firestore.FieldValue.increment(1),
      });
    }

    if (evalRes.matchEnded) {
      const winnerUid = evalRes.guesserWon ? uid : oppUid;
      await finalizeMatchInTx(
        tx,
        roomRef,
        { ...room, processedRequestIds: updatedRequestIds },
        winnerUid,
        evalRes.winReason ?? "Match Completed",
        now
      );
      outcomePayload = {
        correct: evalRes.correct,
        heartsRemaining: evalRes.newHearts,
        matchEnded: true,
        winnerUid,
      };
    } else {
      tx.update(roomRef, {
        guessAttemptedThisTurn: true,
        processedRequestIds: updatedRequestIds,
        updatedAt: now,
      });
      outcomePayload = {
        correct: false,
        heartsRemaining: evalRes.newHearts,
        matchEnded: false,
        winnerUid: null,
      };
    }
  });

  return outcomePayload;
});

// ============================================================================
// 9. deductHeart (Server-verified turn-timer timeout ONLY; blocks client tampering)
// ============================================================================
export const deductHeart = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  if (!roomId) throw new HttpsError("invalid-argument", "roomId is required.");

  const roomRef = db.collection(COL.rooms).doc(roomId);
  let newHearts = 0;

  await db.runTransaction(async (tx) => {
    const roomSnap = await tx.get(roomRef);
    const room = roomSnap.data() as RoomDocument | undefined;
    if (!room) throw new HttpsError("not-found", "Room not found.");

    const now = admin.firestore.Timestamp.now();
    assertMembership(room, uid);
    assertNotExpired(room, now);

    if (room.status !== "active" || !room.currentTurnUid) {
      throw new HttpsError("failed-precondition", "Match is not active.");
    }

    const deadlineMs = room.turnDeadlineAt ? room.turnDeadlineAt.toMillis() : null;
    if (!isTurnTimerExpired(deadlineMs, now.toMillis())) {
      throw new HttpsError(
        "permission-denied",
        "Hearts cannot be manually deducted; turn timer has not expired."
      );
    }

    const activeUid = room.currentTurnUid;
    const activePlayerRef = db.collection(COL.roomPlayers).doc(`${roomId}_${activeUid}`);
    const playerSnap = await tx.get(activePlayerRef);
    const player = playerSnap.data() as RoomPlayerDocument | undefined;
    if (!player) throw new HttpsError("not-found", "Active player record missing.");

    newHearts = Math.max(0, player.hearts - 1);
    tx.update(activePlayerRef, { hearts: newHearts });

    const nextUid = getOpponentUid(room, activeUid);
    if (newHearts === 0) {
      await finalizeMatchInTx(tx, roomRef, room, nextUid, "Timed out with 0 hearts!", now);
    } else {
      tx.update(roomRef, {
        currentTurnUid: nextUid,
        turnDeadlineAt: computeNextDeadline(now, room.turnTimerSeconds),
        guessAttemptedThisTurn: false,
        pendingQuestionId: null,
        updatedAt: now,
      });
    }
  });

  return { heartsRemaining: newHearts };
});

// ============================================================================
// 10. completeMatch (Idempotent match finalizer)
// ============================================================================
async function finalizeMatchInTx(
  tx: admin.firestore.Transaction,
  roomRef: admin.firestore.DocumentReference,
  room: RoomDocument,
  winnerUid: string,
  winReason: string,
  now: admin.firestore.Timestamp
): Promise<void> {
  if (room.status === "completed") return;

  const loserUid = getOpponentUid(room, winnerUid);
  const [winnerSnap, loserSnap] = await Promise.all([
    tx.get(db.collection(COL.roomPlayers).doc(`${room.roomId}_${winnerUid}`)),
    tx.get(db.collection(COL.roomPlayers).doc(`${room.roomId}_${loserUid}`)),
  ]);
  const winnerPlayer = winnerSnap.data() as RoomPlayerDocument | undefined;
  const loserPlayer = loserSnap.data() as RoomPlayerDocument | undefined;

  tx.update(roomRef, {
    status: "completed",
    winnerUid,
    winReason,
    pendingQuestionId: null,
    turnDeadlineAt: null,
    processedRequestIds: room.processedRequestIds ?? [],
    updatedAt: now,
  });

  const historyRef = db.collection(COL.gameHistory).doc(room.roomId);
  const existingHistory = await tx.get(historyRef);
  if (!existingHistory.exists) {
    const duration = Math.max(
      1,
      Math.floor((now.toMillis() - room.createdAt.toMillis()) / 1000)
    );
    const historyDoc: GameHistoryDocument = {
      gameId: room.roomId,
      roomId: room.roomId,
      playerIds: [room.hostUid, room.guestUid ?? ""].filter(Boolean),
      winnerUid,
      loserUid,
      winnerHeartsRemaining: winnerPlayer?.hearts ?? 1,
      category: room.category,
      boardPackId: room.boardPackId,
      duration,
      questionsCount: room.questionsCount ?? 0,
      incorrectGuesses:
        (winnerPlayer?.incorrectGuesses ?? 0) + (loserPlayer?.incorrectGuesses ?? 0),
      winReason,
      completedAt: now,
    };
    tx.set(historyRef, historyDoc);
  }
}

export const completeMatch = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  const roomRef = db.collection(COL.rooms).doc(roomId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    const room = snap.data() as RoomDocument | undefined;
    if (!room) throw new HttpsError("not-found", "Room not found.");
    assertMembership(room, uid);
    if (room.status === "completed") return;

    const winnerUid = getOpponentUid(room, uid);
    await finalizeMatchInTx(
      tx,
      roomRef,
      room,
      winnerUid,
      "Opponent conceded the match.",
      admin.firestore.Timestamp.now()
    );
  });

  return { ok: true };
});

// ============================================================================
// 11. requestRematch
// ============================================================================
export const requestRematch = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId ?? "");
  const roomRef = db.collection(COL.rooms).doc(roomId);

  let restarted = false;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    const room = snap.data() as RoomDocument | undefined;
    if (!room) throw new HttpsError("not-found", "Room not found.");
    assertMembership(room, uid);
    if (room.status !== "completed") {
      throw new HttpsError("failed-precondition", "Rematch is available only after completion.");
    }

    const requested = new Set(room.rematchRequestedBy ?? []);
    requested.add(uid);
    const now = admin.firestore.Timestamp.now();

    if (room.guestUid && requested.has(room.hostUid) && requested.has(room.guestUid)) {
      restarted = true;
      const freshBoard = await generateRoomBoardInTx(
        tx,
        room.category,
        room.boardPackId,
        room.hostUid
      );
      const { hostSecretId, guestSecretId } = assignDistinctSecretCards(freshBoard);

      tx.update(roomRef, {
        status: "active",
        boardCardIds: freshBoard,
        winnerUid: null,
        winReason: null,
        currentTurnUid: room.hostUid,
        turnDeadlineAt: computeNextDeadline(now, room.turnTimerSeconds),
        guessAttemptedThisTurn: false,
        pendingQuestionId: null,
        lastAnsweredQuestionId: null,
        questionsCount: 0,
        rematchRequestedBy: [],
        processedRequestIds: [],
        updatedAt: now,
        expiresAt: admin.firestore.Timestamp.fromMillis(now.toMillis() + ROOM_EXPIRATION_MS),
      });

      tx.set(db.collection(COL.privateSelections).doc(`${roomId}_${room.hostUid}`), {
        roomId,
        playerUid: room.hostUid,
        secretCardId: hostSecretId,
        updatedAt: now,
      });
      tx.set(db.collection(COL.privateSelections).doc(`${roomId}_${room.guestUid}`), {
        roomId,
        playerUid: room.guestUid,
        secretCardId: guestSecretId,
        updatedAt: now,
      });

      for (const pUid of [room.hostUid, room.guestUid]) {
        tx.update(db.collection(COL.roomPlayers).doc(`${roomId}_${pUid}`), {
          hearts: STARTING_HEARTS,
          eliminatedCardIds: [],
          incorrectGuesses: 0,
          questionsAsked: 0,
          secretSubmitted: true,
          ready: true,
        });
      }
    } else {
      tx.update(roomRef, {
        rematchRequestedBy: Array.from(requested),
        updatedAt: now,
      });
    }
  });

  return { restarted };
});

// ============================================================================
// 12. cleanupExpiredRooms (Scheduled every 30 minutes)
// ============================================================================
export const cleanupExpiredRooms = onSchedule("every 30 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const expiredSnap = await db
    .collection(COL.rooms)
    .where("status", "in", ["waiting", "selectingSecrets"])
    .where("expiresAt", "<=", now)
    .limit(200)
    .get();

  if (expiredSnap.empty) return;
  const batch = db.batch();
  for (const doc of expiredSnap.docs) {
    batch.update(doc.ref, { status: "expired", updatedAt: now });
  }
  await batch.commit();
});

// ============================================================================
// 13. updatePlayerStatistics (Updates BOTH private users & publicProfiles)
// ============================================================================
export const updatePlayerStatistics = onDocumentCreated(
  `${COL.gameHistory}/{gameId}`,
  async (event) => {
    const history = event.data?.data() as GameHistoryDocument | undefined;
    if (!history) return;

    const updates: Array<{ uid: string; didWin: boolean; hearts: number }> = [
      {
        uid: history.winnerUid,
        didWin: true,
        hearts: history.winnerHeartsRemaining ?? 1,
      },
      {
        uid: history.loserUid,
        didWin: false,
        hearts: 0,
      },
    ];

    for (const item of updates) {
      if (!item.uid) continue;
      const userRef = db.collection(COL.users).doc(item.uid);
      const pubRef = db.collection(COL.publicProfiles).doc(item.uid);

      await db.runTransaction(async (tx) => {
        const [userSnap, pubSnap] = await Promise.all([tx.get(userRef), tx.get(pubRef)]);
        const current = userSnap.data() ?? pubSnap.data() ?? {};
        const nextStats = computeUpdatedPlayerStats(current, item.didWin, item.hearts);
        const now = admin.firestore.Timestamp.now();

        tx.set(userRef, { ...nextStats, updatedAt: now }, { merge: true });
        tx.set(
          pubRef,
          {
            uid: item.uid,
            username: (current.username as string) || "Desi Player",
            avatar: (current.avatar as string) || "avatar_1",
            rating: nextStats.rating,
            wins: nextStats.wins,
            losses: nextStats.losses,
            totalGames: nextStats.totalGames,
            bestWinStreak: nextStats.bestWinStreak,
            unlockedAchievements: nextStats.unlockedAchievements,
            updatedAt: now,
          },
          { merge: true }
        );
      });
    }
  }
);

// ============================================================================
// 14. shareCustomBoard (Toggle visibility, generate 6-char shareCode, or invite UID)
// ============================================================================
export const shareCustomBoard = onCall(async (request) => {
  const uid = requireAuth(request);
  const boardId = String(request.data?.boardId ?? "").trim();
  const visibility = String(request.data?.visibility ?? "shared") as BoardVisibility;
  const inviteUid =
    typeof request.data?.inviteUid === "string" ? request.data.inviteUid.trim() : null;

  if (!boardId || !["private", "shared"].includes(visibility)) {
    throw new HttpsError("invalid-argument", "Valid boardId and visibility are required.");
  }

  const boardRef = db.collection(COL.customBoards).doc(boardId);
  let shareCode: string | null = null;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(boardRef);
    const board = snap.data() as CustomBoardDocument | undefined;
    if (!board) throw new HttpsError("not-found", "Custom board not found.");
    if (board.ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Only the board owner can manage sharing.");
    }

    shareCode =
      visibility === "shared" ? board.shareCode || generateRoomCode() : null;
    const allowed = new Set(board.allowedPlayerUids ?? [uid]);
    allowed.add(uid);
    if (inviteUid && visibility === "shared") {
      allowed.add(inviteUid);
    }

    tx.update(boardRef, {
      visibility,
      shareCode,
      allowedPlayerUids: Array.from(allowed),
      updatedAt: admin.firestore.Timestamp.now(),
    });
  });

  return { boardId, visibility, shareCode };
});

// ============================================================================
// 15. joinCustomBoardByCode (Join a shared custom board using 6-char shareCode)
// ============================================================================
export const joinCustomBoardByCode = onCall(async (request) => {
  const uid = requireAuth(request);
  const code = String(request.data?.shareCode ?? "").trim().toUpperCase();
  if (!isValidRoomCode(code)) {
    throw new HttpsError("invalid-argument", "Enter a valid 6-character board share code.");
  }

  const query = await db
    .collection(COL.customBoards)
    .where("shareCode", "==", code)
    .where("visibility", "==", "shared")
    .limit(1)
    .get();

  if (query.empty) {
    throw new HttpsError("not-found", "No shared custom board found with that code.");
  }

  const boardRef = query.docs[0].ref;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(boardRef);
    const board = snap.data() as CustomBoardDocument | undefined;
    if (!board || board.visibility !== "shared") {
      throw new HttpsError("failed-precondition", "This board is no longer shared.");
    }
    tx.update(boardRef, {
      allowedPlayerUids: admin.firestore.FieldValue.arrayUnion(uid),
      updatedAt: admin.firestore.Timestamp.now(),
    });
  });

  return { boardId: boardRef.id };
});
