/**
 * Product funnel events. A closed list: the endpoint is unauthenticated, so it must not let
 * callers invent event names or store arbitrary data.
 */
export const EVENT_TYPES = [
  // creator app
  'app_opened',
  'create_started',
  'surprise_created',
  'template_selected',
  'photo_uploaded',
  'preview_opened',
  'surprise_published',
  'share_clicked',
  // recipient web page
  'public_page_opened',
  'public_view_completed',
  'cta_clicked',
] as const;

export type EventType = (typeof EVENT_TYPES)[number];
