import { useState } from "react";

interface Props {
  onJoin: (code: string, name: string) => void;
  error: string;
}

export function JoinScreen({ onJoin, error }: Props) {
  const [code, setCode] = useState("");
  const [name, setName] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (code.trim() && name.trim()) {
      onJoin(code.trim().toUpperCase(), name.trim());
    }
  };

  return (
    <div className="screen join-screen">
      <h1>Emoji-On</h1>
      <p className="subtitle">Enter the code shown on the TV</p>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="Game Code"
          value={code}
          onChange={(e) => setCode(e.target.value.toUpperCase())}
          maxLength={6}
          autoFocus
          className="input-code"
        />
        <input
          type="text"
          placeholder="Your Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          maxLength={20}
          className="input-name"
        />
        <button
          type="submit"
          disabled={!code.trim() || !name.trim()}
          className="btn-primary"
        >
          Join Game
        </button>
      </form>
      {error && <p className="error">{error}</p>}
    </div>
  );
}
