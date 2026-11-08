'use client';

import { useRef } from 'react';
import { photoSrcSet } from '@/lib/photo';
import type { PhotoData } from '@/lib/types';

interface Props {
  photo: PhotoData;
  index: number;
  total: number;
  sizes: string;
  /** Above-the-fold photo: load immediately instead of lazily. */
  priority?: boolean;
  className?: string;
}

/** A photo that opens full screen when tapped. Uses the native <dialog> for focus trapping and Esc. */
export function Photo({ photo, index, total, sizes, priority = false, className = '' }: Props) {
  const dialog = useRef<HTMLDialogElement>(null);
  const alt = `Photo ${index + 1} of ${total}`;
  const dims = photo.width && photo.height ? { width: photo.width, height: photo.height } : {};

  return (
    <>
      <button type="button" className={`photo ${className}`} onClick={() => dialog.current?.showModal()} aria-label={`${alt}, open full screen`}>
        <img
          src={photo.urls.medium}
          srcSet={photoSrcSet(photo)}
          sizes={sizes}
          alt=""
          {...dims}
          loading={priority ? 'eager' : 'lazy'}
          fetchPriority={priority ? 'high' : 'auto'}
          decoding="async"
        />
      </button>
      <dialog
        ref={dialog}
        className="lightbox"
        aria-label={alt}
        onClick={(e) => {
          if (e.target === e.currentTarget) dialog.current?.close();
        }}
      >
        <form method="dialog">
          <button className="lightbox-close" aria-label="Close photo">
            ×
          </button>
        </form>
        {/* Lazy: a closed dialog is display:none, so the large file is only fetched when opened. */}
        <img src={photo.urls.large} alt={alt} loading="lazy" decoding="async" />
      </dialog>
    </>
  );
}
