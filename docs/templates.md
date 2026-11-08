# Templates

A template is **data, not code**: a versioned JSON definition that says which sections a surprise has,
what its default look is, and how much of that the creator may change. The public page renders
`template + surprise content + photos`; no recipient information lives in a template.

Source files live in `templates/<slug>/v<N>.json`. They are loaded into the `Template` table by
`npm run templates:seed` (from `apps/api`) and validated by `src/templates/template-config.ts`.

## Launch templates

| slug | feel | default font | photos needed | memories |
|---|---|---|---|---|
| `cinematic` | dark, slow reveal | playfair | 1 | optional, max 6 |
| `cute` | bright, playful, confetti | poppins | 1 | optional, max 8 |
| `memories` | warm, nostalgic timeline | dm-serif | 2 | **required**, max 6 |
| `luxury` | minimal, typography-first | cormorant | 1 | none |

## Definition file

```jsonc
{
  "slug": "cinematic",          // must equal the folder name
  "version": 1,                 // must equal the file name (v1.json)
  "name": "Cinematic",
  "occasion": "birthday",
  "configuration": {
    "schemaVersion": 1,
    "displayOrder": 1,          // order in GET /templates (unique per template)
    "description": "…",         // shown on the template card, max 200 chars
    "sections": [ { "type": "hero", "required": true, "props": { "eyebrow": "…" } }, … ],
    "theme": {                  // the default look
      "colors": { "background": "#0B1020", "surface": "#151B2E", "text": "#FFFFFF", "accent": "#D4AF37" },
      "font": "playfair"
    },
    "customizable": {           // what a creator may override
      "colors": ["accent"],
      "fonts": ["playfair", "cormorant", "dm-serif", "inter"]
    },
    "limits": { "minPhotos": 1, "maxMemories": 6 }
  }
}
```

### Sections

Rendered top to bottom. The first must be `hero`; the last must be a required `footer` (the
"Made with Surprise Studio" link). A type may appear once. Optional sections are skipped when the
creator provided nothing for them.

| type | content it uses | `required: true` means publishing needs… | props |
|---|---|---|---|
| `hero` | recipient name | nothing (always renderable) | `eyebrow` |
| `photo_gallery` | photos, in `sortOrder` | at least `max(1, limits.minPhotos)` photos | `layout`: `reveal`, `grid`, `timeline`, `hero_then_grid` (**required**) |
| `memory_cards` | `content.memories` | at least one memory | `heading` |
| `message` | `message` | a non-blank message | `heading` |
| `confetti` | none (effect) | nothing | none |
| `final_reveal` | `content.ending` if set | nothing | `prompt` |
| `final_wish` | recipient name | nothing | `text` |
| `footer` | none | nothing | none |

`props` values are strings (max 120 chars), numbers or booleans. In text props, `{name}` is replaced
by the renderer with the recipient's nickname, or name if there is no nickname. Always render props as
text, never as HTML.

### Theme tokens

Colours are `#rrggbb` only and fonts are keys from a fixed list (`playfair`, `cormorant`, `dm-serif`,
`inter`, `poppins`) that the web app maps to real font files. This is deliberate: theme values end up in
CSS custom properties on a public page, so free-form strings would be a CSS-injection hole.

A creator's overrides are checked against `customizable` when they are saved:

- only colours listed in `customizable.colors` can change (all launch templates allow `accent` only);
- the font must be in `customizable.fonts`;
- text must stay readable: text/background contrast ≥ 4.5:1 and accent/background ≥ 3:1
  (`THEME_LOW_CONTRAST` otherwise). Template defaults are tested against the same rule.

Switching a surprise to a different template **clears its theme overrides**, because they were chosen
for the old template (send a new `theme` in the same request to keep customising).

## Content a creator provides

| field | limit |
|---|---|
| `message` | 5000 chars |
| `content.intro` | 300 chars |
| `content.ending` | 600 chars |
| `content.memories[]` | up to 10 globally and `limits.maxMemories` per template; `title` ≤ 80, `text` 1–500 chars |

Unknown keys in `content` or `theme` are rejected, not stored.

## Versioning (important)

**Never edit a released `v<N>.json`.** Published surprises were built on that exact version, and the
rule from the architecture doc is that an old surprise must keep rendering the same way forever. To
change a template, add `v<N+1>.json`:

- `GET /templates` and `GET /templates/:slug` return the **latest active** version of each slug, so new
  surprises pick up v2 automatically;
- an existing surprise keeps its `templateId` (a specific version row), so it keeps v1;
- publishing copies the template configuration **into the surprise's `publishedSnapshot`**, so even a
  retired or changed row cannot affect a live page.

`npm run templates:seed` enforces this: if a `(slug, version)` already exists with different content it
refuses (exit 1) and tells you to add the next version. `--force` overrides that for local development
only; never use it against a database with published surprises.

## Adding a template

1. Create `templates/<slug>/v1.json` (copy an existing one).
2. `npm test` in `apps/api`. `template-files.spec.ts` validates every definition, including contrast.
3. `npm run templates:seed`.
4. Add the layout to the web renderer (`apps/web`) if it uses new `props` or a new `photo_gallery` layout.

Adding a new **section type** or **font** is a code change: extend `SECTION_TYPES` / `FONT_KEYS` in
`template-config.ts`, then build the component in the web renderer.
