# Architecture

## Guiding Constraint

> Every architectural decision must be justifiable without AI.
> Structure produces coherence. AI accelerates it. AI is never the foundation.

If a feature only works because a model is doing the heavy lifting, it is not a structural feature — it is a demo.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Clients                              │
│         Web (SvelteKit)    Mobile (future)    API           │
└────────────────┬────────────────────────────────────────────┘
                 │  HTTPS / WebSocket
┌────────────────▼────────────────────────────────────────────┐
│                     Gateway (Axum)                          │
│   Auth Middleware   Rate Limiting   WebSocket Upgrade        │
└────┬───────────────────┬───────────────────┬────────────────┘
     │                   │                   │
┌────▼─────┐    ┌────────▼──────┐   ┌────────▼────────┐
│  REST    │    │  WS Handler   │   │  Search Proxy   │
│  API     │    │  (fan-out)    │   │  (Meilisearch)  │
└────┬─────┘    └────────┬──────┘   └─────────────────┘
     │                   │
┌────▼───────────────────▼────────────────────────────────────┐
│                    Core Services                            │
│   Identity   │   Stream/Topic   │   Notification   │  Auth  │
└────┬─────────────────┬──────────────────┬───────────────────┘
     │                 │                  │
┌────▼──────┐   ┌──────▼──────┐   ┌───────▼──────┐
│ PostgreSQL│   │    Redis    │   │ Meilisearch  │
│ (primary) │   │ (pubsub,    │   │ (full-text   │
│           │   │  sessions,  │   │  search)     │
│           │   │  presence)  │   │              │
└───────────┘   └─────────────┘   └──────────────┘
```

---

## Core Data Model

This is the load-bearing structure of the entire product. Every feature is downstream of this.

### Identity Layer

```sql
-- One account per human. Not per community.
users (
  id          UUID PRIMARY KEY,
  username    TEXT UNIQUE NOT NULL,       -- global handle
  display_name TEXT NOT NULL,
  email       TEXT UNIQUE NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL,
  settings    JSONB NOT NULL DEFAULT '{}'  -- notification prefs, focus mode, etc.
)

-- A community / organization / project
spaces (
  id          UUID PRIMARY KEY,
  slug        TEXT UNIQUE NOT NULL,       -- appname.com/s/rust-lang
  name        TEXT NOT NULL,
  description TEXT,
  visibility  TEXT NOT NULL              -- 'public' | 'private' | 'unlisted'
    CHECK (visibility IN ('public', 'private', 'unlisted')),
  created_at  TIMESTAMPTZ NOT NULL
)

-- Many-to-many: user joins spaces
memberships (
  user_id     UUID REFERENCES users(id),
  space_id    UUID REFERENCES spaces(id),
  role        TEXT NOT NULL DEFAULT 'member'
    CHECK (role IN ('owner', 'admin', 'member', 'guest')),
  joined_at   TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (user_id, space_id)
)
```

**Key decision:** `users` is global. `memberships` is the join. Slack's fatal flaw was inverting this — workspace-scoped identities, loosely bound by email. One account here means one notification inbox, one search surface, one preference set.

### Message Architecture

```sql
-- Channels within a space
streams (
  id          UUID PRIMARY KEY,
  space_id    UUID REFERENCES spaces(id) NOT NULL,
  name        TEXT NOT NULL,
  description TEXT,
  visibility  TEXT NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'private')),
  created_at  TIMESTAMPTZ NOT NULL,
  UNIQUE (space_id, name)
)

-- Topics within a stream — first-class entities, not metadata
topics (
  id          UUID PRIMARY KEY,
  stream_id   UUID REFERENCES streams(id) NOT NULL,
  name        TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'resolved', 'archived')),
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL,
  last_active TIMESTAMPTZ NOT NULL,
  UNIQUE (stream_id, name)
)

-- Messages belong to a topic. Always. No exceptions.
messages (
  id          UUID PRIMARY KEY,
  topic_id    UUID REFERENCES topics(id) NOT NULL,
  author_id   UUID REFERENCES users(id) NOT NULL,
  content     TEXT NOT NULL,
  rendered    TEXT,                      -- cached HTML render
  edited_at   TIMESTAMPTZ,
  deleted_at  TIMESTAMPTZ,              -- soft delete
  created_at  TIMESTAMPTZ NOT NULL
)

