# TODO

Phases follow the demand validation sequence (Stage 0 → 5).
Feature priority labels: `[MUST]` `[SHOULD]` `[NICE]`

Progress states: `[ ]` not started · `[~]` in progress · `[x]` done

---

## Pre-Phase: Repository and Tooling Bootstrap

> Gate: nothing else starts until this block is complete.

- [ ] Initialize Cargo workspace with crate structure (`api`, `core`, `db`, `search`, `notifications`)
- [ ] Initialize SvelteKit frontend with pnpm (`frontend/`)
- [ ] Configure `rustfmt` and `clippy` (deny warnings in CI)
- [ ] Configure `eslint` + `prettier` for TypeScript
- [ ] Set up `sqlx` with offline mode (compiled query checking)
- [ ] Write initial `docker-compose.yml` (postgres, redis, meilisearch, caddy)
- [ ] Write `.env.example` with all required variables documented
- [ ] Set up GitHub Actions CI: `cargo test`, `cargo clippy`, `cargo audit`, `pnpm test`, `pnpm audit`
- [ ] Write first migration: `CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`
- [ ] Confirm `docker compose up` reaches a healthy state with empty DB

---

## Phase 0 — MVP: Core Architecture Validation

**Goal:** A working instance where a single community can post and read messages in topic-organized streams with full-history search and no presence indicators.

**Gate to Phase 1:** 3–5 real communities actively using daily for 30 consecutive days. At least one community migrated from Slack or Discord.

---

### 0.1 Identity and Auth `[MUST]`

- [ ] `users` table migration + indexes
- [ ] `spaces` table migration
- [ ] `memberships` table migration
- [ ] `POST /auth/register` — email + password, Argon2id hash
- [ ] `POST /auth/login` — returns JWT (15 min) + sets httpOnly refresh cookie (30 days)
- [ ] `POST /auth/refresh` — validates refresh token, issues new access JWT
- [ ] `POST /auth/logout` — invalidates refresh token in Redis
- [ ] Auth middleware for Axum: extract and validate JWT on protected routes
- [ ] Rate limiting on all auth endpoints (10 req/min per IP)
- [ ] Input validation: email format, password minimum entropy, username charset

### 0.2 Spaces `[MUST]`

- [ ] `POST /spaces` — create a space
- [ ] `GET /spaces/:slug` — public space metadata (no auth required for public spaces)
- [ ] `POST /spaces/:slug/join` — authenticated user joins space
- [ ] `GET /spaces/:slug/members` — list members with roles
- [ ] Space slug uniqueness enforced at DB level + application level

### 0.3 Streams `[MUST]`

- [ ] `streams` table migration
- [ ] `POST /spaces/:slug/streams` — create stream (admin/owner only)
- [ ] `GET /spaces/:slug/streams` — list all streams user can see
- [ ] Stream visibility enforcement: private streams filtered at query level by membership
- [ ] `PATCH /spaces/:slug/streams/:id` — rename, change description (admin only)

### 0.4 Topics — First-Class Entities `[MUST]`

- [ ] `topics` table migration + indexes (`stream_id, last_active DESC`)
- [ ] Topics are rows — never just a text field on messages
- [ ] `POST /streams/:id/topics` — create topic with name
- [ ] `GET /streams/:id/topics` — list topics ordered by `last_active DESC`
- [ ] `PATCH /topics/:id` — rename topic (any member, not just admin)
- [ ] `PATCH /topics/:id/status` — set `open` | `resolved` | `archived`
- [ ] `last_active` updated on every message insert (DB trigger or application layer)
- [ ] Topic name autocomplete endpoint: `GET /streams/:id/topics?q=` — feeds the compose input

### 0.5 Messages `[MUST]`

- [ ] `messages` table migration + indexes (`topic_id, created_at`)
- [ ] `POST /topics/:id/messages` — post message, requires authenticated user
- [ ] `GET /topics/:id/messages` — paginated, cursor-based, oldest-first within topic
- [ ] `PATCH /messages/:id` — edit (own messages only), sets `edited_at`
- [ ] `DELETE /messages/:id` — soft delete (sets `deleted_at`), never hard-deletes
- [ ] Message content: Markdown input, server-side render to HTML (stored in `rendered`)
- [ ] Enforce: a message without a `topic_id` is rejected — no orphaned messages ever
- [ ] Enforce: posting to an archived topic is rejected

