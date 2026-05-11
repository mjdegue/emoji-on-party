import type { PlayerInfo } from "../types/messages";

interface Props {
  sessionCode: string;
  players: PlayerInfo[];
  playerName: string;
}

export function LobbyScreen({ sessionCode, players, playerName }: Props) {
  return (
    <div className="screen lobby-screen">
      <h1>Lobby</h1>
      <p className="session-code">Code: <strong>{sessionCode}</strong></p>
      <p className="subtitle">Waiting for host to start...</p>

      <div className="player-list">
        <h2>Players ({players.length})</h2>
        {players.map((p) => (
          <div
            key={p.id}
            className={`player-item ${!p.isConnected ? "disconnected" : ""}`}
          >
            <span className="player-name">
              {p.name}
              {p.name === playerName && " (you)"}
            </span>
            {p.isCreator && <span className="badge">HOST</span>}
            {!p.isConnected && <span className="badge offline">OFFLINE</span>}
          </div>
        ))}
      </div>
    </div>
  );
}
