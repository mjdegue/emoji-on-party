interface Props {
  message?: string;
}

export function WatchingScreen({ message }: Props) {
  return (
    <div className="screen watching-screen">
      <h2>Look at the screen!</h2>
      <p className="subtitle">{message || "The results are being revealed on the TV..."}</p>
    </div>
  );
}
