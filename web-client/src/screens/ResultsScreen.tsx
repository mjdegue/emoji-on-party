import type { FinalRanking } from "../types/messages";

interface Props {
  rankings: FinalRanking[];
  playerName: string;
}

export function ResultsScreen({ rankings, playerName }: Props) {
  return (
    <div className="screen results-screen">
      <h1>Game Over!</h1>
      <div className="rankings">
        {rankings.map((r) => (
          <div
            key={r.playerId}
            className={`ranking-item ${r.playerName === playerName ? "is-me" : ""}`}
          >
            <span className="position">#{r.position}</span>
            <span className="ranking-name">
              {r.playerName}
              {r.playerName === playerName && " (you)"}
            </span>
            <span className="score">{r.totalScore} pts</span>
          </div>
        ))}
      </div>
    </div>
  );
}
