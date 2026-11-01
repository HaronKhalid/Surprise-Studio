# Personalized Surprise Platform — `scratchpad.md`

## 0. Project Identity

**Working product name:** `Surprise Studio`  
**Status:** Architecture / MVP planning  
**Primary platform:** Android  
**Generated experience:** Responsive web page  
**Future platforms:** iOS, desktop/web creator dashboard

### Core idea

Build a platform where a user can create a personalized digital surprise for another person.

The creator enters:

- recipient name
- relationship
- birthday/occasion
- message
- memories
- photos
- optional music
- optional preferences
- optional custom text

The system combines this information with a visual template and generates a beautiful, mobile-first, shareable web experience.

Example:

```text
Creator
  ↓
Create Surprise
  ↓
Enter recipient information
  ↓
Upload photos
  ↓
Choose template
  ↓
Customize
  ↓
Optional AI enhancement
  ↓
Preview
  ↓
Publish
  ↓
Unique URL
  ↓
Share on WhatsApp / Instagram / Messenger / etc.
  ↓
Recipient opens URL without installing the app
```

---

# 1. Product Vision

The initial product is a birthday-surprise generator.

The long-term product is a:

> Personalized digital experience / digital gifting platform.

Potential occasions:

- Birthday
- Friendship
- Anniversary
- Valentine
- Graduation
- Wedding
- Engagement
- Farewell
- Congratulations
- Eid
- Christmas
- New Year
- Mother's Day
- Father's Day
- Event invitations
- Personalized appreciation pages

The architecture MUST therefore avoid hard-coding the entire system around birthdays.

Use a generic concept:

```text
Occasion
Template
Content
Assets
Experience
Share URL
```

---

# 2. Product Principles

1. The recipient should NOT need the mobile app.
2. The generated experience must load quickly.
3. The creator flow should be simple enough for a non-technical user.
4. Templates should be reusable and data-driven.
5. AI should enhance the product, not become a mandatory dependency.
6. Free users should be able to create a useful experience.
7. Premium features should be easy to add later.
8. Privacy must be considered from the beginning because users upload personal photographs.
9. The backend must be designed for eventual scale.
10. The first release should remain small.

---

# 3. MVP Scope

## Must Have

### Creator app

- onboarding
- create surprise
- occasion selection
- recipient name
- relationship
- message
- photo upload
- photo ordering
- template selection
- basic customization
- preview
- publish
- unique share URL
- share button
- saved surprises
- delete surprise

### Generated web experience

- responsive mobile-first layout
- hero section
- recipient name
- photos
- personalized message
- animations
- final reveal
- creator branding on free plan
- share button

### Backend

- authentication
- users
- surprises
- templates
- assets
- publishing
- public page retrieval
- basic analytics
- authorization
- storage

---

# 4. Explicitly NOT in MVP

Do NOT build these in V1:

- social network
- public user profiles
- chat
- complex video editor
- AI image generation
- AI avatars
- AI voice cloning
- automatic music licensing
- complex timeline editor
- iOS application
- desktop application
- 100+ templates
- subscription system
- complicated referral system
- advanced creator analytics
- marketplace

These can come later.

---

# 5. Recommended Technology Stack

## Mobile

**Flutter + Dart**

Why:

- one codebase
- Android first
- good UI control
- animation support
- easy future iOS expansion
- suitable for form-heavy and media-heavy interfaces

## Generated web experience

**Next.js + TypeScript**

Use the web layer independently from the mobile application.

Responsibilities:

- public surprise pages
- SEO/social metadata where applicable
- server-side rendering/static generation where useful
- fast loading
- responsive UI
- animations

## Backend

**Node.js + TypeScript + NestJS**

Reason:

- structured architecture
- strong TypeScript support
- modularity
- validation
- authentication
- clean API organization
- good long-term maintainability

Alternative for a simpler first backend:

- FastAPI + Python

But the main architecture should use NestJS.

## Database

**PostgreSQL**

## ORM

**Prisma**

## Object storage

Use S3-compatible object storage.

Possible providers:

- Cloudflare R2
- AWS S3
- Supabase Storage
- another S3-compatible provider

The application must interact through an abstraction layer so the storage provider can be changed later.

## Cache / queues

MVP:

- no Redis required unless needed

Later:

- Redis
- BullMQ

Use queues for:

- image processing
- AI generation
- email
- analytics aggregation
- cleanup jobs

## Authentication

MVP options:

- email/password
- Google Sign-In

Recommended:

- Firebase Auth OR custom JWT authentication

For a fully controlled backend, use:

```text
short-lived access token
+
refresh token
```

Store sensitive authentication information securely.

## AI

Create an abstraction:

```text
AIProvider
```

Possible providers:

- OpenAI
- Google Gemini
- Anthropic
- local/open-source model later

Never hard-code the entire application to one AI provider.

## Analytics

MVP:

- privacy-conscious internal event tracking

Events:

```text
app_opened
surprise_created
template_selected
photo_uploaded
preview_opened
surprise_published
share_clicked
public_page_opened
cta_clicked
```

---

# 6. High-Level Architecture

