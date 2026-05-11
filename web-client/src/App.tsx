import { useCallback, useEffect, useRef } from "react";
import { useWebSocket } from "./hooks/useWebSocket";
import { useGameStore, type GamePhase } from "./store/gameStore";
import { JoinScreen } from "./screens/JoinScreen";
import { LobbyScreen } from "./screens/LobbyScreen";
import { DescribingScreen } from "./screens/DescribingScreen";
import { DecoyScreen } from "./screens/DecoyScreen";
import { GuessingScreen } from "./screens/GuessingScreen";
import { WatchingScreen } from "./screens/WatchingScreen";
import { ResultsScreen } from "./screens/ResultsScreen";
import type {
  JoinConfirmedPayload,
  PhraseAssignedPayload,
  PhaseChangedPayload,
  DecoyRoundStartedPayload,
  GuessingOptionsPayload,
  PlayerActionPayload,
  RoundRevealPayload,
  ScoreUpdatePayload,
  GameEndedPayload,
  PlayerJoinedPayload,
  PlayerDisconnectedPayload,
} from "./types/messages";

interface StateSyncPayload {
  phase: string;
  currentSubPhase: string;
  players: { id: string; name: string; isCreator: boolean; isConnected: boolean }[];
  sessionCode: string;
  myPhrase?: { id: string; text: string; category: string; difficulty: string };
  myEmojiSubmitted?: boolean;
  currentEmojiIndex?: number;
  totalEmojis?: number;
  targetPlayerId?: string;
  targetPlayerName?: string;
  targetEmoji?: string;
}

function saveSession(playerId: string, name: string, code: string) {
  sessionStorage.setItem("emoji-on-session", JSON.stringify({ playerId, name, code }));
}