### 0.6 WebSocket Real-Time `[MUST]`

- [ ] WS upgrade endpoint: `GET /ws` — authenticated, long-lived connection
- [ ] On connect: client sends `{type: "subscribe", space_ids: [...]}` 
- [ ] Server subscribes to Redis channels for all spaces user is a member of
- [ ] On new message: push `{type: "message", payload: MessageDTO}` to all subscribers of that topic's space
- [ ] On topic status change: push `{type: "topic_updated", payload: TopicDTO}`
- [ ] On disconnect: unsubscribe from Redis channels, clean up connection state
- [ ] Reconnect protocol: client sends `{type: "catch_up", last_seen: {topic_id: message_id}}`, server returns missed messages per topic
- [ ] Heartbeat: server sends `{type: "ping"}` every 30s, client responds `{type: "pong"}` — close if no pong within 10s

### 0.7 Per-Topic Read State `[MUST]`

- [ ] `read_positions` table migration
- [ ] `POST /topics/:id/read` — update `last_read_message_id` for current user
- [ ] `GET /spaces/:slug/unread` — returns per-topic unread counts for current user across all streams in a space
- [ ] Unread count = messages after `last_read_message_id` in that topic
- [ ] Topics with `muted: true` excluded from unread counts
- [ ] `POST /topics/:id/mute` and `DELETE /topics/:id/mute` — per-user topic muting
- [ ] WS: push `{type: "read_position_updated"}` to other connected clients of same user (multi-tab sync)

### 0.8 No Presence by Default `[MUST]`

- [ ] No `last_seen` exposed to other users unless explicitly opted in
- [ ] No online/offline indicator shown in UI by default
- [ ] No read receipts visible to message senders
- [ ] If user opts in: `PATCH /users/me/settings` sets `show_presence: true`
- [ ] Presence data stored in Redis with 60s TTL — never persisted to PostgreSQL

### 0.9 Search `[MUST]`

- [ ] Meilisearch index: `messages` — searchable fields, filterable fields, ranking defined
- [ ] Async indexer: every new message enqueued for indexing after PostgreSQL write
- [ ] `GET /spaces/:slug/search?q=&stream_id=&topic_id=&author_id=&before=&after=` — scoped, filtered search
- [ ] Membership filter applied at query time: user only sees results from accessible streams
- [ ] No message expiry in search index — full history always searchable
- [ ] Reindex utility: `cargo run --bin reindex -- --space [slug]` — rebuilds from PostgreSQL

### 0.10 Public Read Access Without Join `[MUST]`

- [ ] Public spaces: unauthenticated `GET /spaces/:slug/streams` returns stream list
- [ ] Public spaces: unauthenticated `GET /topics/:id/messages` returns full topic history
- [ ] Private spaces: all endpoints require auth + membership
- [ ] Read-only UI route: `/s/:slug` renders without requiring login for public spaces

### 0.11 New Member Onboarding Digest `[MUST]`

- [ ] On join, system generates a "welcome digest" of recent topics per stream
- [ ] Digest = topics with status `open` + highest message count in last 30 days
- [ ] Delivered as an in-app notification linking to each topic (not email at Phase 0)
- [ ] Configurable depth: user can request 7 / 30 / all-time history digest

### 0.12 Frontend: Phase 0 Views `[MUST]`

- [ ] Auth pages: `/login`, `/register`
- [ ] Space shell: `/s/:slug` — stream list sidebar + main content area
- [ ] Stream view: `/s/:slug/streams/:stream_id` — topic list, sorted by `last_active`
- [ ] Topic view: `/s/:slug/streams/:stream_id/topics/:topic_id` — message feed + compose
- [ ] Compose box: enforces topic selection before send — no topic, no send
- [ ] Topic autocomplete in compose: `GET /streams/:id/topics?q=`
- [ ] Per-topic unread badges in stream sidebar
- [ ] Catch-up queue: button "X unread topics" → opens ordered list of unread topics, navigable with keyboard
- [ ] Topic status badge (open / resolved / archived) visible in topic list
- [ ] Mark topic read button (explicit, not just on scroll)
- [ ] Search bar: scoped to current space, uses Meilisearch endpoint
- [ ] Settings page: `show_presence` toggle, notification defaults