```text
                    ┌───────────────────────┐
                    │    Flutter Android    │
                    │       Creator         │
                    └───────────┬───────────┘
                                │ HTTPS
                                ▼
                    ┌───────────────────────┐
                    │       API Gateway     │
                    │       / REST API      │
                    └───────────┬───────────┘
                                │
               ┌────────────────┼────────────────┐
               │                │                │
               ▼                ▼                ▼
       ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
       │ Auth Module  │ │ Surprise     │ │ Template     │
       │              │ │ Module       │ │ Module       │
       └──────────────┘ └──────────────┘ └──────────────┘
               │                │                │
               └────────────────┼────────────────┘
                                ▼
                    ┌───────────────────────┐
                    │      PostgreSQL       │
                    └───────────────────────┘

                    ┌───────────────────────┐
                    │    Object Storage    │
                    │ photos / assets      │
                    └───────────────────────┘

                    ┌───────────────────────┐
                    │      AI Service       │
                    │ text / captions       │
                    └───────────────────────┘

                    ┌───────────────────────┐
                    │   Next.js Web App     │
                    │ Public Surprise Page  │
                    └───────────────────────┘
```

---

# 7. Monorepo Structure

Use a monorepo.

```text
surprise-studio/
│
├── apps/
│   │
│   ├── mobile/
│   │   └── Flutter application
│   │
│   ├── web/
│   │   └── Next.js public experience
│   │
│   └── api/
│       └── NestJS backend
│
├── packages/
│   │
│   ├── types/
│   │   └── shared TypeScript types
│   │
│   ├── config/
│   │   └── shared configuration
│   │
│   ├── template-schema/
│   │   └── template definitions
│   │
│   └── validation/
│       └── shared validation schemas
│
├── templates/
│   │
│   ├── cinematic/
│   ├── cute/
│   ├── memories/
│   └── luxury/
│
├── docs/
│   ├── architecture.md
│   ├── api.md
│   ├── database.md
│   ├── templates.md
│   ├── security.md
│   ├── deployment.md
│   └── monetization.md
│
├── infrastructure/
│   ├── docker/
│   ├── migrations/
│   └── deployment/
│
├── scripts/
│
├── .env.example
├── .gitignore
├── README.md
├── package.json
└── scratchpad.md
```

---

# 8. Flutter Structure

```text
apps/mobile/
│
├── lib/
│   │
│   ├── main.dart
│   │
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── network/
│   │   ├── storage/
│   │   ├── utils/
│   │   └── widgets/
│   │
│   ├── features/
│   │   │
│   │   ├── auth/
│   │   ├── home/
│   │   ├── create_surprise/
│   │   ├── templates/
│   │   ├── editor/
│   │   ├── preview/
│   │   ├── publishing/
│   │   ├── surprises/
│   │   └── settings/
│   │
│   └── services/
│       ├── api_service.dart
│       ├── auth_service.dart
│       ├── upload_service.dart
│       └── analytics_service.dart
│
├── test/
└── pubspec.yaml
```

---

# 9. Flutter Screens

## Onboarding

```text
Welcome
↓
What can you create?
↓
Continue
```

Keep it short.

## Home

```text
Create Surprise

Your Surprises
 ├── Ahmed's Birthday
 ├── Sara's Birthday
 └── Graduation

Templates
```

## Create Surprise

```text
Choose Occasion

Birthday
Anniversary
Friendship
Graduation
...
```

## Recipient Information

```text
Name
Nickname
Relationship
Date
Optional details
```

## Photos

```text
+ Add Photos

photo 1
photo 2
photo 3
...
```

Support:

- reorder
- remove
- crop/fit
- compression

## Template Selection

Cards:

```text
Cinematic
Cute
Memories
Luxury
```

## Customization

```text
Theme
Font
Accent
Message
Music (future)
```

## Preview

Show the actual generated experience.

## Publish

```text
Publish Surprise

[ Publish ]

Privacy:
Private / Unlisted
```

## Success

```text
Your surprise is ready!

[ Copy Link ]
[ WhatsApp ]
[ Share ]
[ Preview ]
```

---

# 10. Web App Structure

```text
apps/web/
│
├── app/
│   ├── page.tsx
│   ├── s/
│   │   └── [slug]/
│   │       └── page.tsx
│   ├── privacy/
│   ├── terms/
│   └── not-found.tsx
│
├── components/
│   ├── experiences/
│   ├── sections/
│   ├── animations/
│   └── shared/
│
├── templates/
│   ├── CinematicTemplate.tsx
│   ├── CuteTemplate.tsx
│   ├── MemoriesTemplate.tsx
│   └── LuxuryTemplate.tsx
│
├── lib/
│   ├── api.ts
│   ├── template-loader.ts
│   └── metadata.ts
│
└── public/
```

---

# 11. Public URL System

Every published surprise gets a random slug.

Example:

```text
https://yourdomain.com/s/a8Kp3xQz
```

Do NOT expose:

```text
/s/user/123/surprise/456
```

Use a public random identifier.

Requirements:

- collision-resistant
- not sequential
- not personally identifiable
- difficult to guess

Use something like:

```text
nanoid
```

or UUID-based identifiers.

---

# 12. Database Schema

## User

```text
User
-----
id
email
displayName
avatarUrl
createdAt
updatedAt
```

## Surprise

```text
Surprise
--------
id
userId
occasionId
templateId
recipientName
recipientNickname
relationship
message
slug
status
visibility
publishedAt
createdAt
updatedAt
```

Status:

