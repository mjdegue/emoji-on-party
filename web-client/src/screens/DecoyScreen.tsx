import { useState } from "react";

interface Props {
  targetPlayerName: string;
  emoji: string;
  category: string;
  currentIndex: number;
  totalEmojis: number;
  submitted: boolean;
  submittedCount: number;
  expectedCount: number;
  isAuthor: boolean;
  onSubmit: (decoyText: string) => void;
}

export function DecoyScreen({
  targetPlayerName,
  emoji,
  category,
  currentIndex,
  totalEmojis,
  submitted,
  submittedCount,
  expectedCount,
  isAuthor,
  onSubmit,
}: Props) {
  const [decoy, setDecoy] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const text = decoy.trim();
    if (text.length >= 3 && text.length <= 50) {
      onSubmit(text);
    }
  };

  if (isAuthor) {
    return (
      <div className="screen decoy-screen">
        <div className="progress-badge">{currentIndex + 1} / {totalEmojis}</div>
        <h2>Your emoji is up!</h2>
        <div className="emoji-display">{emoji}</div>
        <p className="subtitle">Other players are writing fake answers...</p>
        <div className="progress-bar">
          <div
            className="progress-fill"
            style={{ width: `${expectedCount > 0 ? (submittedCount / expectedCount) * 100 : 0}%` }}
          />
        </div>
        <p className="progress-text">{submittedCount} / {expectedCount} submitted</p>
      </div>
    );
  }

  if (submitted) {
    return (
      <div className="screen decoy-screen">
        <div className="progress-badge">{currentIndex + 1} / {totalEmojis}</div>
        <h2>Submitted!</h2>
        <div className="emoji-display">{emoji}</div>
        <p className="subtitle">Waiting for other players...</p>
        <div className="progress-bar">
          <div
            className="progress-fill"
            style={{ width: `${expectedCount > 0 ? (submittedCount / expectedCount) * 100 : 0}%` }}
          />
        </div>
        <p className="progress-text">{submittedCount} / {expectedCount} submitted</p>
      </div>
    );
  }

  return (
    <div className="screen decoy-screen">
      <div className="progress-badge">{currentIndex + 1} / {totalEmojis}</div>
      <h2>Write a fake answer</h2>
      <p className="subtitle">{targetPlayerName}'s emoji ({category}):</p>
      <div className="emoji-display">{emoji}</div>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="Write a convincing fake phrase..."
          value={decoy}
          onChange={(e) => setDecoy(e.target.value)}
          maxLength={50}
          autoFocus
          className="input-decoy"
        />
        <p className="hint">{decoy.length}/50 characters (min 3)</p>
        <button
          type="submit"
          disabled={decoy.trim().length < 3}
          className="btn-primary"
        >
          Submit
        </button>
      </form>
    </div>
  );
}