---

## Phase 1 — First Retention Features

**Goal:** Reduce churn from the three documented drop-off causes: multi-community fatigue, no lurker UX, no neurodivergent accommodation.

**Gate to Phase 2:** Retained communities report at least one of: (a) migrated knowledge from old platform, (b) onboarded a new member who stayed active 14+ days, (c) a user reports using it across 3+ communities.

---

### 1.1 Unified Inbox — Context Multiplexer `[SHOULD]`

- [ ] `/inbox` route: all mentions + keyword alerts from all joined spaces, chronological
- [ ] Filters: by space, by type (mention / keyword / reply)
- [ ] Mark individual notifications read without visiting the topic
- [ ] Keyboard shortcut: `G I` → go to inbox from anywhere
- [ ] Unread badge in global nav showing total cross-community unread mentions

### 1.2 Topic Summary Card `[SHOULD]`

- [ ] Summary card visible at topic header before reading thread
- [ ] Phase 1: manually authored — any member can write/edit via `PATCH /topics/:id/summary`
- [ ] Rendered Markdown, pinned above message feed
- [ ] Phase 2+: AI-generated summary as default if no manual summary exists

### 1.3 Topic Status Flags — Full Implementation `[SHOULD]`

- [ ] `open` / `resolved` / `archived` already in DB from Phase 0
- [ ] UI: status change control in topic header (any member, not admin-only)
- [ ] Resolved topics: visually distinct (muted) in topic list, still searchable
- [ ] Archived topics: hidden from default topic list, accessible via filter
- [ ] `GET /streams/:id/topics?status=resolved` — filtered list endpoint

### 1.4 Anonymous Reactions `[SHOULD]`

- [ ] `topic_reactions` table: `(topic_id, user_id, emoji)` — not per-message
- [ ] Topic-level reactions: acknowledge without replying — serves lurkers
- [ ] Anonymous mode: reaction count shown, individual reactors hidden (space-level setting)
- [ ] Per-message reactions as well (standard emoji picker, message-level)

### 1.5 Read-Mode UI `[SHOULD]`

- [ ] Toggle: hides compose box, notification badges, sidebar
- [ ] Shows: messages, topic header, summary card, reactions
- [ ] Keyboard shortcut: `R` in topic view → toggle read mode
- [ ] Persisted per-user in settings

### 1.6 Notification Scheduling `[SHOULD]`

- [ ] UI for setting "available windows" (days of week + time ranges per timezone)
- [ ] Outside window: all notifications suppressed except `@here` and `@everyone`
- [ ] Digest delivery: configurable schedule (every 4h / daily at 9am / weekly)
- [ ] `notification_preferences` + `keyword_alerts` full UI — not just API

### 1.7 Focus Mode `[SHOULD]`

- [ ] Hides all streams/topics except the currently active one
- [ ] No sidebar, no badge counts, no activity indicators
- [ ] Toggle: button in nav + keyboard shortcut `F`
- [ ] Automatically deactivates when navigating to a different space

### 1.8 Draft Autosave `[SHOULD]`

- [ ] Compose box content saved to `localStorage` keyed by `topic_id`
- [ ] Draft restored on return to topic
- [ ] Draft discarded on send or explicit discard
- [ ] No server-side draft storage at Phase 1 — local only is sufficient

### 1.9 OAuth2 Login `[SHOULD]`

- [ ] GitHub OAuth2 — critical for open source community adoption
- [ ] Google OAuth2 — expands addressable market to research/academic users
- [ ] Link OAuth identity to existing account by email match
- [ ] `oauth_identities` table: `(user_id, provider, provider_user_id)`

