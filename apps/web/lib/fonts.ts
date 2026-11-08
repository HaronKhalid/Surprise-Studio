import { Cormorant_Garamond, DM_Serif_Display, Inter, Playfair_Display, Poppins } from 'next/font/google';

// next/font needs literal options (no spreads or shared variables) so it can fetch and self-host the
// files at build time. `preload: false`: all five are declared but only the one a surprise uses is
// ever downloaded, so they should not all be preloaded on every page.
const playfair = Playfair_Display({ subsets: ['latin'], display: 'swap', preload: false, variable: '--font-playfair' });
const cormorant = Cormorant_Garamond({
  subsets: ['latin'],
  weight: ['300', '400', '600'],
  display: 'swap',
  preload: false,
  variable: '--font-cormorant',
});
const dmSerif = DM_Serif_Display({ subsets: ['latin'], weight: '400', display: 'swap', preload: false, variable: '--font-dm-serif' });
const inter = Inter({ subsets: ['latin'], display: 'swap', preload: false, variable: '--font-inter' });
const poppins = Poppins({
  subsets: ['latin'],
  weight: ['400', '600', '700'],
  display: 'swap',
  preload: false,
  variable: '--font-poppins',
});

/** Defines every font CSS variable; the theme then picks one with --font. */
export const fontVariableClasses = [playfair, cormorant, dmSerif, inter, poppins].map((f) => f.variable).join(' ');

/** Theme font key (from the API's fixed list) to its CSS variable. Unknown keys fall back safely. */
const FONT_VAR: Record<string, string> = {
  playfair: 'var(--font-playfair)',
  cormorant: 'var(--font-cormorant)',
  'dm-serif': 'var(--font-dm-serif)',
  inter: 'var(--font-inter)',
  poppins: 'var(--font-poppins)',
};
export const fontFamily = (key: string) => `${FONT_VAR[key] ?? FONT_VAR.inter}, Georgia, 'Times New Roman', serif`;
