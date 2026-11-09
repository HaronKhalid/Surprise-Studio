import { VARIANTS } from './image-validation';

/**
 * Processed, publicly readable files live under assets/; raw uploads are private and short-lived.
 * The public key is random, not derived from database ids, because it ends up in public image URLs.
 */
export const uploadKey = (assetId: string) => `uploads/${assetId}`;
export const variantKeys = (storageKey: string) => VARIANTS.map((v) => `${storageKey}/${v.name}.webp`);

/** Every object that can exist in storage for one asset (raw upload and all variants). */
export const allKeysForAsset = (asset: { id: string; storageKey: string }) => [
  uploadKey(asset.id),
  ...variantKeys(asset.storageKey),
];