```text
DRAFT
PUBLISHED
ARCHIVED
DELETED
```

Visibility:

```text
PRIVATE
UNLISTED
```

## Asset

```text
Asset
-----
id
surpriseId
storageKey
url
type
mimeType
width
height
size
sortOrder
createdAt
```

## Template

```text
Template
--------
id
name
slug
occasion
version
configuration
isActive
createdAt
updatedAt
```

## Event

```text
Event
-----
id
surpriseId
eventType
metadata
createdAt
```

Do not store unnecessary personal data.

---

# 13. Template Architecture

The template system is one of the most important parts.

A template should be data-driven.

Example:

```json
{
  "id": "cinematic-v1",
  "name": "Cinematic",
  "occasion": "birthday",
  "version": 1,
  "sections": [
    {
      "type": "hero",
      "required": true
    },
    {
      "type": "photo_gallery",
      "required": true
    },
    {
      "type": "message",
      "required": true
    },
    {
      "type": "timeline",
      "required": false
    },
    {
      "type": "final_reveal",
      "required": true
    }
  ]
}
```

The renderer receives:

```text
Template
+
Surprise data
+
Assets
```

and renders the final page.

---

# 14. Template Components

Build reusable components.

```text
Hero
PhotoGallery
FullScreenPhoto
Message
Quote
Timeline
MemoryCard
Countdown
Reveal
Confetti
FloatingParticles
Video
MusicPlayer
FinalWish
Footer
```

Every component should have a predictable interface.

Example:

```typescript
type SectionData = {
  type: string;
  data: unknown;
};
```

Avoid making every template completely independent.

---

# 15. Theme System

Use design tokens.

```text
colors
typography
spacing
radius
shadows
animation
```

Example:

```json
{
  "colors": {
    "background": "#0B1020",
    "surface": "#151B2E",
    "text": "#FFFFFF",
    "accent": "#D4AF37"
  }
}
```

The user can change supported theme values without modifying template code.

---

# 16. Animation Architecture

Animations must be:

- smooth
- lightweight
- mobile-friendly
- optional/reduced when device performance is poor

Use:

- CSS animations
- Framer Motion where appropriate
- Web APIs
- lightweight canvas effects only when justified

Avoid huge animation libraries.

Support:

```text
prefers-reduced-motion
```

---

# 17. Image Pipeline

Never blindly serve original uploads.

Flow:

```text
User selects photo
       ↓
Client validates
       ↓
Upload
       ↓
Backend generates upload permission
       ↓
Storage
       ↓
Image processing
       ↓
Resize
       ↓
Compress
       ↓
Generate optimized variants
       ↓
CDN delivery
```

Generate multiple sizes:

```text
thumbnail
medium
large
```

Use modern formats where possible:

- WebP
- AVIF

Keep original only if business requirements justify it.

---

# 18. Upload Security

Allowed MIME types:

```text
image/jpeg
image/png
image/webp
```

Validate:

- extension
- MIME type
- actual file signature
- file size
- dimensions

Set maximum upload size.

Never trust client-side validation alone.

---

# 19. API Structure

Base:

```text
/api/v1
```

## Auth

```text
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
GET  /auth/me
```

## Surprises

```text
POST   /surprises
GET    /surprises
GET    /surprises/:id
PATCH  /surprises/:id
DELETE /surprises/:id
POST   /surprises/:id/publish
POST   /surprises/:id/unpublish
```

## Assets

```text
POST   /assets/upload-url
POST   /assets/complete
DELETE /assets/:id
PATCH  /assets/:id/order
```

## Templates

```text
GET /templates
GET /templates/:slug
```

## Public

```text
GET /public/surprises/:slug
```

## Analytics

```text
POST /analytics/events
```

---

# 20. Authentication Rules

Every protected endpoint must verify:

```text
authenticated user
+
resource ownership
```

Do NOT trust:

```text
userId
```

sent by the client.

Determine the authenticated user from the access token.

Example:

```text
GET /surprises/123

JWT → user A

surprise 123 → belongs to user A

ALLOW
```

If it belongs to user B:

```text
403 Forbidden
```

---

# 21. Public Surprise Security

Public pages are intentionally accessible.

But public access must reveal only what the creator chose to publish.

Do NOT expose:

- creator email
- internal user ID
- private metadata
- storage credentials
- database IDs
- admin information

Public API should return a sanitized DTO.

---

# 22. Privacy

The product deals with personal photographs.

Implement:

- privacy policy
- terms of service
- delete account
- delete surprise
- delete assets
- data retention policy
- secure storage
- access control
- HTTPS
- signed upload URLs
- signed/private storage where appropriate

Never expose storage credentials to the client.

---

# 23. AI Architecture

Create an internal interface.

```typescript
interface AIProvider {
  generateMessage(input: MessageGenerationInput): Promise<string>;
  generateCaptions(input: CaptionInput): Promise<string[]>;
}
```

Then:

```text
AIService
   ↓
AIProvider
   ├── OpenAIProvider
   ├── GeminiProvider
   └── FutureLocalProvider
```

This allows changing providers without rewriting the application.

---

# 24. AI Features for MVP+

## Feature 1 — Message generation

Input:

```text
Name
Relationship
Tone
Memories
```

Output:

```text
Opening
Main message
Final message
```

Tones:

