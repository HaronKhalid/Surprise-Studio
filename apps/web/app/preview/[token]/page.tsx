import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { Experience } from '@/components/Experience';
import { getPreview } from '@/lib/api';

interface Props {
  params: Promise<{ token: string }>;
}

// Per-request and never cached: the token is a credential and the content is a live draft.
export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Preview',
  robots: { index: false, follow: false },
  referrer: 'no-referrer',
};

/** What the creator app shows in its Preview step: the real renderer, fed from the unpublished draft. */
export default async function PreviewPage({ params }: Props) {
  const { token } = await params;
  const surprise = await getPreview(token);
  if (!surprise) notFound();
  return <Experience surprise={surprise} preview />;
}
