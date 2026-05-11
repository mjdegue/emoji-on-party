// --- Relay-level messages ---

export interface RelayMessage {
  type: string;
  payload?: Record<string, unknown>;
  from?: string;
  to?: string;
}

// --- Incoming from host ---

export interface JoinConfirmedPayload {
  playerId: string;
  colorIndex: number;
  color: string;
  sessionState: {
    phase: string;
    players: PlayerInfo[];
    sessionCode: string;
  };
}

export interface PlayerInfo {
  id: string;
  name: string;
  isCreator: boolean;
  color?: string;
  isConnected: boolean;
}

export interface PhraseAssignedPayload {
  phrase: Phrase;
}

export interface Phrase {
  id: string;
  text: string;
  category: string;
  difficulty: string;
}

export interface PhaseChangedPayload {
  previousPhase: string;
  newPhase: string;
}

export interface DecoyRoundStartedPayload {
  targetPlayerId: string;
  targetPlayerName: string;
  emojiSelection: string;
  category: string;
  currentEmojiIndex: number;
  totalEmojis: number;
}

export interface GuessingOptionsPayload {
  targetPlayerId: string;
  targetPlayerName: string;
  emojiSelection: string;
  phrases: GuessingOption[];
  currentEmojiIndex: number;
  totalEmojis: number;
}

export interface GuessingOption {
  text: string;
  optionId: number;
}

export interface PlayerActionPayload {
  action: string;
  playerId: string;
  submittedCount: number;
  expectedCount: number;
}

export interface RevealPhrase {
  phrase: string;
  user: string;
  userName: string;
  selectedBy: string[];
  isReal: boolean;
  selectionCount: number;
}

export interface RoundRevealPayload {
  emojiSelection: string;
  user: string;
  userName: string;
  phrases: RevealPhrase[];
  currentEmojiIndex: number;
  totalEmojis: number;
}

export interface ScoreBreakdown {
  correctGuesses: number;
  fooledPlayers: number;
  clarityBonus: number;
}

export interface PlayerScoreEntry {
  playerId: string;
  playerName: string;
  preRoundScore: number;
  postRoundScore: number;
  pointsEarned: number;
  breakdown: ScoreBreakdown;
}

export interface ScoreUpdatePayload {
  roundNumber: number;
  totalEmojis: number;
  isLastEmoji: boolean;
  playerScores: PlayerScoreEntry[];
}

export interface FinalRanking {
  playerId: string;
  playerName: string;
  totalScore: number;
  position: number;
}

export interface GameEndedPayload {
  finalRankings: FinalRanking[];
  gameStats: Record<string, unknown>;
}

export interface PlayerJoinedPayload {
  playerId: string;
  playerName: string;
  color?: string;
}

export interface PlayerDisconnectedPayload {
  playerId: string;
}