- emotional
- funny
- romantic
- friendly
- elegant
- short
- poetic

## Feature 2 — Photo captions

Input:

```text
photo
memory/context
```

Output:

```text
short caption
```

## Feature 3 — Story generation

Input:

```text
relationship
memories
photos
```

Output:

```text
intro
memory sequence
ending
```

AI output must always be editable.

---

# 25. AI Safety

Do not automatically publish generated text without allowing review.

Flow:

```text
Generate
 ↓
Preview
 ↓
User edits
 ↓
Publish
```

Never assume AI-generated personal facts are correct.

---

# 26. Monetization Architecture

Do not hard-code payments into template logic.

Use entitlements.

Example:

```text
FREE
PREMIUM
CREATOR
```

Feature flags:

```text
premium_templates
remove_branding
max_photos
ai_generation
custom_domain
advanced_animations
storage_limit
```

Example:

```text
User
 ↓
Subscription/Entitlement
 ↓
FeatureAccessService
 ↓
Allowed / Denied
```

---

# 27. Free Plan

Example:

```text
3–5 templates
10 photos
basic animations
basic AI credits
platform branding
limited storage
```

The exact limits can be adjusted after testing.

---

# 28. Premium Plan

Possible features:

```text
premium templates
more photos
advanced animations
AI credits
remove branding
custom colors
custom music
longer storage
custom URL
```

Use one-time purchases initially.

Possible price experiments:

```text
PKR 299
PKR 499
PKR 799
```

International:

```text
$1.99
$2.99
$4.99
```

These are pricing experiments, not fixed final prices.

---

# 29. Ads

Use ads carefully.

Potential:

- banner in creator app
- occasional interstitial
- rewarded ad for optional free premium generation

Do NOT put intrusive ads inside the emotional recipient experience.

Potential model:

```text
Free creator
 ↓
Ad-supported

Premium creator
 ↓
No ads
```

---

# 30. Analytics

Track product behavior, not unnecessary personal information.

Important metrics:

```text
install
signup
create_started
create_completed
template_selected
photo_uploaded
preview_viewed
published
share_clicked
public_view
public_view_completed
premium_view
purchase_started
purchase_completed
```

Key business metrics:

```text
Activation Rate
Publish Rate
Share Rate
Recipient View Rate
Viral Coefficient
Conversion Rate
ARPU
Retention
Cost per Acquisition
```

Most important early metric:

> Percentage of creators who successfully publish and share a surprise.

---

# 31. Viral Loop

Every public surprise should contain a subtle CTA:

```text
Made with Surprise Studio

Create your own surprise
```

Do not make it visually destructive.

Flow:

```text
Creator A
 ↓
creates surprise
 ↓
Recipient B opens it
 ↓
Recipient B sees "Create your own"
 ↓
B creates surprise
 ↓
Recipient C opens it
```

This can become a major acquisition channel.

---

# 32. Deep Linking

The Android app should support links such as:

```text
https://yourdomain.com/s/abc123
```

If the app is installed:

```text
open app
```

If not installed:

```text
open web experience
```

Use Android App Links.

Later add iOS Universal Links.

---

# 33. Sharing

Support native Android share sheet.

Buttons:

```text
Share
WhatsApp
Copy Link
Instagram
Messenger
```

Do not require direct integrations with every social platform in V1.

Native share is enough.

---

# 34. SEO / Social Preview

Every public surprise should generate metadata.

Example:

```text
Title:
Ahmed's Birthday Surprise 🎂

Description:
Someone created a special surprise for Ahmed.

Image:
generated social preview image
```

Use Open Graph metadata.

Do not expose private information in metadata.

---

# 35. Generated Social Preview

Later create a dynamic preview image:

```text
Ahmed
Happy Birthday ❤️
```

This can improve link sharing.

Possible architecture:

```text
Surprise
 ↓
PreviewImageService
 ↓
generated OG image
 ↓
CDN
```

---

# 36. Performance Requirements

Public experience target:

```text
First meaningful content: fast
Images: lazy loaded
Fonts: optimized
JavaScript: minimized
Animations: GPU-friendly
```

Targets should be measured rather than guessed.

Use Lighthouse and real-device testing.

Do not load every image at full resolution immediately.

---

# 37. Backend Error Handling

Use consistent API responses.

Example:

```json
{
  "success": false,
  "error": {
    "code": "SURPRISE_NOT_FOUND",
    "message": "Surprise not found"
  }
}
```

Never return stack traces to users.

Log internal errors separately.

---

# 38. Logging

Use structured logs.

Record:

```text
timestamp
requestId
userId if available
endpoint
status
duration
error code
```

Never log:

- passwords
- access tokens
- refresh tokens
- private image URLs
- sensitive personal content unnecessarily

---

# 39. Rate Limiting

Protect:

```text
login
register
AI generation
upload URL generation
publish
public API
analytics
```

AI endpoints require particularly strict limits because they cost money.

---

# 40. Abuse Prevention

Add:

- rate limiting
- report page
- block abusive content
- moderation mechanism
- upload validation
- storage quotas
- AI usage limits

Future:

```text
automated moderation
manual review
```

---

# 41. Environment Variables

Example:

