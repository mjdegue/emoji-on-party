import { useCallback, useEffect } from "react";
import { useWebSocket } from "./hooks/useWebSocket";
import { useGameStore } from "./store/gameStore";
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

export default function App() {
  const store = useGameStore();

  const handleMessage = useCallback(
    (type: string, payload: Record<string, unknown>, _from: string) => {
      const s = useGameStore.getState();

      switch (type) {
        case "__connected":
          s.setConnected(true);
          break;
        case "__disconnected":
          s.setConnected(false);
          break;
        case "join_confirmed": {
          const p = payload as unknown as JoinConfirmedPayload;
          s.setPlayerInfo(p.playerId, s.playerName, p.sessionState.sessionCode);
          s.setPlayers(p.sessionState.players);
          s.setPhase("lobby");
          break;
        }
        case "player_joined": {
          const p = payload as unknown as PlayerJoinedPayload;
          s.addPlayer({
            id: p.playerId,
            name: p.playerName,
            isCreator: false,
            isConnected: true,
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
            case "decoy_rounds":
              break;
            case "collecting_guesses":
              break;
            case "ended":
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
          break;
        }
        case "host_disconnected":
          s.setError("Host disconnected");
          s.setPhase("disconnected");
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
      return <WatchingScreen message="Look at the TV! Results are being revealed..." />;

    case "watching_scores":
      return <WatchingScreen message="Look at the TV! Scores are updating..." />;

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
