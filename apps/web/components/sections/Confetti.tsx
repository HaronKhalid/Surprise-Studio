const PIECES = 26;

/**
 * Decorative falling confetti, pure CSS. Positions are derived from the index (not Math.random) so
 * the server and client render identical markup. Hidden for visitors who prefer reduced motion.
 */
export function Confetti() {
  return (
    <div className="confetti" aria-hidden="true">
      {Array.from({ length: PIECES }, (_, i) => (
        <span
          key={i}
          style={{
            left: `${(i * 37 + 11) % 100}%`,
            animationDelay: `${((i * 53) % 40) / 10}s`,
            animationDuration: `${4 + (i % 5)}s`,
            // Tints of the accent only, so it stays festive on any background instead of mixing in dark text
            background:
              i % 3 === 0
                ? 'var(--accent)'
                : i % 3 === 1
                  ? 'color-mix(in srgb, var(--accent) 40%, var(--bg))'
                  : 'color-mix(in srgb, var(--accent) 70%, white)',
            transform: `rotate(${(i * 47) % 360}deg)`,
          }}
        />
      ))}
    </div>
  );
}
