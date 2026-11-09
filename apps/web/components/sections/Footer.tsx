import { EndBeacon, TrackedLink } from '@/components/Beacons';

/**
 * Subtle viral loop: part of every free surprise, never intrusive.
 * Without a `slug` (draft preview) the links are plain and nothing is reported.
 */
export function Footer({ slug, template }: { slug?: string; template: string }) {
  return (
    <footer className="site-footer">
      {slug && <EndBeacon slug={slug} template={template} />}
      <p>
        Made with{' '}
        {slug ? (
          <TrackedLink slug={slug} step="footer_brand" href="/">
            Surprise Studio
          </TrackedLink>
        ) : (
          <a href="/">Surprise Studio</a>
        )}
      </p>
      {slug ? (
        <TrackedLink slug={slug} step="footer_cta" href="/" className="cta">
          Create your own surprise
        </TrackedLink>
      ) : (
        <a href="/" className="cta">
          Create your own surprise
        </a>
      )}
    </footer>
  );
}