```env
NODE_ENV=development

DATABASE_URL=

JWT_SECRET=
JWT_REFRESH_SECRET=

STORAGE_ENDPOINT=
STORAGE_BUCKET=
STORAGE_ACCESS_KEY=
STORAGE_SECRET_KEY=

AI_PROVIDER=
AI_API_KEY=

NEXT_PUBLIC_API_URL=

ANALYTICS_KEY=

PAYMENT_PROVIDER=
PAYMENT_SECRET=
```

Never commit `.env`.

Commit:

```text
.env.example
```

---

# 42. Local Development

Recommended:

```text
Docker
PostgreSQL
Node.js
Flutter
```

Run:

```text
database
backend
web
mobile
```

locally.

Example:

```text
localhost:3000 → web
localhost:4000 → API
localhost:5432 → PostgreSQL
```

The exact ports can be changed.

---

# 43. Docker

Create:

```text
docker-compose.yml
```

Services:

```text
postgres
redis (future)
api
web (optional for production-like testing)
```

Do not containerize Flutter unnecessarily during normal development.

---

# 44. Testing Strategy

## Backend

Unit tests:

```text
auth
surprise service
template service
publishing
permissions
AI service
```

Integration tests:

```text
database
API
authentication
uploads
```

## Web

Test:

```text
public page
template rendering
responsive behavior
invalid slug
missing content
```

## Flutter

Test:

```text
form validation
state
API calls
upload flow
navigation
```

## E2E

Critical path:

```text
register
→ create
→ upload
→ select template
→ preview
→ publish
→ open public URL
```

---

# 45. Git Strategy

Branches:

```text
main
develop
feature/*
fix/*
```

Commit style:

```text
feat:
fix:
refactor:
docs:
test:
chore:
```

Example:

```text
feat: add surprise publishing flow
fix: validate image upload size
```

---

# 46. CI/CD

Use GitHub Actions.

Pipeline:

```text
Push
 ↓
Lint
 ↓
Type check
 ↓
Unit tests
 ↓
Build
 ↓
Deploy
```

For production:

```text
main
 ↓
CI
 ↓
API deployment
 ↓
Web deployment
```

Android:

```text
main/release
 ↓
build APK/AAB
 ↓
test
 ↓
manual Play Store release
```

Do not automatically publish production Android builds at the beginning.

---

# 47. Deployment Architecture

MVP:

```text
Flutter
     ↓
Google Play

Next.js
     ↓
Vercel / equivalent

NestJS
     ↓
managed container/server

PostgreSQL
     ↓
managed database

Object Storage
     ↓
S3-compatible provider

CDN
     ↓
public assets
```

The exact vendors can be changed.

Avoid vendor lock-in by using interfaces.

---

# 48. Production Domains

Recommended structure:

```text
yourdomain.com
```

Public surprises:

```text
yourdomain.com/s/abc123
```

API:

```text
api.yourdomain.com
```

Optional future creator web app:

```text
app.yourdomain.com
```

---

# 49. Security Checklist

Before production:

```text
[ ] HTTPS
[ ] secure authentication
[ ] refresh-token rotation
[ ] password hashing if using passwords
[ ] rate limiting
[ ] CORS configuration
[ ] CSRF protection where applicable
[ ] SQL injection protection through ORM
[ ] input validation
[ ] file validation
[ ] upload size limits
[ ] signed upload URLs
[ ] authorization checks
[ ] sanitized public DTO
[ ] secret management
[ ] database backups
[ ] deletion flow
[ ] privacy policy
[ ] terms
```

---

# 50. Product UX Rules

The user should never feel like they are filling out a database form.

Instead of:

```text
Recipient Name
Recipient Relationship
Recipient Description
Message
Photo Metadata
```

Use conversational UX:

```text
Who is this surprise for?

What's their name?

What are they to you?

Tell us something about them...

Add your favorite memories.
```

Make the process feel creative.

---

# 51. MVP User Flow

```text
OPEN APP
  ↓
HOME
  ↓
CREATE SURPRISE
  ↓
CHOOSE BIRTHDAY
  ↓
ENTER NAME
  ↓
ADD MESSAGE
  ↓
ADD PHOTOS
  ↓
CHOOSE TEMPLATE
  ↓
PREVIEW
  ↓
EDIT
  ↓
PUBLISH
  ↓
SHARE
```

Target:

> User should be able to create a basic surprise in a few minutes.

---

# 52. Template #1 — Cinematic

Sections:

```text
Intro
↓
Recipient Name
↓
"Someone made something for you..."
↓
Photo reveal
↓
Memory cards
↓
Personal message
↓
Final reveal
↓
Birthday wish
```

Visual direction:

- dark
- cinematic
- elegant
- smooth
- emotional

---

# 53. Template #2 — Cute

Sections:

```text
Animated intro
↓
Name
↓
Photos
↓
Funny messages
↓
Confetti
↓
Birthday wish
```

Visual direction:

- bright
- playful
- friendly

---

# 54. Template #3 — Memories

Sections:

```text
Our Story
↓
Photo timeline
↓
Memory 1
↓
Memory 2
↓
Memory 3
↓
Final message
```

Visual direction:

- emotional
- nostalgic
- photo-focused

---

# 55. Template #4 — Luxury

Sections:

```text
Minimal intro
↓
Name
↓
Hero photograph
↓
Elegant message
↓
Gallery
↓
Final reveal
```

Visual direction:

- minimal
- premium
- typography-focused

---

