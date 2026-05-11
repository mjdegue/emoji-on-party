import { create } from "zustand";
import type {
  PlayerInfo,
  Phrase,
  GuessingOption,
  RevealPhrase,
  PlayerScoreEntry,
  FinalRanking,
} from "../types/messages";

export type GamePhase =
  | "disconnected"
  | "join"
  | "lobby"
  | "dealing"
  | "describing"
  | "collecting_decoys"
  | "collecting_guesses"
  | "watching_reveal"
  | "watching_scores"
  | "ended";

export interface GameState {
  // Connection
  connected: boolean;

  // Player identity
  playerId: string;
  playerName: string;
  sessionCode: string;
  myColor: string;

  // Game
  phase: GamePhase;
  players: PlayerInfo[];

  // Assignment
  myPhrase: Phrase | null;
  myEmojiSubmitted: boolean;

  // Decoy round
  targetPlayerId: string;
  targetPlayerName: string;
  targetEmoji: string;
  targetCategory: string;
  currentEmojiIndex: number;
  totalEmojis: number;
  myDecoySubmitted: boolean;

  // Guessing
  guessingOptions: GuessingOption[];
  myGuessSubmitted: boolean;

  // Submission progress
  submittedCount: number;
  expectedCount: number;

  // Reveal
  revealPhrases: RevealPhrase[];
  revealEmoji: string;
  revealUserName: string;

  // Scores
  playerScores: PlayerScoreEntry[];
  isLastEmoji: boolean;

  // Final
  finalRankings: FinalRanking[];

  // Error
  error: string;
}

export interface GameActions {
  setConnected: (connected: boolean) => void;
  setPlayerInfo: (playerId: string, playerName: string, sessionCode: string, color?: string) => void;
  setPhase: (phase: GamePhase) => void;
  setPlayers: (players: PlayerInfo[]) => void;
  addPlayer: (player: PlayerInfo) => void;
  removePlayer: (playerId: string) => void;
  setMyPhrase: (phrase: Phrase) => void;
  setDecoyRound: (data: {
    targetPlayerId: string;
    targetPlayerName: string;
    emojiSelection: string;
    category: string;
    currentEmojiIndex: number;
    totalEmojis: number;
  }) => void;
  setGuessingOptions: (options: GuessingOption[]) => void;
  setSubmissionProgress: (submitted: number, expected: number) => void;
  setReveal: (emoji: string, userName: string, phrases: RevealPhrase[]) => void;
  setScores: (scores: PlayerScoreEntry[], isLast: boolean) => void;
  setFinalRankings: (rankings: FinalRanking[]) => void;
  setEmojiSubmitted: () => void;
  setDecoySubmitted: () => void;
  setGuessSubmitted: () => void;
  setError: (error: string) => void;
  reset: () => void;
}

const initialState: GameState = {
  connected: false,
  playerId: "",
  playerName: "",
  sessionCode: "",
  myColor: "",
  phase: "disconnected",
  players: [],
  myPhrase: null,
  myEmojiSubmitted: false,
  targetPlayerId: "",
  targetPlayerName: "",
  targetEmoji: "",
  targetCategory: "",
  currentEmojiIndex: 0,
  totalEmojis: 0,
  myDecoySubmitted: false,
  guessingOptions: [],
  myGuessSubmitted: false,
  submittedCount: 0,
  expectedCount: 0,
  revealPhrases: [],
  revealEmoji: "",
  revealUserName: "",
  playerScores: [],
  isLastEmoji: false,
  finalRankings: [],
  error: "",
};

export const useGameStore = create<GameState & GameActions>()((set) => ({
  ...initialState,

  setConnected: (connected) =>
    set({ connected, phase: connected ? "join" : "disconnected", error: "" }),

  setPlayerInfo: (playerId, playerName, sessionCode, color) =>
    set({ playerId, playerName, sessionCode, myColor: color || "" }),

  setPhase: (phase) =>
    set({
      phase,
      error: "",
      // Reset submission flags on phase transitions
      myDecoySubmitted: false,
      myGuessSubmitted: false,
      submittedCount: 0,
      expectedCount: 0,
    }),

  setPlayers: (players) => set({ players }),

  addPlayer: (player) =>
    set((s) => ({
      players: s.players.some((p) => p.id === player.id)
        ? s.players
        : [...s.players, player],
    })),

  removePlayer: (playerId) =>
    set((s) => ({
      players: s.players.map((p) =>
        p.id === playerId ? { ...p, isConnected: false } : p
      ),
    })),

  setMyPhrase: (phrase) => set({ myPhrase: phrase, myEmojiSubmitted: false }),

  setDecoyRound: (data) =>
    set({
      targetPlayerId: data.targetPlayerId,
      targetPlayerName: data.targetPlayerName,
      targetEmoji: data.emojiSelection,
      targetCategory: data.category,
      currentEmojiIndex: data.currentEmojiIndex,
      totalEmojis: data.totalEmojis,
      myDecoySubmitted: false,
      myGuessSubmitted: false,
      submittedCount: 0,
      expectedCount: 0,
    }),

  setGuessingOptions: (options) =>
    set({ guessingOptions: options, myGuessSubmitted: false }),

  setSubmissionProgress: (submitted, expected) =>
    set({ submittedCount: submitted, expectedCount: expected }),

  setReveal: (emoji, userName, phrases) =>
    set({ revealEmoji: emoji, revealUserName: userName, revealPhrases: phrases }),

  setScores: (scores, isLast) =>
    set({ playerScores: scores, isLastEmoji: isLast }),

  setFinalRankings: (rankings) => set({ finalRankings: rankings }),

  setEmojiSubmitted: () => set({ myEmojiSubmitted: true }),
  setDecoySubmitted: () => set({ myDecoySubmitted: true }),
  setGuessSubmitted: () => set({ myGuessSubmitted: true }),

  setError: (error) => set({ error }),

  reset: () => set(initialState),
}));