-- Index for fast topic-ordered retrieval
CREATE INDEX idx_messages_topic_time ON messages(topic_id, created_at);
CREATE INDEX idx_topics_stream_active ON topics(stream_id, last_active DESC);
```

**Key decision:** Topics are rows, not tags. They have status, timestamps, and IDs. This is what enables topic-level unread tracking, status flags, expert routing, and search filtering — none of which are possible if topics are just a text field on messages.

### Read State (Per-Topic, Not Per-Channel)

```sql
-- Tracks last-read position per user per topic
-- Not per stream — that is the Slack model and it does not scale
read_positions (
  user_id     UUID REFERENCES users(id),
  topic_id    UUID REFERENCES topics(id),
  last_read_message_id UUID REFERENCES messages(id),
  last_read_at TIMESTAMPTZ NOT NULL,
  muted       BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (user_id, topic_id)
)
```

**Key decision:** Read state at topic granularity means a user can mark "compilers stream" read while leaving "type system" stream unread. This is the concrete mechanism behind "read what you care about, skip the rest" — Zulip's most praised feature.

### Notification System

```sql
notification_preferences (
  user_id          UUID REFERENCES users(id),
  scope_type       TEXT NOT NULL   -- 'global' | 'space' | 'stream' | 'topic'
    CHECK (scope_type IN ('global', 'space', 'stream', 'topic')),
  scope_id         UUID,           -- NULL for global
  notify_on        TEXT[] NOT NULL -- ['mention', 'keyword', 'all', 'none']
    DEFAULT '{mention}',
  delivery_mode    TEXT NOT NULL   -- 'immediate' | 'digest' | 'muted'
    DEFAULT 'immediate',
  digest_schedule  TEXT,           -- cron expression for digest delivery
  PRIMARY KEY (user_id, scope_type, COALESCE(scope_id, '00000000-0000-0000-0000-000000000000'))
)

keyword_alerts (
  id          UUID PRIMARY KEY,
  user_id     UUID REFERENCES users(id) NOT NULL,
  space_id    UUID REFERENCES spaces(id),  -- NULL = all spaces
  keyword     TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL
)
```

---

## WebSocket Architecture

Real-time fan-out without a message broker dependency in Phase 0.

```
Client connects → WS upgrade → assigned to room(s) matching joined spaces/streams/topics

Message posted (REST or WS) →
  1. Write to PostgreSQL (durable)
  2. Publish to Redis channel: space:{space_id}:stream:{stream_id}:topic:{topic_id}
  3. Redis pub/sub fan-out to all connected clients subscribed to that topic
  4. Update Meilisearch index (async, non-blocking)
  5. Evaluate notification rules → queue push/email/digest

Client reconnects after gap →
  1. Sends last_seen_message_id
  2. Server returns missed messages per topic since that ID
  3. Client updates per-topic unread state
```

**Key decision:** Redis pub/sub handles fan-out. PostgreSQL is the source of truth. Meilisearch is a read-optimized replica for search. No single point of failure is the message store.

---

## Search Architecture

```
Meilisearch index: messages
  - Searchable fields: content, topic.name, stream.name, author.display_name
  - Filterable fields: space_id, stream_id, topic_id, author_id, created_at, topic.status
  - Ranking: exact match → recency → topic activity

Indexed on:
  - Every new message (async, <500ms latency acceptable)
  - Every topic name change
  - Every message edit

NOT indexed:
  - Private stream messages for users without membership
  - Deleted messages
```

Search is scoped by membership at query time — Meilisearch receives a filter `space_id IN [spaces_user_is_member_of]` on every query. No leakage of private content.

---

## Authentication

```
Phase 0: Email + password (Argon2id hashing)
         JWT access token (15 min) + refresh token (30 days, stored in httpOnly cookie)

Phase 1: OAuth2 (GitHub, Google) — critical for open source community adoption
         Magic link (email) — reduces friction for non-developer users

Phase 2: SAML/SSO — required for enterprise self-hosting segment
         Passkeys (WebAuthn) — future-proof, no password risk