### 1.10 Accessibility — Neurodivergent Baseline `[SHOULD]`

- [ ] High-contrast mode (CSS custom properties, toggled via settings)
- [ ] Reduced-motion mode (respects `prefers-reduced-motion`, also manual toggle)
- [ ] Full keyboard navigation: every action reachable without mouse
- [ ] Published keyboard shortcut map (`?` → shortcut overlay)
- [ ] No animations on message arrival by default — opt-in only
- [ ] ARIA labels on all interactive elements (screen reader baseline)

### 1.11 Member Tenure Signal `[SHOULD]`

- [ ] `joined_at` from `memberships` shown on member profile (factual, not gamified)
- [ ] Contribution count per stream: message count per `(user_id, stream_id)` — shown on profile
- [ ] No badges, levels, XP, or streak mechanics — ever

### 1.12 Data Export `[SHOULD]`

- [ ] `GET /spaces/:slug/export` — space owner / admin only
- [ ] Format: JSON (full fidelity) + Markdown (human readable)
- [ ] Includes: all streams, topics, messages, member list
- [ ] Rate limited: max once per 24h per space
- [ ] Required for trust with self-hosting target segment

---

## Phase 2 — Differentiation Compounds

**Goal:** Activate the features that make the product structurally irreplaceable — expertise surfaces, SEO-indexable public streams, self-hosting, AI acceleration of structure.

**Gate to Phase 3:** At least one community reports "we couldn't go back — our knowledge is here."

---

### 2.1 Expertise Map `[SHOULD]`

- [ ] Per-community graph: top contributors per topic cluster (computed from message counts + topic name similarity)
- [ ] "Ask an expert" routing: tag topic with a domain tag → system suggests members with highest contribution in that domain
- [ ] Visible at `/s/:slug/experts` — community knowledge map
- [ ] No external ranking, no gamification — contribution data only

### 2.2 SEO-Indexable Public Streams `[SHOULD]`

- [ ] Public space topics: rendered as static HTML with proper `<title>`, `<meta description>`, canonical URLs
- [ ] Server-side rendering for public routes (SvelteKit SSR already supports this)
- [ ] `robots.txt` allows indexing of public spaces, blocks private
- [ ] Sitemap generation: `/s/:slug/sitemap.xml` for public streams + topics
- [ ] This directly solves the Discord black hole problem — knowledge becomes discoverable

### 2.3 Self-Hosting Documentation `[SHOULD]`

- [ ] `docs/self-hosting.md` — full installation guide: prerequisites, config, first run
- [ ] `docs/upgrade.md` — migration procedure between versions
- [ ] `docs/backup.md` — PostgreSQL dump procedure, volume backup
- [ ] Tested on: Ubuntu 24.04 LTS, Debian 12, generic VPS with 1GB RAM minimum
- [ ] Published Docker image to GHCR: `ghcr.io/pebesen/pebesen:latest`

### 2.4 AI Topic Summaries `[NICE]`

- [ ] Background job: topics with 20+ messages and no manual summary → auto-generate summary
- [ ] Model: configurable (default: local Ollama if self-hosted, Anthropic API if cloud)
- [ ] Stored as `topics.ai_summary` — separate field from manual `topics.summary`
- [ ] Manual summary always takes precedence in display
- [ ] Can be disabled entirely per space by admin

### 2.5 Smart Topic Name Suggestion `[NICE]`

- [ ] Compose box: when user types a message without selecting a topic, suggest topic names from message content
- [ ] Client-side heuristic first (keyword extraction from first 100 chars)
- [ ] Phase 3: server-side semantic similarity against existing topic names

### 2.6 E2E Encrypted DMs `[SHOULD]`

- [ ] Direct messages between two users: end-to-end encrypted
- [ ] Key exchange: X25519 (ECDH) — public keys stored server-side, private keys client-side only
- [ ] DMs are NOT searchable by server (by design — communicate this explicitly)
- [ ] DM history stored encrypted in PostgreSQL — server cannot read content

### 2.7 Verified Credential Badges `[NICE]`