# 56. Content Model

Keep content flexible.

Example:

```json
{
  "recipient": {
    "name": "Ahmed",
    "nickname": "Amee",
    "relationship": "best_friend"
  },
  "occasion": {
    "type": "birthday"
  },
  "content": {
    "intro": "...",
    "message": "...",
    "ending": "..."
  },
  "assets": [],
  "theme": {},
  "sections": []
}
```

This allows future occasions without redesigning the database.

---

# 57. Draft vs Published

A surprise should have two states.

## Draft

Can change everything.

## Published

A snapshot/version is served publicly.

Do not allow random editing to break a currently shared page.

Better architecture:

```text
Draft
 ↓
Publish
 ↓
Published Version
```

Later:

```text
Edit
 ↓
New Version
 ↓
Republish
```

This makes publishing reliable.

---

# 58. Versioning

Templates must have versions.

Example:

```text
cinematic-v1
cinematic-v2
```

A surprise created with v1 should continue rendering correctly even after v2 is released.

Never silently change the visual structure of old published surprises.

---

# 59. Storage Lifecycle

Possible:

```text
Draft assets
 ↓
Published assets
 ↓
Active
 ↓
User deletes
 ↓
soft delete
 ↓
retention period
 ↓
permanent deletion
```

Run cleanup jobs.

---

# 60. Cost Control

Important because AI and storage can create variable costs.

Implement:

```text
max photos
max photo size
storage quotas
AI credits
rate limits
generation limits
```

Before every paid AI operation:

```text
check entitlement
check credits
execute
record usage
```

Never allow unlimited free AI generation.

---

# 61. Monetization Roadmap

## Phase 1

No monetization.

Goal:

> Validate product.

## Phase 2

Ads for free creator users.

## Phase 3

One-time premium surprise.

## Phase 4

Premium template packs.

## Phase 5

AI credits.

## Phase 6

Subscription for heavy users.

## Phase 7

Business/event plans.

---

# 62. Business Expansion

Eventually:

```text
B2C
Personal surprises
     ↓
B2B
Digital invitations
     ↓
Events
     ↓
Businesses
     ↓
Creators
```

Possible future product:

> "Create beautiful personalized experiences without knowing how to build websites."

That is a much larger market than birthdays alone.

---

# 63. Admin Dashboard — Future

Create later.

Features:

```text
users
surprises
templates
reports
storage
AI usage
revenue
orders
analytics
moderation
```

Do NOT build this before the MVP unless necessary.

---

# 64. Admin Roles

Future:

```text
SUPER_ADMIN
ADMIN
MODERATOR
SUPPORT
TEMPLATE_MANAGER
```

Use role-based access control.

---

# 65. Future Custom Domain

Premium feature:

```text
ahmed.yourdomain.com
```

or:

```text
birthday.ahmed.com
```

This requires domain verification and DNS management.

Do not implement in MVP.

---

# 66. Future QR Code

Every surprise can generate:

```text
QR code
```

Useful for:

- birthday cards
- printed gifts
- parties
- wedding tables
- graduation
- physical gifts

Example:

```text
Scan to see your surprise ❤️
```

---

# 67. Future Physical Product Integration

Potential long-term business:

```text
Digital Surprise
+
Printed Card
+
QR Code
```

Example:

```text
Physical birthday card
       ↓
QR code
       ↓
Personalized digital experience
```

This could become a separate revenue stream.

---

# 68. Important Product Decision

The recipient experience should be:

> **No installation. No login. Open link and experience the surprise.**

This is a core product principle.

---

# 69. Claude Code Master Prompt

Use the following prompt when starting implementation with Claude Code.

---

## MASTER PROMPT

You are the lead software architect and senior full-stack engineer for a production-quality product called **Surprise Studio**.

Build the application according to the architecture in this `scratchpad.md`.

The product is a personalized digital-surprise platform.

A creator uses an Android Flutter app to create a personalized surprise for another person.

The creator enters recipient information, uploads photographs, chooses a template, customizes content, previews the result, publishes it, and receives a shareable URL.

The recipient does NOT need the mobile application. The URL opens a responsive Next.js web experience.

### Core architecture

```text
Flutter Android App
        ↓
NestJS TypeScript REST API
        ↓
PostgreSQL + Prisma
        ↓
S3-compatible Object Storage
        ↓
Next.js Public Experience
```

AI must be accessed through an abstraction layer.

---

## Technology requirements

Use:

- Flutter
- Dart
- Next.js
- TypeScript
- NestJS
- PostgreSQL
- Prisma
- S3-compatible object storage
- REST API
- Docker for local infrastructure
- GitHub Actions for CI
- an AI provider abstraction
- environment variables for secrets

Do not introduce unnecessary technologies.

---

# DEVELOPMENT RULES

### 1. Architecture first

Before writing substantial code:

1. inspect the repository
2. read `scratchpad.md`
3. identify existing code
4. create an implementation plan
5. identify dependencies
6. create the required directory structure
7. implement incrementally

Do not blindly overwrite existing files.

---

### 2. Production quality

Write:

- maintainable code
- modular code
- typed code
- validated inputs
- secure APIs
- clear naming
- meaningful errors
- reusable components

Avoid:

- giant files
- duplicated logic
- magic values
- hard-coded secrets
- unnecessary abstractions
- fake implementations presented as complete
- placeholder TODOs for critical functionality