```

**Key decision:** Session tokens are stored server-side in Redis with a reference in the httpOnly cookie. This allows instant revocation — important for the security-conscious self-hosting segment.

---

## Notification Delivery

```
Immediate:   WebSocket push (in-app, connected clients)
             Push notification (mobile — Phase 2)
Digest:      Email (SendGrid / Resend / self-hosted SMTP)
             Scheduled job (cron, per user's digest_schedule)
Batching:    Mentions in the same topic within 60s are collapsed into one notification
```

---

## Self-Hosting Architecture

Target: single `docker compose up` deploys a fully functional instance.

```yaml
# docker-compose.yml (simplified)
services:
  app:        # Rust binary (API + WS)
  frontend:   # SvelteKit static build served by Caddy
  postgres:   # PostgreSQL 16
  redis:      # Redis 7 (pubsub + session)
  meilisearch: # Meilisearch latest
  caddy:      # Reverse proxy + automatic TLS
```

Data volumes:
- `postgres_data` — all messages, users, structure
- `meilisearch_data` — search index (rebuilds from PG if lost)
- `uploads` — file attachments

Rebuild search index from PostgreSQL if Meilisearch data is lost: `cargo run --bin reindex`

---

## Frontend Architecture

```
SvelteKit (TypeScript, pnpm)
  src/
    routes/
      (auth)/          login, register, magic-link
      (app)/
        +layout.svelte  → global WS connection, unified inbox state
        [space]/        space shell + stream list
        [space]/[stream]/[topic]   message view + compose
        inbox/          cross-community unified view (Phase 1)
    lib/
      stores/
        connection.ts   WS state machine (connecting/connected/reconnecting)
        spaces.ts       all joined spaces + membership
        unread.ts       per-topic unread counts (the core UX state)
        identity.ts     current user
      components/
        Compose.svelte       topic-enforcing message input
        TopicList.svelte     stream sidebar with unread badges
        MessageFeed.svelte   virtualized message list
        CatchUpQueue.svelte  ordered unread topic queue (Phase 0)
        ReadMode.svelte      distraction-reduced content view (Phase 1)
```

**Key decision:** `unread.ts` is a derived store computed from `read_positions` synced on WebSocket connect. Unread counts are never polled — they are pushed. UI never goes stale.

---

## Explicit Non-Decisions (Deferred, Not Forgotten)

These are architectural questions not answered in Phase 0. Deciding them early without data would add accidental complexity.

| Question | Deferred Until |
|---|---|
| Federation (ActivityPub / Matrix bridge) | Phase 3 — needs user demand signal first |
| E2E encryption for channel messages | Phase 2 — DMs only first |
| Mobile native app (iOS / Android) | Phase 2 — validate web retention first |
| Horizontal scaling / multi-region | Phase 3 — premature before load data exists |
| AI summarization pipeline | Phase 2 — structure must work without it first |
| Plugin / extension system | Phase 3 — API-first, then extension surface |

---

## Security Baseline

All of these are required before any public deployment, regardless of phase:

- All inputs sanitized and validated at the Rust layer before reaching the DB
- SQL queries via `sqlx` with compile-time checked queries — no string interpolation
- Content Security Policy headers on all pages
- Rate limiting on all auth endpoints (login, register, magic link)
- CORS restricted to known origins
- File uploads: type validation, size limits, stored outside web root
- Dependency audit in CI: `cargo audit`, `pnpm audit`
- Secrets in environment variables only — no hardcoded credentials, ever

---

## File Structure

```
pebesen/
├── crates/
│   ├── api/            Axum HTTP + WebSocket handlers
│   ├── core/           Domain types, business logic (no I/O)
│   ├── db/             sqlx queries, migrations
│   ├── search/         Meilisearch client wrapper
│   ├── notifications/  Delivery pipeline (email, push, digest)
│   └── bin/
│       ├── server.rs   Main binary
│       └── reindex.rs  Search reindex utility
├── frontend/           SvelteKit app (pnpm)
│   ├── src/
│   ├── package.json
│   └── svelte.config.js
├── migrations/         PostgreSQL migrations (sqlx)
├── docker-compose.yml
├── .env.example
├── Cargo.toml          Workspace root
├── README.md
├── ARCHITECTURE.md
└── TODO.md
```
