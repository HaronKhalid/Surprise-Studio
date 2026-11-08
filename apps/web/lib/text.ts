import type { PublicSurprise } from './types';

/** What we call the recipient on the page. */
export const displayName = (s: PublicSurprise) => s.recipient.nickname?.trim() || s.recipient.name;

/**
 * Replaces `{name}` in template copy. Output is always rendered as text, never as HTML.
 * A function replacer is used because the name is user input: with a plain string, sequences like
 * `$&` or `$1` in a name would be interpreted as replacement patterns and mangle it.
 */
export const fill = (text: string | number | boolean | undefined, name: string) =>
  typeof text === 'string' ? text.replaceAll('{name}', () => name) : '';

/** Neutral wording per occasion for places where the creator wrote nothing of their own. */
const WISHES: Record<string, string> = {
  birthday: 'Happy Birthday, {name} 🎂',
};
export const occasionWish = (occasion: string, name: string) => fill(WISHES[occasion] ?? 'Thinking of you, {name} 💛', name);

export const occasionTitle = (occasion: string, name: string) =>
  occasion === 'birthday' ? `${name}'s Birthday Surprise 🎂` : `A surprise for ${name} 🎁`;
