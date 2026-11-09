import { EndBeacon, TrackedLink } from '@/components/Beacons';

/** Subtle viral loop: part of every free surprise, never intrusive. */
export function Footer({ slug, template }: { slug: string; template: string }) {
  return (
    <footer className="site-footer">
      <EndBeacon slug={slug} template={template} />
      <p>
        Made with{' '}
        <TrackedLink slug={slug} step="footer_brand" href="/">
          Surprise Studio
        </TrackedLink>
      </p>
      <TrackedLink slug={slug} step="footer_cta" href="/" className="cta">
        Create your own surprise
      </TrackedLink>
    </footer>
  );
}