- [ ] Optional, community-governed (not platform-governed)
- [ ] Space admin can define badge types (e.g. "Core Contributor", "Maintainer")
- [ ] Space admin awards badges to members
- [ ] Badges displayed on member profile within that space only
- [ ] No cross-space badge visibility — badges are not a reputation system

### 2.8 Mobile Web — Responsive Hardening `[SHOULD]`

- [ ] All Phase 0 + 1 views fully functional on mobile web (375px minimum)
- [ ] Compose box on mobile: topic autocomplete works via tap, not hover
- [ ] Swipe gesture: left on topic list item → mark read
- [ ] PWA manifest + service worker: installable on iOS/Android home screen

---

## Phase 3 — Network Effects

**Goal:** Cross-community discovery and developer ecosystem that creates compounding value.

**Gate:** No gate — continuous. These are growth levers, not survival features.

---

### 3.1 Public Community Directory `[NICE]`

- [ ] `/explore` — browsable directory of public spaces
- [ ] Filters: by topic domain, activity level, member count, language
- [ ] Each space card: name, description, top 3 active streams, member count
- [ ] Opt-in: spaces must explicitly list themselves (not automatic)

### 3.2 Cross-Community Semantic Search `[NICE]`

- [ ] "Find conversations similar to this topic" across all spaces user is a member of
- [ ] Semantic embedding index (Meilisearch vector search or pgvector)
- [ ] Scoped to user's memberships — no cross-space leakage

### 3.3 Bot / Webhook API `[NICE]`

- [ ] Inbound webhook: `POST /webhooks/:token` → posts message to configured topic
- [ ] Outbound webhook: on new message in configured stream → HTTP POST to external URL
- [ ] Bot user type: created by space admin, sends messages via API key
- [ ] Rate limited: 60 messages/minute per bot

### 3.4 MCP Connector `[NICE]`

- [ ] MCP server exposing: `post_message`, `list_topics`, `search_messages`, `get_topic_summary`
- [ ] Allows AI agents to participate in communities as first-class members
- [ ] Published to MCP registry
- [ ] Auth: same API key as bot users

### 3.5 Federation Research `[NICE]`

- [ ] Evaluate: ActivityPub vs Matrix bridge vs custom federation protocol
- [ ] Decision criteria: complexity cost vs addressable community gain
- [ ] No implementation until at least 3 community operators request it explicitly
- [ ] This is a research task, not a build task

---

## Permanent Backlog — Excluded by Design

These will not be built regardless of phase. Documented here to prevent scope drift.

| Feature | Reason Excluded |
|---|---|
| Gamification (XP, streaks, levels) | Directly harms neurodivergent users. Validated by research. |
| Algorithmic feed / recommended content | Contradicts async, low-pressure model |
| Ephemeral / disappearing messages in channels | Destroys institutional memory — antithesis of product |
| NFT / token-gating | Zero validated demand in target segments |
| Built-in project management (tasks, boards) | Scope creep. Integrate via webhook/bot instead |
| Public follower graph | Social pressure layer. Not community coherence. |
| Read receipts visible to sender | Anxiety-inducing. Documented harm. Default must be off. |
| Algorithmic notification ranking | Removes user control. Opposite of the product's values. |

---

## Open Questions (Unresolved, Need Data Before Deciding)

- [ ] **Pricing model**: seat-based (Slack model, penalizes lurkers) vs space-based vs usage-based vs pure open source + hosting revenue. Seat-based is ruled out — it structurally conflicts with the lurker-first design. Decision needed before Phase 2.
- [ ] **Mobile native app**: validate web retention in Phase 1 before committing to native. If DAU/MAU ratio on mobile web exceeds 40%, build native.
- [ ] **Message length limits**: no limit vs. practical limits (10,000 chars?). Long messages in topics may substitute for documentation — possibly desirable.
- [ ] **Space federation**: can a user in Space A see and reply to a topic in Space B without joining? Powerful for open source cross-project discussion. Complex. Evaluate in Phase 3.
- [ ] **Moderation tooling**: Phase 0 has admin roles. Full moderation (mute, ban, appeal, audit log) needs its own phase planning. Required before any public community launch.
