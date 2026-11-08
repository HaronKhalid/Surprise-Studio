import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Surprise not available',
  robots: { index: false, follow: false },
};

export default function NotFound() {
  return (
    <main className="notice">
      <h1>This surprise isn&rsquo;t available</h1>
      <p>The link may have a typo, or the person who made it has taken it down.</p>
      <a className="notice-link" href="/">
        Go to Surprise Studio
      </a>
    </main>
  );
}
