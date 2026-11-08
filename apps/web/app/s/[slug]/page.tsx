import type { Metadata, Viewport } from 'next';
import { notFound } from 'next/navigation';
import { Experience } from '@/components/Experience';
import { getSurprise } from '@/lib/api';
import { displayName, occasionTitle } from '@/lib/text';

interface Props {
  params: Promise<{ slug: string }>;
}

// Never cached: unpublishing or deleting must take effect immediately.
export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const surprise = await getSurprise(slug).catch(() => null);
  const noIndex = { index: false, follow: false };
  if (!surprise) return { title: 'Surprise not available', robots: noIndex };

  const name = displayName(surprise);
  const title = occasionTitle(surprise.occasion, name);
  // Deliberately generic: link previews are scraped by third parties, so no photos, message or
  // creator details go in here. The recipient's name is what makes the preview feel personal.
  const description = `Someone made something special for ${name}. Open it to see.`;
  return {
    title,
    description,
    robots: noIndex,
    openGraph: { type: 'website', title, description, siteName: 'Surprise Studio' },
    twitter: { card: 'summary_large_image', title, description },
  };
}

/** Tints the phone's browser chrome to the surprise's background. */
export async function generateViewport({ params }: Props): Promise<Viewport> {
  const { slug } = await params;
  const surprise = await getSurprise(slug).catch(() => null);
  return surprise ? { themeColor: surprise.theme.colors.background } : {};
}

export default async function SurprisePage({ params }: Props) {
  const { slug } = await params;
  const surprise = await getSurprise(slug);
  if (!surprise) notFound();
  return <Experience surprise={surprise} />;
}