function loadSession(): { playerId: string; name: string; code: string } | null {
  try {
    const raw = sessionStorage.getItem("emoji-on-session");
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function clearSession() {
  sessionStorage.removeItem("emoji-on-session");
}

const PHASE_MAP: Record<string, GamePhase> = {
  lobby: "lobby",
  dealing: "dealing",
  describing: "describing",
};

export default function App() {
  const store = useGameStore();
  const sendRef = useRef<(type: string, payload?: Record<string, unknown>) => void>(() => {});

  const handleMessage = useCallback(
    (type: string, payload: Record<string, unknown>, _from: string) => {
      const s = useGameStore.getState();

      switch (type) {
        case "__connected": {
          s.setConnected(true);
          // Attempt rejoin if we have a saved session
          const saved = loadSession();
          if (saved && saved.playerId && saved.code) {
            s.setPlayerInfo(saved.playerId, saved.name, saved.code);
            sendRef.current("player_rejoin", {
              code: saved.code,
              name: saved.name,
              playerId: saved.playerId,
            });
          }
          break;
        }
        case "__disconnected":
          s.setConnected(false);
          break;
        case "join_confirmed": {
          const p = payload as unknown as JoinConfirmedPayload;
          s.setPlayerInfo(p.playerId, s.playerName, p.sessionState.sessionCode, p.color);
          s.setPlayers(p.sessionState.players);
          s.setPhase("lobby");
          saveSession(p.playerId, s.playerName, p.sessionState.sessionCode);
          break;
        }
        case "state_sync": {
          const p = payload as unknown as StateSyncPayload;
          s.setPlayers(p.players);

          if (p.myPhrase) {
            s.setMyPhrase(p.myPhrase);
            if (p.myEmojiSubmitted) s.setEmojiSubmitted();
          }

          if (p.targetPlayerId && p.targetEmoji) {
            s.setDecoyRound({
              targetPlayerId: p.targetPlayerId,
              targetPlayerName: p.targetPlayerName || "",
              emojiSelection: p.targetEmoji,
              category: "",
              currentEmojiIndex: p.currentEmojiIndex || 0,
              totalEmojis: p.totalEmojis || 0,
            });
          }

          // Map server phase to client phase
          const subPhase = p.currentSubPhase;
          if (subPhase === "collecting_decoys") {
            s.setPhase("collecting_decoys");
          } else if (subPhase === "collecting_guesses") {
            s.setPhase("collecting_guesses");
          } else if (subPhase === "revealing" || subPhase === "final_scores") {
            s.setPhase("watching_reveal");
          } else if (PHASE_MAP[p.phase]) {
            s.setPhase(PHASE_MAP[p.phase]);
          } else {
            s.setPhase("lobby");
          }
          break;
        }
        case "player_joined": {
          const p = payload as unknown as PlayerJoinedPayload;
          s.addPlayer({
            id: p.playerId,
            name: p.playerName,
            isCreator: false,
            isConnected: true,
            color: p.color,
          });
          break;
        }
        case "player_disconnected": {
          const p = payload as unknown as PlayerDisconnectedPayload;
          s.removePlayer(p.playerId);
          break;
        }
        case "game_started":
          s.setPhase("dealing");
          break;
        case "phrase_assigned": {
          const p = payload as unknown as PhraseAssignedPayload;
          s.setMyPhrase(p.phrase);
          s.setPhase("describing");
          break;
        }
        case "phase_changed": {
          const p = payload as unknown as PhaseChangedPayload;
          switch (p.newPhase) {
            case "describing":
              s.setPhase("describing");
              break;
          }
          break;
        }
        case "decoy_round_started": {
          const p = payload as unknown as DecoyRoundStartedPayload;
          s.setDecoyRound(p);
          s.setPhase("collecting_decoys");
          break;
        }
        case "guessing_options": {
          const p = payload as unknown as GuessingOptionsPayload;
          s.setGuessingOptions(p.phrases);
          s.setPhase("collecting_guesses");
          break;
        }
        case "player_action": {
          const p = payload as unknown as PlayerActionPayload;
          s.setSubmissionProgress(p.submittedCount, p.expectedCount);
          break;
        }
        case "round_reveal": {
          const p = payload as unknown as RoundRevealPayload;
          s.setReveal(p.emojiSelection, p.userName, p.phrases);
          s.setPhase("watching_reveal");
          break;
        }
        case "score_update": {
          const p = payload as unknown as ScoreUpdatePayload;
          s.setScores(p.playerScores, p.isLastEmoji);
          s.setPhase("watching_scores");
          break;
        }
        case "game_ended": {
          const p = payload as unknown as GameEndedPayload;
          s.setFinalRankings(p.finalRankings);
          s.setPhase("ended");
          clearSession();
          break;
        }
        case "host_disconnected":
          s.setError("Host disconnected");
          s.setPhase("disconnected");
          clearSession();
          break;
        case "error": {
          const msg = (payload as { message?: string }).message || "Unknown error";
          s.setError(msg);
          break;
        }
      }
    },
    []
  );

  const { connect, send } = useWebSocket(handleMessage);
  sendRef.current = send;

  useEffect(() => {
    connect();
  }, [connect]);

  const handleJoin = (code: string, name: string) => {
    useGameStore.getState().setPlayerInfo("", name, code);
    send("player_join", { code, name });
  };

  const handleSubmitEmoji = (emojiString: string) => {
    send("submit_emoji", { emojiString });
    store.setEmojiSubmitted();
  };

  const handleSubmitDecoy = (decoyText: string) => {
    send("submit_decoy", { decoyText });
    store.setDecoySubmitted();
  };

  const handleSubmitGuess = (optionId: number) => {
    send("submit_guess", { selectedOptionId: optionId });
    store.setGuessSubmitted();
  };

  const isAuthor = store.targetPlayerId === store.playerId;

  switch (store.phase) {
    case "disconnected":
      return (
        <div className="screen">
          <h2>Connecting...</h2>
          {store.error && <p className="error">{store.error}</p>}
        </div>
      );

    case "join":
      return <JoinScreen onJoin={handleJoin} error={store.error} />;

    case "lobby":
      return (
        <LobbyScreen
          sessionCode={store.sessionCode}
          players={store.players}
          playerName={store.playerName}
        />
      );

    case "dealing":
      return <WatchingScreen message="Dealing phrases..." />;

    case "describing":
      return store.myPhrase ? (
        <DescribingScreen
          phrase={store.myPhrase}
          submitted={store.myEmojiSubmitted}
          onSubmit={handleSubmitEmoji}
        />
      ) : (
        <WatchingScreen message="Waiting for your phrase..." />
      );

    case "collecting_decoys":
      return (
        <DecoyScreen
          targetPlayerName={store.targetPlayerName}
          emoji={store.targetEmoji}
          category={store.targetCategory}
          currentIndex={store.currentEmojiIndex}
          totalEmojis={store.totalEmojis}
          submitted={store.myDecoySubmitted}
          submittedCount={store.submittedCount}
          expectedCount={store.expectedCount}
          isAuthor={isAuthor}
          onSubmit={handleSubmitDecoy}
        />
      );

    case "collecting_guesses":
      return (
        <GuessingScreen
          targetPlayerName={store.targetPlayerName}
          emoji={store.targetEmoji}
          options={store.guessingOptions}
          currentIndex={store.currentEmojiIndex}
          totalEmojis={store.totalEmojis}
          submitted={store.myGuessSubmitted}
          submittedCount={store.submittedCount}
          expectedCount={store.expectedCount}
          isAuthor={isAuthor}
          onSubmit={handleSubmitGuess}
        />
      );

    case "watching_reveal":
      return <WatchingScreen message="Look at the TV! The real answer is being revealed..." />;

    case "watching_scores":
      return <WatchingScreen message="Look at the TV! Final scores are up!" />;

    case "ended":
      return (
        <ResultsScreen
          rankings={store.finalRankings}
          playerName={store.playerName}
        />
      );

    default:
      return <WatchingScreen />;
  }
}
