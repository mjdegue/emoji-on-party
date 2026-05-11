import { useState } from "react";
import type { GuessingOption } from "../types/messages";

interface Props {
  targetPlayerName: string;
  emoji: string;
  options: GuessingOption[];
  currentIndex: number;
  totalEmojis: number;
  submitted: boolean;
  submittedCount: number;
  expectedCount: number;
  isAuthor: boolean;
  onSubmit: (optionId: number) => void;
}

export function GuessingScreen({
  targetPlayerName,
  emoji,
  options,
  currentIndex,
  totalEmojis,
  submitted,
  submittedCount,
  expectedCount,
  isAuthor,
  onSubmit,
}: Props) {
  const [selected, setSelected] = useState<number | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (selected !== null) {
      onSubmit(selected);
    }
  };

  if (isAuthor) {
    return (
      <div className="screen guessing-screen">
        <div className="progress-badge">{currentIndex + 1} / {totalEmojis}</div>
        <h2>Your emoji is being guessed!</h2>
        <div className="emoji-display">{emoji}</div>
        <p className="subtitle">Players are picking the real answer...</p>
        <div className="progress-bar">
          <div
            className="progress-fill"
            style={{ width: `${expectedCount > 0 ? (submittedCount / expectedCount) * 100 : 0}%` }}
          />
        </div>
        <p className="progress-text">{submittedCount} / {expectedCount} guessed</p>
      </div>
    );
  }

  if (submitted) {
    return (
      <div className="screen guessing-screen">
        <div className="progress-badge">{currentIndex + 1} / {totalEmojis}</div>
        <h2>Guess submitted!</h2>
        <div className="emoji-display">{emoji}</div>
        <p className="subtitle">Waiting for other players...</p>
        <div className="progress-bar">
          <div
            className="progress-fill"
            style={{ width: `${expectedCount > 0 ? (submittedCount / expectedCount) * 100 : 0}%` }}
          />
        </div>
        <p className="progress-text">{submittedCount} / {expectedCount} guessed</p>
      </div>
    );
  }

  return (
    <div className="screen guessing-screen">
      <div className="progress-badge">{currentIndex + 1} / {totalEmojis}</div>
      <h2>Which is the real phrase?</h2>
      <p className="subtitle">{targetPlayerName}'s emoji:</p>
      <div className="emoji-display">{emoji}</div>
      <form onSubmit={handleSubmit}>
        <div className="options-list">
          {options.map((opt) => (
            <label
              key={opt.optionId}
              className={`option ${selected === opt.optionId ? "selected" : ""}`}
            >
              <input
                type="radio"
                name="guess"
                value={opt.optionId}
                checked={selected === opt.optionId}
                onChange={() => setSelected(opt.optionId)}
              />
              <span>{opt.text}</span>
            </label>
          ))}
        </div>
        <button
          type="submit"
          disabled={selected === null}
          className="btn-primary"
        >
          Lock In Guess
        </button>
      </form>
    </div>
  );
}
