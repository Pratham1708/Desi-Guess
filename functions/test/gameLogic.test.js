const test = require("node:test");
const assert = require("node:assert/strict");
const {
  STARTING_HEARTS,
  RANDOM_BOARD_SIZE,
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
} = require("../lib/gameLogic");
const { BUILT_IN_PACK_CARDS, isBuiltInCardInPack } = require("../lib/packCatalog");

test("generateRoomCode produces valid 6-char uppercase codes", () => {
  for (let i = 0; i < 20; i++) {
    const code = generateRoomCode();
    assert.equal(code.length, 6);
    assert.equal(isValidRoomCode(code), true);
  }
});

test("generateBalancedRandomBoard builds 10 unique cards and assignDistinctSecretCards returns 2 different IDs", () => {
  const whoSubs = {};
  for (const [packId, set] of Object.entries(BUILT_IN_PACK_CARDS)) {
    if (packId.startsWith("who_")) whoSubs[packId] = set;
  }
  const board = generateBalancedRandomBoard(whoSubs, RANDOM_BOARD_SIZE);
  assert.equal(board.length, 10);
  assert.equal(new Set(board).size, 10);

  const { hostSecretId, guestSecretId } = assignDistinctSecretCards(board);
  assert.notEqual(hostSecretId, guestSecretId);
  assert.ok(board.includes(hostSecretId));
  assert.ok(board.includes(guestSecretId));
});

test("server pack catalog includes all 24 built-in packs and rejects foreign card IDs", () => {
  assert.equal(Object.keys(BUILT_IN_PACK_CARDS).length, 24);
  assert.equal(isBuiltInCardInPack("who_indian_cricketers", "cr_01"), true);
  assert.equal(isBuiltInCardInPack("who_indian_cricketers", "fd_01"), false);

  assert.throws(
    () => assertCardInValidPack(BUILT_IN_PACK_CARDS.who_indian_cricketers, "invalid_id", "Secret"),
    /does not belong/
  );
});

test("validateAnswerSubmission rejects answers without pending question and duplicate answers", () => {
  assert.throws(
    () =>
      validateAnswerSubmission({
        pendingQuestionId: null,
        lastAnsweredQuestionId: null,
      }),
    /no pending question/
  );

  assert.throws(
    () =>
      validateAnswerSubmission({
        pendingQuestionId: "q_1",
        lastAnsweredQuestionId: "q_1",
      }),
    /already been answered/
  );

  const ok = validateAnswerSubmission({
    pendingQuestionId: "q_2",
    lastAnsweredQuestionId: "q_1",
    requestedQuestionId: "q_2",
  });
  assert.equal(ok, "q_2");
});

test("canAccessCustomBoard enforces private vs shared board permissions", () => {
  const privateBoard = { ownerUid: "u1", visibility: "private", allowedPlayerUids: ["u1"] };
  assert.equal(canAccessCustomBoard(privateBoard, "u1"), true);
  assert.equal(canAccessCustomBoard(privateBoard, "u2"), false);

  const sharedBoard = { ownerUid: "u1", visibility: "shared", allowedPlayerUids: ["u1", "u2"] };
  assert.equal(canAccessCustomBoard(sharedBoard, "u2"), true);
  assert.equal(canAccessCustomBoard(sharedBoard, "u3"), false);
});

test("isTurnTimerExpired prevents premature heart deduction", () => {
  assert.equal(isTurnTimerExpired(null, 1000), false);
  assert.equal(isTurnTimerExpired(2000, 1500), false);
  assert.equal(isTurnTimerExpired(2000, 2000), true);
});

test("evaluateFinalGuess wins immediately on correct card", () => {
  const res = evaluateFinalGuess({
    guesserHearts: STARTING_HEARTS,
    guessedCardId: "cr_01",
    opponentSecretCardId: "cr_01",
  });
  assert.equal(res.correct, true);
  assert.equal(res.matchEnded, true);
  assert.equal(res.guesserWon, true);
  assert.equal(res.newHearts, 5);
});

test("evaluateFinalGuess deducts 1 heart on wrong guess without ending above 0", () => {
  const res = evaluateFinalGuess({
    guesserHearts: 5,
    guessedCardId: "cr_02",
    opponentSecretCardId: "cr_01",
  });
  assert.equal(res.correct, false);
  assert.equal(res.newHearts, 4);
  assert.equal(res.matchEnded, false);
});

test("evaluateFinalGuess ends match on 5th wrong guess (0 hearts)", () => {
  const res = evaluateFinalGuess({
    guesserHearts: 1,
    guessedCardId: "cr_02",
    opponentSecretCardId: "cr_01",
  });
  assert.equal(res.correct, false);
  assert.equal(res.newHearts, 0);
  assert.equal(res.matchEnded, true);
  assert.equal(res.guesserWon, false);
});

test("computeUpdatedPlayerStats unlocks achievements & updates rating", () => {
  let stats = computeUpdatedPlayerStats({}, true, 5);
  assert.equal(stats.wins, 1);
  assert.equal(stats.rating, 1025);
  assert.ok(stats.unlockedAchievements.includes("first_victory"));
  assert.ok(stats.unlockedAchievements.includes("perfect_guess"));

  stats = computeUpdatedPlayerStats(stats, true, 1);
  assert.ok(stats.unlockedAchievements.includes("comeback_king"));
});