---

### 3. Keep the MVP small

The first working version must contain:

```text
authentication
create surprise
recipient information
photo upload
template selection
preview
publish
public share URL
responsive public experience
```

Do not implement the entire future roadmap before the MVP works.

---

# BACKEND REQUIREMENTS

Create a NestJS backend.

Structure:

```text
src/
├── auth/
├── users/
├── surprises/
├── templates/
├── assets/
├── publishing/
├── analytics/
├── ai/
├── common/
├── config/
└── main.ts
```

Use:

- DTO validation
- Prisma
- authentication guards
- authorization
- structured errors
- logging
- configuration service

All protected resources must verify ownership.

Never trust a client-supplied user ID.

---

# DATABASE

Create Prisma models for:

```text
User
Surprise
Asset
Template
Event
```

Support:

```text
draft
published
archived
deleted
```

Use migrations.

Never modify production schema manually without migrations.

---

# AUTHENTICATION

Implement:

```text
register
login
refresh
logout
me
```

Use secure password hashing if password authentication is implemented.

Use short-lived access tokens and refresh-token rotation.

Never store raw passwords.

Never log authentication secrets.

---

# SURPRISE API

Implement:

```text
POST   /api/v1/surprises
GET    /api/v1/surprises
GET    /api/v1/surprises/:id
PATCH  /api/v1/surprises/:id
DELETE /api/v1/surprises/:id

POST /api/v1/surprises/:id/publish
POST /api/v1/surprises/:id/unpublish
```

---

# ASSET API

Implement secure upload flow.

Preferred:

```text
client
 ↓
request signed upload URL
 ↓
upload directly to storage
 ↓
notify backend
 ↓
backend validates/registers asset
```

Do not route large image files unnecessarily through the API server.

Validate:

- MIME
- file size
- image dimensions
- file signature

Support:

```text
JPEG
PNG
WebP
```

---

# TEMPLATE SYSTEM

Templates must be data-driven.

Implement:

```text
Template
TemplateSection
Theme
```

The web renderer receives:

```text
template
+
surprise
+
assets
+
theme
```

Do not hard-code recipient information inside template components.

Create at least four templates:

```text
cinematic
cute
memories
luxury
```

---

# WEB EXPERIENCE

Use Next.js.

Public route:

```text
/s/[slug]
```

Example:

```text
https://yourdomain.com/s/a8Kp3xQz
```

The page must:

- be responsive
- work on mobile
- work on desktop
- load optimized images
- support animations
- support reduced motion
- provide Open Graph metadata
- handle invalid/expired links gracefully

The recipient should not need an account.

---

# FLUTTER APP

Create feature-based architecture.

```text
lib/
├── app/
├── core/
├── features/
│   ├── auth/
│   ├── home/
│   ├── create_surprise/
│   ├── templates/
│   ├── editor/
│   ├── preview/
│   ├── publishing/
│   ├── surprises/
│   └── settings/
└── services/
```

Implement:

```text
Onboarding
Login/Register
Home
Create Surprise
Occasion Selection
Recipient Information
Photo Upload
Template Selection
Customization
Preview
Publish
Share
Saved Surprises
Settings
```

Use clean state management.

Do not place all state inside one widget.

---

# DESIGN SYSTEM

Create reusable design tokens:

```text
colors
typography
spacing
radius
shadows
animation
```

The application should feel:

- premium
- modern
- emotional
- simple
- fast

Avoid generic dashboard styling.

The creator should feel like they are creating a gift, not filling out a database form.

---

# UX

The main creation flow should be:

```text
Create
 ↓
Who is it for?
 ↓
Tell us about them
 ↓
Add memories
 ↓
Choose a style
 ↓
Preview
 ↓
Publish
 ↓
Share
```

Use progressive disclosure.

Do not ask 20 questions on one screen.

---

# AI

Create:

```text
AIService
AIProvider
```

Methods:

```text
generateMessage()
generateCaptions()
generateStory()
```

AI must never be required for basic product functionality.

AI output must be editable before publishing.

Track AI usage.

Implement usage limits.

---

# ANALYTICS

Implement events:

```text
app_opened
create_started
surprise_created
template_selected
photo_uploaded
preview_opened
surprise_published
share_clicked
public_page_opened
purchase_started
purchase_completed
```

Avoid unnecessary personal data.

---

# SECURITY

Implement:

```text
HTTPS
CORS
rate limiting
input validation
authorization
secure upload
file validation
secret management
sanitized public DTOs
```

Public endpoints must expose only intended data.

Never expose:

```text
database IDs unnecessarily
user email
tokens
storage credentials
internal metadata
```

---

# PERFORMANCE

Optimize:

```text
images
fonts
JavaScript
animations
API calls
database queries
```

Use lazy loading.

Do not load every photo at full resolution.

Use responsive image sizes.

---

# ERROR HANDLING

Use consistent API responses.

Example:

```json
{
  "success": false,
  "error": {
    "code": "SURPRISE_NOT_FOUND",
    "message": "Surprise not found"
  }
}
```

Never return stack traces to clients.

---

# TESTING

Write tests for:

### Backend

- authentication
- permissions
- surprise creation
- publishing
- templates
- asset validation

### Web

- public route
- template rendering
- invalid slug
- responsive rendering

