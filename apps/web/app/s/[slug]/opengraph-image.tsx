import { ImageResponse } from 'next/og';
import { getSurprise } from '@/lib/api';

export const alt = 'A surprise is waiting';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';
export const dynamic = 'force-dynamic';

/**
 * Social preview card. Uses the surprise's own colours but shows no name, photo or message:
 * the default image font has no Arabic/Urdu glyphs (a recipient's name could render as boxes),
 * and previews are scraped by third parties. The name appears in the page title instead.
 */
export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  let { bg, fg, accent } = { bg: '#0b1020', fg: '#ffffff', accent: '#d4af37' };
  try {
    const s = await getSurprise(slug);
    if (s) ({ background: bg, text: fg, accent } = s.theme.colors);
  } catch {
    // Fall back to the defaults: a preview image is not worth failing over.
  }

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          background: bg,
          color: fg,
          fontSize: 76,
        }}
      >
        <div style={{ display: 'flex', width: 120, height: 120, borderRadius: 60, background: accent, marginBottom: 48 }} />
        <div style={{ display: 'flex' }}>A surprise is waiting</div>
        <div style={{ display: 'flex', fontSize: 34, color: accent, marginTop: 28, letterSpacing: 6 }}>SURPRISE STUDIO</div>
      </div>
    ),
    { ...size },
  );
}
