'use client';

/** Shown when the API is unreachable or broken. Distinct from not-found: the surprise may well exist. */
export default function ErrorPage({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main className="notice">
      <h1>Something went wrong</h1>
      <p>We couldn&rsquo;t load this page just now. Please try again in a moment.</p>
      <button type="button" className="notice-link" onClick={reset}>
        Try again
      </button>
    </main>
  );
}