### Flutter

- form validation
- navigation
- API state
- upload flow

### E2E

Test:

```text
register
→ create surprise
→ upload photo
→ choose template
→ preview
→ publish
→ open public URL
```

---

# LOCAL DEVELOPMENT

Provide:

```text
.env.example
docker-compose.yml
README.md
```

Document:

```text
install
environment setup
database setup
migration
development
testing
production build
```

---

# ENVIRONMENT VARIABLES

Use placeholders:

```env
DATABASE_URL=
JWT_SECRET=
JWT_REFRESH_SECRET=

STORAGE_ENDPOINT=
STORAGE_BUCKET=
STORAGE_ACCESS_KEY=
STORAGE_SECRET_KEY=

AI_PROVIDER=
AI_API_KEY=

NEXT_PUBLIC_API_URL=
```

Never commit real values.

---

# CI/CD

Create GitHub Actions for:

```text
lint
typecheck
test
build
```

Do not automatically deploy to production until the repository is stable.

---

# IMPLEMENTATION ORDER

Follow this order:

## Phase 1

Repository structure.

## Phase 2

Database + Prisma.

## Phase 3

Authentication.

## Phase 4

Surprise CRUD.

## Phase 5

Storage/upload.

## Phase 6

Template system.

## Phase 7

Public Next.js experience.

## Phase 8

Flutter creator flow.

## Phase 9

Preview and publishing.

## Phase 10

Analytics.

## Phase 11

AI abstraction.

## Phase 12

Testing.

## Phase 13

Security review.

## Phase 14

Performance review.

## Phase 15

Deployment documentation.

---

# IMPORTANT CLAUDE CODE BEHAVIOR

Do not attempt to generate the entire application in one enormous operation.

Work phase by phase.

After each major phase:

1. run tests
2. run lint
3. run type checks
4. verify build
5. inspect changed files
6. report what was completed
7. identify remaining work

If an external credential is required, do not invent one.

If a service requires configuration, create `.env.example` and clearly document the required value.

If a decision is ambiguous, choose the simplest production-safe option and document the decision.

Do not add dependencies unless they solve a real problem.

---

# DEFINITION OF DONE

The MVP is complete only when:

```text
[ ] User can register/login
[ ] User can create a surprise
[ ] User can enter recipient information
[ ] User can upload photos
[ ] User can select a template
[ ] User can preview
[ ] User can publish
[ ] Backend generates unique public slug
[ ] Public URL works without login
[ ] Public page renders correctly on mobile
[ ] Public page renders correctly on desktop
[ ] Photos are optimized
[ ] Authorization works
[ ] Invalid URLs are handled
[ ] Basic analytics work
[ ] Tests pass
[ ] Production build succeeds
[ ] Secrets are not committed
[ ] README explains setup
[ ] Deployment documentation exists
```

---

# 70. DEVELOPMENT ROADMAP

## Version 0.1 — Proof of Concept

```text
1 template
static/mock data
basic public page
```

Goal:

> Prove the visual experience.

## Version 0.2 — Technical MVP

```text
backend
database
upload
4 templates
publishing
share URL
```

Goal:

> Prove the complete creation pipeline.

## Version 0.3 — Public MVP

```text
authentication
analytics
AI messages
polish
security
```

Goal:

> Give it to real users.

## Version 0.4 — Monetization

```text
premium templates
payments
ads
entitlements
```

## Version 1.0

```text
multiple occasions
AI story generation
advanced templates
viral loop
referrals
```

---

# 71. Final Product Architecture

```text
                         SURPRISE STUDIO
                               │
             ┌─────────────────┴─────────────────┐
             │                                   │
        CREATOR SIDE                         RECIPIENT SIDE
             │                                   │
       Flutter Android                       Web Browser
             │                                   │
             └────────────────┬──────────────────┘
                              │
                         REST API
                              │
                ┌─────────────┼─────────────┐
                │             │             │
               Auth        Surprise       AI
                │             │             │
                └─────────────┼─────────────┘
                              │
                        PostgreSQL
                              │
                      Object Storage
                              │
                         CDN / Web
```

---

# 72. Product North Star

The final experience should feel like:

> "Someone made this specifically for me."

Not:

> "Someone filled out a birthday form."

The technology should remain invisible.

The emotion and surprise are the product.

---

# 73. First Build Target

Do NOT start by implementing every feature.

Start with this exact vertical slice:

```text
Flutter
  ↓
Create Birthday Surprise
  ↓
Enter Name
  ↓
Upload 3 Photos
  ↓
Choose Cinematic Template
  ↓
Preview
  ↓
Backend
  ↓
Publish
  ↓
Generate /s/random-slug
  ↓
Next.js public page
  ↓
Open link on phone
```

Once this complete vertical slice works end-to-end, expand the system.

---

# 74. Final instruction to Claude

Treat this document as the product architecture and source of truth.

However, verify every implementation detail against the actual repository before changing files.

Do not blindly follow an outdated assumption if the existing codebase provides a better compatible implementation.

Prioritize:

1. correctness
2. security
3. maintainability
4. performance
5. user experience
6. scalability
7. development speed

Build the smallest complete version first.

Do not over-engineer the MVP.

Do not sacrifice architecture quality merely to make a demo.

The goal is to create a real product that can eventually be published on Google Play and used by real people.
