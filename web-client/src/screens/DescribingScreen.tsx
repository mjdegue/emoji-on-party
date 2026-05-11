import { useState } from "react";
import type { Phrase } from "../types/messages";

interface Props {
  phrase: Phrase;
  submitted: boolean;
  onSubmit: (emojiString: string) => void;
}

export function DescribingScreen({ phrase, submitted, onSubmit }: Props) {
  const [emoji, setEmoji] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (emoji.trim()) {
      onSubmit(emoji.trim());
    }
  };

  if (submitted) {
    return (
      <div className="screen describing-screen">
        <h2>Submitted!</h2>
        <p className="subtitle">Waiting for other players...</p>
      </div>
    );
  }

  return (
    <div className="screen describing-screen">
      <h2>Describe with emojis</h2>
      <div className="phrase-card">
        <span className="phrase-category">{phrase.category}</span>
        <span className="phrase-text">{phrase.text}</span>
        <span className="phrase-difficulty">{phrase.difficulty}</span>
      </div>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="Type emojis here..."
          value={emoji}
          onChange={(e) => setEmoji(e.target.value)}
          className="input-emoji"
          autoFocus
        />
        <p className="hint">Use your emoji keyboard to describe the phrase</p>
        <button
          type="submit"
          disabled={!emoji.trim()}
          className="btn-primary"
        >
          Submit Emojis
        </button>
      </form>
    </div>
  );
}
