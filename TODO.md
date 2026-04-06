# TODO

Phases follow the demand validation sequence (Stage 0 → 5).
Feature priority labels: `[MUST]` `[SHOULD]` `[NICE]`

Progress states: `[ ]` not started · `[~]` in progress · `[x]` done

---

## Pre-Phase: Repository and Tooling Bootstrap ✅

> Gate: nothing else starts until this block is complete.
>
> **Status: COMPLETED** - All tooling, workspace, and infrastructure setup is done.

### P.1 Rust Workspace

- [x] Create root `Cargo.toml` with `[workspace]` and `members` list
  - [x] Add member: `crates/api`
  - [x] Add member: `crates/core`
  - [x] Add member: `crates/db`
  - [x] Add member: `crates/search`
  - [x] Add member: `crates/notifications`
  - [x] Add member: `crates/bin`
- [x] Create each crate with `cargo new --lib` (except `bin`)
- [x] Add shared workspace dependencies in root `Cargo.toml` (`[workspace.dependencies]`)
  - [x] `tokio` with full features
  - [x] `axum` latest stable
  - [x] `sqlx` with `postgres`, `uuid`, `time`, `runtime-tokio` features
  - [x] `serde` + `serde_json`
  - [x] `tracing` + `tracing-subscriber`
  - [x] `uuid` with `v4`, `serde` features
  - [x] `argon2`
  - [x] `jsonwebtoken`
  - [x] `redis` async
- [x] Configure `rustfmt.toml` (edition 2024, max width 100)
- [x] Configure `clippy.toml` — add `#![deny(clippy::all)]` to each crate root
- [x] Confirm `cargo build` succeeds on empty crates

### P.2 Frontend

- [x] Scaffold SvelteKit app: `pnpm create svelte@latest frontend`
  - [x] Select: TypeScript, ESLint, Prettier, no Playwright (add later)
- [x] Configure `pnpm` workspace in root `pnpm-workspace.yaml`
- [x] Install base dependencies
  - [x] `@sveltejs/adapter-node` for server deployment
  - [x] `tailwindcss` + `@tailwindcss/typography`
  - [x] `svelte-check`
- [x] Configure `eslint.config.js` with TypeScript rules
- [x] Configure `prettier.config.js`
- [x] Confirm `pnpm dev` starts without errors

### P.3 Database Bootstrap

- [x] Write `docker-compose.yml`
  - [x] `postgres:16-alpine` service with named volume `postgres_data`
  - [x] `redis:7-alpine` service with named volume `redis_data`
  - [x] `getmeili/meilisearch:latest` service with named volume `meilisearch_data`
  - [x] `caddy:alpine` service with bind-mounted `Caddyfile`
  - [x] `app` service (commented out — added in Phase 0 build)
  - [x] All services on shared `pebesen_net` bridge network
  - [x] Health checks on postgres and redis
- [x] Write `.env.example` with all variables and inline comments
  - [x] `DATABASE_URL`
  - [x] `REDIS_URL`
  - [x] `MEILISEARCH_URL` + `MEILISEARCH_MASTER_KEY`
  - [x] `JWT_SECRET` (min 64 chars)
  - [x] `JWT_ACCESS_TTL_SECONDS` (default 900)
  - [x] `JWT_REFRESH_TTL_SECONDS` (default 2592000)
  - [x] `SERVER_HOST` + `SERVER_PORT`
  - [x] `FRONTEND_URL` (for CORS)
- [x] Write first migration `migrations/0001_extensions.sql`
  - [x] `CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`
  - [x] `CREATE EXTENSION IF NOT EXISTS "pg_trgm"`
- [x] Confirm `sqlx migrate run` succeeds against fresh DB

### P.4 CI Pipeline

- [x] Create `.github/workflows/ci.yml`
  - [x] Trigger: push to `main`, all PRs
  - [x] Job: `rust`
    - [x] `cargo fmt --check`
    - [x] `cargo clippy -- -D warnings`
    - [x] `cargo test --all`
    - [x] `cargo audit`
    - [x] Cache: `~/.cargo/registry`, `target/`
  - [x] Job: `frontend`
    - [x] `pnpm install --frozen-lockfile`
    - [x] `pnpm lint`
    - [x] `pnpm check`
    - [x] `pnpm test`
    - [x] `pnpm audit`
  - [x] Job: `docker`
    - [x] `docker compose config`
    - [x] `docker compose up -d --wait`
    - [x] `docker compose down`
- [x] Confirm all CI jobs pass on an empty commit

### P.5 Developer Experience

- [x] Write root `Makefile`
  - [x] `make dev` — starts docker compose + cargo watch + pnpm dev
  - [x] `make migrate` — runs sqlx migrations
  - [x] `make test` — runs cargo test + pnpm test
  - [x] `make lint` — runs clippy + eslint
  - [x] `make reindex` — runs reindex binary
- [x] Write `CONTRIBUTING.md` — setup steps, branch naming, PR checklist
- [x] Write `.gitignore` — covers Rust, Node, env files, IDE dirs

---

## Phase 0 — MVP: Core Architecture Validation

**Goal:** A working instance where a single community can post and read messages in topic-organized streams with full-history search and no presence indicators.

**Gate to Phase 1:** 3–5 real communities actively using daily for 30 consecutive days. At least one community migrated from an existing platform.

---

### 0.1 Identity and Auth `[MUST]`

#### 0.1.1 Database Migrations

- [ ] Write migration `0002_users.sql`
  - [ ] `users` table: `id UUID`, `username TEXT UNIQUE`, `display_name TEXT`, `email TEXT UNIQUE`, `password_hash TEXT`, `created_at TIMESTAMPTZ`, `settings JSONB DEFAULT '{}'`
  - [ ] Index: `CREATE UNIQUE INDEX idx_users_email ON users(lower(email))`
  - [ ] Index: `CREATE UNIQUE INDEX idx_users_username ON users(lower(username))`
- [ ] Write migration `0003_spaces.sql`
  - [ ] `spaces` table: `id UUID`, `slug TEXT UNIQUE`, `name TEXT`, `description TEXT`, `visibility TEXT CHECK(...)`, `created_at TIMESTAMPTZ`
  - [ ] Index: `CREATE UNIQUE INDEX idx_spaces_slug ON spaces(lower(slug))`
- [ ] Write migration `0004_memberships.sql`
  - [ ] `memberships` table: `user_id UUID REFERENCES users`, `space_id UUID REFERENCES spaces`, `role TEXT CHECK(...)`, `joined_at TIMESTAMPTZ`, `PRIMARY KEY (user_id, space_id)`
  - [ ] Index: `CREATE INDEX idx_memberships_space ON memberships(space_id)`

#### 0.1.2 Core Domain Types (`crates/core`)

- [ ] Define `User` struct with `serde` derives
- [ ] Define `Space` struct
- [ ] Define `Membership` struct
- [ ] Define `Role` enum: `Owner`, `Admin`, `Member`, `Guest`
- [ ] Define `AuthClaims` struct for JWT payload
- [ ] Define `AppError` enum implementing `axum::response::IntoResponse`
  - [ ] Variants: `Unauthorized`, `Forbidden`, `NotFound`, `Conflict`, `BadRequest`, `Internal`

#### 0.1.3 DB Queries (`crates/db`)

- [ ] `users::insert(pool, email, username, display_name, password_hash) -> User`
- [ ] `users::find_by_email(pool, email) -> Option<User>`
- [ ] `users::find_by_id(pool, id) -> Option<User>`
- [ ] `users::find_by_username(pool, username) -> Option<User>`
- [ ] `spaces::insert(pool, slug, name, visibility) -> Space`
- [ ] `spaces::find_by_slug(pool, slug) -> Option<Space>`
- [ ] `memberships::insert(pool, user_id, space_id, role) -> Membership`
- [ ] `memberships::find(pool, user_id, space_id) -> Option<Membership>`
- [ ] `memberships::list_by_space(pool, space_id) -> Vec<(User, Membership)>`

#### 0.1.4 Auth Handlers (`crates/api`)

- [ ] `POST /auth/register`
  - [ ] Validate email format (regex)
  - [ ] Validate username: 3–32 chars, alphanumeric + underscore + hyphen
  - [ ] Validate password: minimum 8 chars, at least one non-alpha char
  - [ ] Check email uniqueness — return `409 Conflict` if taken
  - [ ] Check username uniqueness — return `409 Conflict` if taken
  - [ ] Hash password with Argon2id (memory: 64MB, iterations: 3, parallelism: 4)
  - [ ] Insert user row
  - [ ] Return `201` with `UserDTO` (no password hash)
- [ ] `POST /auth/login`
  - [ ] Look up user by email
  - [ ] Verify password with Argon2id — constant-time comparison
  - [ ] On failure: return `401` with generic message (no user enumeration)
  - [ ] On success: generate access JWT (15 min, signed with `JWT_SECRET`)
  - [ ] Generate refresh token (UUID v4, stored in Redis with TTL 30 days)
  - [ ] Set refresh token as `httpOnly; Secure; SameSite=Strict` cookie
  - [ ] Return `200` with access token in response body
- [ ] `POST /auth/refresh`
  - [ ] Read refresh token from cookie
  - [ ] Look up token in Redis — return `401` if missing/expired
  - [ ] Generate new access JWT
  - [ ] Rotate refresh token (delete old, insert new) — prevent replay
  - [ ] Return `200` with new access token
- [ ] `POST /auth/logout`
  - [ ] Read refresh token from cookie
  - [ ] Delete from Redis
  - [ ] Clear cookie (set Max-Age=0)
  - [ ] Return `204`

#### 0.1.5 Auth Middleware

- [ ] Implement Axum `FromRequestParts` extractor `AuthUser`
  - [ ] Extract `Authorization: Bearer <token>` header
  - [ ] Decode and validate JWT signature + expiry
  - [ ] Load user from DB (or short-lived cache)
  - [ ] Return `AuthUser { id, username, email }` or `401`
- [ ] Implement `OptionalAuthUser` extractor (returns `Option<AuthUser>`)

#### 0.1.6 Rate Limiting

- [ ] Add `tower_governor` middleware
- [ ] Apply to: `/auth/register`, `/auth/login`, `/auth/refresh`
- [ ] Limit: 10 requests per minute per IP per endpoint
- [ ] Return `429 Too Many Requests` with `Retry-After` header on breach

---

### 0.2 Spaces `[MUST]`

#### 0.2.1 Handlers

- [ ] `POST /spaces`
  - [ ] Require auth
  - [ ] Validate slug: 3–48 chars, lowercase alphanumeric + hyphen, no leading/trailing hyphen
  - [ ] Validate name: 1–64 chars
  - [ ] Check slug uniqueness — return `409` if taken
  - [ ] Insert space row
  - [ ] Insert membership row for creator with role `owner`
  - [ ] Return `201` with `SpaceDTO`
- [ ] `GET /spaces/:slug`
  - [ ] Public spaces: no auth required
  - [ ] Private spaces: require auth + membership
  - [ ] Return `SpaceDTO` with member count
  - [ ] Return `404` if not found, `403` if private and not member
- [ ] `POST /spaces/:slug/join`
  - [ ] Require auth
  - [ ] Return `403` if space is private
  - [ ] Return `409` if already a member
  - [ ] Insert membership with role `member`
  - [ ] Return `201` with `MembershipDTO`
- [ ] `GET /spaces/:slug/members`
  - [ ] Require auth + membership
  - [ ] Return paginated list: `{ user: UserDTO, role, joined_at }`
  - [ ] Page size: 50, cursor-based

#### 0.2.2 DTOs

- [ ] Define `SpaceDTO`: `id`, `slug`, `name`, `description`, `visibility`, `member_count`, `created_at`
- [ ] Define `MembershipDTO`: `user_id`, `space_id`, `role`, `joined_at`

---

### 0.3 Streams `[MUST]`

#### 0.3.1 Migration

- [ ] Write migration `0005_streams.sql`
  - [ ] `streams` table: `id UUID`, `space_id UUID REFERENCES spaces`, `name TEXT`, `description TEXT`, `visibility TEXT DEFAULT 'public'`, `created_at TIMESTAMPTZ`
  - [ ] `UNIQUE (space_id, lower(name))`
  - [ ] Index: `CREATE INDEX idx_streams_space ON streams(space_id)`

#### 0.3.2 DB Queries

- [ ] `streams::insert(pool, space_id, name, description, visibility) -> Stream`
- [ ] `streams::find_by_id(pool, id) -> Option<Stream>`
- [ ] `streams::list_by_space(pool, space_id, user_id) -> Vec<Stream>`
  - [ ] Filter: include public streams + private streams where user has membership

#### 0.3.3 Handlers

- [ ] `POST /spaces/:slug/streams`
  - [ ] Require auth + role `admin` or `owner`
  - [ ] Validate name: 1–64 chars, no leading/trailing whitespace
  - [ ] Check name uniqueness within space (case-insensitive)
  - [ ] Return `201` with `StreamDTO`
- [ ] `GET /spaces/:slug/streams`
  - [ ] Public spaces: return public streams without auth
  - [ ] Authenticated: return public streams + private streams user is member of
  - [ ] Return ordered by `created_at ASC`
- [ ] `PATCH /spaces/:slug/streams/:id`
  - [ ] Require auth + role `admin` or `owner`
  - [ ] Allow updating: `name`, `description`, `visibility`
  - [ ] Re-validate name uniqueness if changed
  - [ ] Return `200` with updated `StreamDTO`

---

### 0.4 Topics — First-Class Entities `[MUST]`

#### 0.4.1 Migration

- [ ] Write migration `0006_topics.sql`
  - [ ] `topics` table: `id UUID`, `stream_id UUID REFERENCES streams`, `name TEXT`, `status TEXT DEFAULT 'open' CHECK(...)`, `created_by UUID REFERENCES users`, `created_at TIMESTAMPTZ`, `last_active TIMESTAMPTZ`
  - [ ] `UNIQUE (stream_id, lower(name))`
  - [ ] Index: `CREATE INDEX idx_topics_stream_active ON topics(stream_id, last_active DESC)`
  - [ ] Index: `CREATE INDEX idx_topics_stream_status ON topics(stream_id, status)`

#### 0.4.2 DB Queries

- [ ] `topics::insert(pool, stream_id, name, created_by) -> Topic`
- [ ] `topics::find_by_id(pool, id) -> Option<Topic>`
- [ ] `topics::list_by_stream(pool, stream_id, status_filter) -> Vec<Topic>`
- [ ] `topics::search_by_name_prefix(pool, stream_id, prefix) -> Vec<Topic>` (uses `pg_trgm`)
- [ ] `topics::update_last_active(pool, topic_id, timestamp)`
- [ ] `topics::set_status(pool, topic_id, status)`
- [ ] `topics::rename(pool, topic_id, new_name)`

#### 0.4.3 Handlers

- [ ] `POST /streams/:id/topics`
  - [ ] Require auth + space membership
  - [ ] Validate name: 1–128 chars
  - [ ] Check name uniqueness within stream (case-insensitive)
  - [ ] Set `last_active = NOW()`
  - [ ] Return `201` with `TopicDTO`
- [ ] `GET /streams/:id/topics`
  - [ ] Public streams in public spaces: no auth required
  - [ ] Accept `?status=open|resolved|archived|all` (default: `open`)
  - [ ] Accept `?cursor=<last_active_timestamp>` for pagination
  - [ ] Return ordered by `last_active DESC`, page size 50
- [ ] `PATCH /topics/:id` (rename)
  - [ ] Require auth + space membership (any member)
  - [ ] Validate new name, check uniqueness
  - [ ] Return `200` with updated `TopicDTO`
- [ ] `PATCH /topics/:id/status`
  - [ ] Require auth + space membership
  - [ ] Validate value is `open`, `resolved`, or `archived`
  - [ ] Return `200` with updated `TopicDTO`
- [ ] `GET /streams/:id/topics?q=:prefix` (autocomplete)
  - [ ] Return top 10 matching topics by name prefix
  - [ ] Exclude `archived` from suggestions
  - [ ] Response time target: < 50ms

---

### 0.5 Messages `[MUST]`

#### 0.5.1 Migration

- [ ] Write migration `0007_messages.sql`
  - [ ] `messages` table: `id UUID`, `topic_id UUID REFERENCES topics NOT NULL`, `author_id UUID REFERENCES users NOT NULL`, `content TEXT NOT NULL`, `rendered TEXT`, `edited_at TIMESTAMPTZ`, `deleted_at TIMESTAMPTZ`, `created_at TIMESTAMPTZ`
  - [ ] Index: `CREATE INDEX idx_messages_topic_time ON messages(topic_id, created_at)`
  - [ ] Index: `CREATE INDEX idx_messages_author ON messages(author_id)`
  - [ ] Constraint: `CHECK (length(content) > 0)`

#### 0.5.2 Markdown Rendering

- [ ] Add `pulldown-cmark` to `crates/core`
- [ ] Implement `render_markdown(input: &str) -> String`
  - [ ] Enable: tables, footnotes, strikethrough, task lists
  - [ ] Sanitize output HTML — strip `<script>`, `<iframe>`, `on*` attributes
  - [ ] Add `target="_blank" rel="noopener noreferrer"` to all external links
  - [ ] Test: XSS vectors, nested markdown, code blocks with syntax hint

#### 0.5.3 DB Queries

- [ ] `messages::insert(pool, topic_id, author_id, content, rendered) -> Message`
  - [ ] After insert: call `topics::update_last_active`
- [ ] `messages::get_page(pool, topic_id, cursor, limit) -> Vec<Message>`
  - [ ] Cursor: `created_at` timestamp, oldest-first
  - [ ] Exclude soft-deleted
  - [ ] Return `author: UserDTO` joined
- [ ] `messages::find_by_id(pool, id) -> Option<Message>`
- [ ] `messages::update_content(pool, id, author_id, new_content, new_rendered) -> Message`
  - [ ] Enforce: only `author_id` may update
  - [ ] Set `edited_at = NOW()`
- [ ] `messages::soft_delete(pool, id, requester_id, requester_role)`
  - [ ] Allow: author OR admin/owner
  - [ ] Set `deleted_at = NOW()`, clear `content` and `rendered`

#### 0.5.4 Handlers

- [ ] `POST /topics/:id/messages`
  - [ ] Require auth + space membership
  - [ ] Load topic — return `404` if not found
  - [ ] Return `403` if topic status is `archived`
  - [ ] Validate content: not empty, max 10,000 chars
  - [ ] Render Markdown
  - [ ] Insert message
  - [ ] Enqueue for Meilisearch indexing (async, non-blocking)
  - [ ] Publish to Redis pub/sub channel
  - [ ] Return `201` with `MessageDTO`
- [ ] `GET /topics/:id/messages`
  - [ ] Public topics in public spaces: no auth required
  - [ ] Accept `?cursor=<created_at>&limit=<n>` (max 100, default 50)
  - [ ] Return `MessageDTO[]` with `author`, `edited_at`, `is_deleted` flag
- [ ] `PATCH /messages/:id`
  - [ ] Require auth — must be message author
  - [ ] Validate new content
  - [ ] Re-render Markdown
  - [ ] Update Meilisearch index entry
  - [ ] Publish `{type: "message_updated"}` to Redis
  - [ ] Return `200` with updated `MessageDTO`
- [ ] `DELETE /messages/:id`
  - [ ] Require auth — author OR space admin/owner
  - [ ] Soft delete only
  - [ ] Remove from Meilisearch index
  - [ ] Publish `{type: "message_deleted", id}` to Redis
  - [ ] Return `204`

---

### 0.6 WebSocket Real-Time `[MUST]`

#### 0.6.1 Connection Lifecycle

- [ ] `GET /ws` — Axum WebSocket upgrade handler
  - [ ] Require auth (JWT in `?token=` query param or `Authorization` header)
  - [ ] On upgrade: create `ConnectionState { user_id, subscribed_spaces: HashSet }`
  - [ ] Store connection in `Arc<DashMap<UserId, Vec<WsSender>>>`
  - [ ] Spawn two tasks: `read_loop` and `write_loop`
- [ ] `read_loop` — handle incoming client frames
  - [ ] Parse JSON, match on `type`
  - [ ] `subscribe`: add `space_ids`, subscribe to Redis channels
  - [ ] `unsubscribe`: remove space, unsubscribe
  - [ ] `catch_up`: accept `{ last_seen: { [topic_id]: message_id } }`, return missed messages
  - [ ] `pong`: reset heartbeat timer
  - [ ] Unknown type: log, ignore (do not close connection)
- [ ] `write_loop` — push server events to client
  - [ ] Receive from Redis pub/sub subscriber
  - [ ] Receive from internal `tokio::mpsc` channel
  - [ ] Serialize and send as `Text` frame
  - [ ] On send error: log, break loop
- [ ] On disconnect: remove from connection map, unsubscribe all Redis channels

#### 0.6.2 Redis Pub/Sub

- [ ] Channel naming: `space:{space_id}`
- [ ] Publish on: new message, message edit, message delete, topic created, topic updated, read position updated
- [ ] Message envelope: `{ type, space_id, payload }`

#### 0.6.3 Heartbeat

- [ ] Server sends `{ type: "ping" }` every 30 seconds
- [ ] Start 10-second response timer after each ping
- [ ] No `pong` within timer → close connection with code `1001`
- [ ] Reset timer on any received frame

#### 0.6.4 Reconnection Protocol

- [ ] Client sends `{ type: "catch_up", last_seen: { "<topic_id>": "<message_id>" } }` on reconnect
- [ ] Server queries missed messages per topic since given message id
- [ ] Batch response: `{ type: "catch_up_response", topics: [ { topic_id, messages, has_more } ] }`
- [ ] Limit: 200 messages per topic per catch-up

---

### 0.7 Per-Topic Read State `[MUST]`

#### 0.7.1 Migration

- [ ] Write migration `0008_read_positions.sql`
  - [ ] `read_positions`: `user_id UUID`, `topic_id UUID`, `last_read_message_id UUID`, `last_read_at TIMESTAMPTZ`, `muted BOOLEAN DEFAULT FALSE`, `PRIMARY KEY (user_id, topic_id)`
  - [ ] Index: `CREATE INDEX idx_read_positions_user ON read_positions(user_id)`

#### 0.7.2 DB Queries

- [ ] `read_positions::upsert(pool, user_id, topic_id, message_id, timestamp)`
  - [ ] `INSERT ... ON CONFLICT DO UPDATE` — only update if `message_id` is newer
- [ ] `read_positions::get_unread_counts(pool, user_id, space_id) -> HashMap<TopicId, u32>`
  - [ ] Single query joining `messages` with `read_positions`
  - [ ] Exclude muted topics and deleted messages
- [ ] `read_positions::set_muted(pool, user_id, topic_id, muted: bool)`

#### 0.7.3 Handlers

- [ ] `POST /topics/:id/read`
  - [ ] Require auth + membership
  - [ ] Body: `{ last_read_message_id: UUID }`
  - [ ] Upsert read position
  - [ ] Publish `{ type: "read_position_updated" }` to Redis (multi-tab sync)
  - [ ] Return `204`
- [ ] `GET /spaces/:slug/unread`
  - [ ] Require auth + membership
  - [ ] Return `{ [topic_id]: unread_count }` for all non-muted topics
  - [ ] Cache in Redis with 30s TTL, invalidate on `read_position_updated`
- [ ] `POST /topics/:id/mute` — set `muted = true`, return `204`
- [ ] `DELETE /topics/:id/mute` — set `muted = false`, return `204`

---

### 0.8 No Presence by Default `[MUST]`

- [ ] `PATCH /users/me/settings`
  - [ ] Require auth
  - [ ] Validate keys against allowlist: `show_presence`, `digest_schedule`, etc.
  - [ ] Update `users.settings` JSONB
  - [ ] Return `200` with updated settings
- [ ] Presence heartbeat: `POST /users/me/presence`
  - [ ] Only processes if `settings.show_presence = true`
  - [ ] Write `presence:{user_id}` to Redis with 60s TTL
  - [ ] Return `204`
- [ ] `GET /users/:id/presence`
  - [ ] Return `{ online: false }` if either party has not opted in
  - [ ] Return `{ online: bool }` only if both have opted in
  - [ ] Never expose `last_seen` timestamp to other users
- [ ] Frontend: confirm no online indicator, status ring, or read receipt rendered anywhere in Phase 0

---

### 0.9 Search `[MUST]`

#### 0.9.1 Meilisearch Index Configuration

- [ ] Create index `messages` on startup (idempotent)
  - [ ] `searchableAttributes`: `["content", "topic_name", "stream_name", "author_display_name"]`
  - [ ] `filterableAttributes`: `["space_id", "stream_id", "topic_id", "author_id", "created_at", "topic_status"]`
  - [ ] `sortableAttributes`: `["created_at"]`
  - [ ] `rankingRules`: `["words", "typo", "proximity", "attribute", "sort", "exactness"]`
  - [ ] `typoTolerance`: enabled, min word size 4
- [ ] Define `SearchDocument` struct: `id`, `content`, `topic_id`, `topic_name`, `stream_id`, `stream_name`, `space_id`, `author_id`, `author_display_name`, `created_at`

#### 0.9.2 Async Indexer

- [ ] Implement `crates/search::indexer`
  - [ ] Receive `IndexTask` via `tokio::mpsc` unbounded channel
  - [ ] Batch: collect up to 100 tasks or 500ms, whichever comes first
  - [ ] Send batch to Meilisearch
  - [ ] On failure: retry up to 3 times with exponential backoff
  - [ ] Task variants: `Add(MessageDoc)`, `Update(MessageDoc)`, `Delete(message_id)`
- [ ] Wire indexer channel into message create/edit/delete handlers

#### 0.9.3 Reindex Binary

- [ ] `crates/bin/reindex.rs`
  - [ ] Accept `--space <slug>` flag (optional)
  - [ ] Stream all non-deleted messages from PostgreSQL in batches of 500
  - [ ] Join with `topics`, `streams`, `users` for denormalized fields
  - [ ] Send to Meilisearch in batches
  - [ ] Print progress and final count

#### 0.9.4 Search Handler

- [ ] `GET /spaces/:slug/search`
  - [ ] Auth: require membership for private, open for public
  - [ ] Params: `q`, `stream_id`, `topic_id`, `author_id`, `before`, `after`, `page`, `limit` (max 50)
  - [ ] Always inject `space_id` filter — no cross-space leakage
  - [ ] Return `{ hits: SearchHitDTO[], total, page }`
  - [ ] Each hit: `message_id`, truncated content with match highlight, `topic_id`, `topic_name`, `stream_name`, `author`, `created_at`

---

### 0.10 Public Read Access Without Join `[MUST]`

- [ ] Audit all `GET` endpoints — use `OptionalAuthUser` where public access is intended
- [ ] `GET /spaces/:slug` — unauthenticated for public spaces
- [ ] `GET /spaces/:slug/streams` — unauthenticated returns public streams only
- [ ] `GET /streams/:id/topics` — unauthenticated if stream is public in public space
- [ ] `GET /topics/:id/messages` — unauthenticated if topic is in public stream in public space
- [ ] `GET /spaces/:slug/search` — unauthenticated for public spaces
- [ ] Access control decision tree documented in `crates/api/src/auth.rs` as inline comments
- [ ] Integration test: unauthenticated request to each public endpoint returns `200`
- [ ] Integration test: unauthenticated request to private space returns `403`

---

### 0.11 New Member Onboarding Digest `[MUST]`

#### 0.11.1 Notifications Table

- [ ] Write migration `0009_notifications.sql`
  - [ ] `notifications`: `id UUID`, `user_id UUID REFERENCES users`, `type TEXT`, `payload JSONB`, `read_at TIMESTAMPTZ`, `created_at TIMESTAMPTZ`
  - [ ] Index: `CREATE INDEX idx_notifications_user_unread ON notifications(user_id) WHERE read_at IS NULL`
- [ ] `GET /notifications` — unread, newest first, cursor page size 20
- [ ] `POST /notifications/read` — body: `{ ids: UUID[] }` or `{ all: true }` — set `read_at`

#### 0.11.2 Welcome Digest Generation

- [ ] `fn generate_welcome_digest(pool, space_id, depth_days: u32) -> Vec<TopicDigestItem>`
  - [ ] Query: top 5 most-active open topics per stream in last `depth_days` days
  - [ ] Sort by `message_count DESC`
  - [ ] Return: `stream_name`, `topic_id`, `topic_name`, `message_count`, `last_active`
- [ ] Wire into `POST /spaces/:slug/join` — call after membership insert
- [ ] Write digest items to `notifications` table
- [ ] Depth options: 7 / 30 / 90 days via `?digest_depth=` on join endpoint

---

### 0.12 Frontend: Phase 0 Views `[MUST]`

#### 0.12.1 Routing Structure

- [ ] Define SvelteKit route tree
  - [ ] `/(auth)/login`
  - [ ] `/(auth)/register`
  - [ ] `/(app)/+layout.svelte` — global WS connection, auth guard
  - [ ] `/(app)/s/[slug]/+layout.svelte` — space shell
  - [ ] `/(app)/s/[slug]/+page.svelte` — space home
  - [ ] `/(app)/s/[slug]/[stream_id]/+page.svelte` — topic list
  - [ ] `/(app)/s/[slug]/[stream_id]/[topic_id]/+page.svelte` — message feed
  - [ ] `/(app)/settings/+page.svelte`
  - [ ] `/(public)/s/[slug]/+page.svelte` — public read-only

#### 0.12.2 Global State Stores

- [ ] `stores/identity.ts` — current user, cleared on logout
- [ ] `stores/connection.ts` — WS state machine: `idle | connecting | connected | reconnecting | failed`
  - [ ] Auto-reconnect with exponential backoff (max 30s)
  - [ ] On reconnect: send `catch_up` frame
- [ ] `stores/spaces.ts` — joined spaces list, active space
- [ ] `stores/unread.ts` — `Map<topic_id, count>`, updated by WS events + mark-read
  - [ ] Derived: `totalUnread` — sum across all spaces

#### 0.12.3 Auth Pages

- [ ] `/login`
  - [ ] Email + password fields
  - [ ] Submit → `POST /auth/login` → store access token in memory only (not localStorage)
  - [ ] On success: redirect to last visited space or `/`
  - [ ] Inline error on `401`
- [ ] `/register`
  - [ ] Username, email, password, confirm-password
  - [ ] Client-side validation before submit
  - [ ] Inline error on `409` — specify whether email or username is taken

#### 0.12.4 Space Shell Layout

- [ ] Left sidebar (240px, collapsible on mobile)
  - [ ] Space name + settings icon
  - [ ] Stream list: name + unread badge (sum of topic unreads in stream)
  - [ ] Active stream highlighted
  - [ ] "Create stream" button (admin/owner only)
  - [ ] Bottom: user avatar, username, settings link
- [ ] Main content: `<slot />` outlet
- [ ] Connection status bar (visible only when `connecting` or `reconnecting`)

#### 0.12.5 Topic List View

- [ ] List topics ordered by `last_active DESC`
- [ ] Each row: topic name, status badge, unread count, relative timestamp
- [ ] Filter tabs: `Open` | `Resolved` | `All`
- [ ] "New topic" inline input: submit creates + navigates
- [ ] Empty state: "No open topics. Start the first one."
- [ ] Catch-up banner: "N unread topics" → opens `CatchUpQueue`

#### 0.12.6 CatchUpQueue Component

- [ ] Triggered by banner or `U` keyboard shortcut
- [ ] Ordered: mentions first, then `last_active DESC`
- [ ] Each item: stream name, topic name, unread count
- [ ] Keyboard: `↑/↓` navigate, `Enter` open, `S` skip (mark read), `Esc` close

#### 0.12.7 Message Feed View

- [ ] Topic header: name, status badge, status dropdown (any member), message count
- [ ] Virtualized message list
  - [ ] Each: avatar, display name, timestamp, rendered HTML
  - [ ] Edited indicator: "(edited)" in muted text
  - [ ] Deleted: grey italic "This message was deleted"
  - [ ] Own messages: hover reveals edit + delete icons
- [ ] Auto-scroll to bottom on initial load
- [ ] Auto-scroll on new message only if already at bottom
- [ ] "Jump to bottom" button when scrolled up 200px+
- [ ] Mark read: triggered when topic open + user at bottom for 2 seconds
- [ ] Explicit "Mark as read" button in header

#### 0.12.8 Compose Box

- [ ] Topic selector: required, dropdown with autocomplete
  - [ ] Pre-filled from current topic view
  - [ ] Block send if no topic — show "Select a topic first"
- [ ] Textarea: Markdown input, auto-grows to 6 rows max
  - [ ] `Enter` sends, `Shift+Enter` newlines
  - [ ] `Ctrl+B` bold, `Ctrl+I` italic, `Ctrl+K` link
- [ ] Markdown toolbar: Bold, Italic, Code, Link, Lists
- [ ] Draft autosave: `sessionStorage` key `draft:{topic_id}`, debounced 500ms
- [ ] Restore draft on mount, clear on send

#### 0.12.9 Search UI

- [ ] `Ctrl+K` or `/` focuses search bar
- [ ] Debounce 300ms → `GET /spaces/:slug/search?q=`
- [ ] Results panel: grouped by topic, snippet with match highlighted, timestamp
- [ ] "No results" empty state
- [ ] Advanced filters: stream, author, date range

#### 0.12.10 Settings Page

- [ ] Display name edit
- [ ] Password change (current + new + confirm)
- [ ] Presence toggle: off by default, explanatory text
- [ ] Notification default: immediate / digest / muted
- [ ] Save → `PATCH /users/me/settings` — success/error toast

---

## Phase 1 — First Retention Features

**Goal:** Reduce churn from the three documented drop-off causes: multi-community fatigue, no lurker UX, no neurodivergent accommodation.

**Gate to Phase 2:** Retained communities report at least one of: (a) migrated knowledge from old platform, (b) onboarded a member who stayed active 14+ days, (c) a user reports using it across 3+ communities.

---

### 1.1 Unified Inbox `[SHOULD]`

- [ ] `GET /inbox`
  - [ ] Require auth
  - [ ] Return all unread mentions + keyword alerts across all joined spaces
  - [ ] Join with `messages`, `topics`, `streams`, `spaces`
  - [ ] Sort by `created_at DESC`, cursor pagination page size 30
  - [ ] Accept `?space_id=`, `?type=mention|keyword|reply`
- [ ] `/inbox` route in `/(app)/inbox/+page.svelte`
  - [ ] Global nav: "Inbox" link with total unread badge (real-time via WS)
  - [ ] List item: space name, stream, topic, message preview, timestamp
  - [ ] Filter bar: All | Mentions | Keywords | Replies
  - [ ] Mark individual read: `POST /notifications/read`
  - [ ] Mark all read button
  - [ ] Keyboard shortcut: `G I` → go to inbox

---

### 1.2 Topic Summary Card `[SHOULD]`

- [ ] Migration: add `summary TEXT`, `summary_rendered TEXT` columns to `topics`
- [ ] `PATCH /topics/:id/summary`
  - [ ] Require auth + membership (any member)
  - [ ] Validate: max 1000 chars
  - [ ] Render Markdown, store `summary_rendered`
  - [ ] Return `200` with updated topic
- [ ] Include `summary_rendered` in `TopicDTO`
- [ ] Frontend: summary card above message feed if non-null
  - [ ] Collapsible, preference in `localStorage`
  - [ ] Inline editor: Markdown textarea, preview toggle, save + cancel
  - [ ] Empty state hint for admins: "Add a summary to help newcomers"

---

### 1.3 Topic Status Flags — Full UI `[SHOULD]`

- [ ] Status dropdown in topic header (any member)
  - [ ] Confirmation modal before archiving
- [ ] `Resolved`: muted text in topic list, grey badge
- [ ] `Archived`: hidden from default list, visible under "Archived" tab
  - [ ] Compose box disabled: "This topic is archived"
- [ ] WS event `topic_status_updated` → reactive update without reload

---

### 1.4 Anonymous Reactions `[SHOULD]`

- [ ] Migration `0010_reactions.sql`
  - [ ] `message_reactions`: `message_id UUID`, `user_id UUID`, `emoji TEXT`, `PRIMARY KEY (message_id, user_id, emoji)`
- [ ] `POST /messages/:id/reactions` — body: `{ emoji }`, idempotent, publish WS event
- [ ] `DELETE /messages/:id/reactions/:emoji` — own reactions only
- [ ] Include aggregated counts in `MessageDTO`: `{ emoji, count, reacted }[]`
- [ ] Frontend: reaction bar below messages, `+` opens emoji picker
- [ ] Reactions update real-time via WS
- [ ] Space setting: `anonymous_reactions` — show counts only, hide individuals

---

### 1.5 Read-Mode UI `[SHOULD]`

- [ ] Toggle in topic header (`R` keyboard shortcut)
- [ ] Hides: compose box, unread badges, hover action icons
- [ ] Increases: font size to 16px, line height to 1.8
- [ ] Persisted in `localStorage` key `readMode`
- [ ] Does not affect navigation

---

### 1.6 Notification Scheduling `[SHOULD]`

- [ ] Migration: `notification_preferences` table + `keyword_alerts` table
- [ ] `GET/PUT /users/me/notification-preferences`
- [ ] `GET/POST/DELETE /users/me/keyword-alerts` (max 20 per user)
- [ ] Digest job: cron per user's `digest_schedule`, assembles unread digest, sends email
  - [ ] Template: grouped by space → stream → topic, unread count, direct link
- [ ] Frontend: Settings > Notifications
  - [ ] Global default selector
  - [ ] Available hours widget: day-of-week × time-of-day range, timezone-aware
  - [ ] Digest schedule dropdown
  - [ ] Keyword alerts list: add + delete

---

### 1.7 Focus Mode `[SHOULD]`

- [ ] `F` keyboard shortcut toggles (within topic view)
- [ ] Hides: sidebar (collapsed to 0px), unread badges, activity indicators
- [ ] Changes page title to topic name only
- [ ] Persisted in `localStorage` key `focusMode`
- [ ] Auto-deactivates on space navigation
- [ ] "Focus" chip in top bar with click-to-dismiss

---

### 1.8 Draft Autosave `[SHOULD]`

- [ ] Save on keystroke, debounced 500ms
- [ ] Key: `draft:{space_id}:{topic_id}` in `sessionStorage` (not localStorage)
- [ ] Restore on mount, clear on send or manual clear
- [ ] "Draft saved" indicator in muted text

---

### 1.9 OAuth2 Login `[SHOULD]`

- [ ] Migration `0011_oauth_identities.sql`: `user_id`, `provider`, `provider_user_id`, `UNIQUE(provider, provider_user_id)`
- [ ] GitHub OAuth2: `GET /auth/github` redirect + `GET /auth/github/callback`
  - [ ] Match by email → link to existing, else create new user
  - [ ] Insert `oauth_identity`, issue JWT
- [ ] Google OAuth2: same pattern
- [ ] Frontend: "Continue with GitHub" + "Continue with Google" on login + register
- [ ] Settings > Account: "Connected accounts" — show providers, unlink button

---

### 1.10 Accessibility — Neurodivergent Baseline `[SHOULD]`

- [ ] High-contrast mode
  - [ ] CSS custom property overrides for all colour tokens
  - [ ] Toggle in settings, detects `prefers-contrast: more`
- [ ] Reduced-motion mode
  - [ ] All transitions wrapped in `@media (prefers-reduced-motion: reduce)`
  - [ ] Manual toggle overrides system setting
- [ ] Keyboard navigation
  - [ ] Tab order: sidebar → topic list → feed → compose
  - [ ] All interactive elements reachable by Tab
  - [ ] Modals trap focus, restore on close
- [ ] Shortcut map: `?` opens overlay listing all shortcuts
- [ ] ARIA
  - [ ] Landmark roles on all layout regions
  - [ ] `aria-label` on all icon-only buttons
  - [ ] `aria-live="polite"` on unread badge changes
  - [ ] `role="status"` on connection status bar
  - [ ] Screen reader test with VoiceOver (macOS) — document results

---

### 1.11 Member Tenure Signal `[SHOULD]`

- [ ] `GET /spaces/:slug/members/:user_id`
  - [ ] Return: `joined_at`, message count per stream (top 5), total count
  - [ ] No rank, score, or gamified metric
- [ ] Member profile card on username click
  - [ ] "Member since {date}", top contribution streams (factual, no bar chart)
  - [ ] No badges, XP, level, streak — enforced in code review gate

---

### 1.12 Data Export `[SHOULD]`

- [ ] `POST /spaces/:slug/export` → `202 Accepted` with `{ job_id }`
  - [ ] Require owner/admin, rate-limit once per 24h
- [ ] Export job (background)
  - [ ] JSON: ndjson per stream, full message content + author + timestamps
  - [ ] Markdown: one `.md` per topic, threaded by timestamp
  - [ ] Zip both, store in `exports/` volume
  - [ ] Write to `export_jobs` table: `id`, `status`, `file_path`, `expires_at`
- [ ] `GET /spaces/:slug/export/:job_id` — poll: `pending | complete | failed`
- [ ] `GET /exports/:token` — download, delete after download or 24h TTL
- [ ] Frontend: Settings > Space > Export
  - [ ] "Export all data" button, last export date, progress spinner, download link

---

## Phase 2 — Differentiation Compounds

**Goal:** Activate the features that make the product structurally irreplaceable.

**Gate to Phase 3:** At least one community reports "we couldn't go back — our knowledge is here."

---

### 2.1 Expertise Map `[SHOULD]`

- [ ] Migration: `topic_domains` table — `topic_id`, `domain_tag TEXT`
- [ ] Materialized view: message count per `(author_id, domain_tag)`, refreshed every 6h
- [ ] `GET /spaces/:slug/experts?domain=` — top 10 contributors per domain
- [ ] `GET /topics/:id/suggest-experts` — up to 3 suggested experts for topic's domains
- [ ] Frontend: `/s/:slug/experts` page
  - [ ] Stream breakdown: top 3 contributors per stream
  - [ ] Domain tags: clickable, filter to domain experts
  - [ ] No ranking numbers — names and contribution area only
- [ ] "Ask an expert" CTA in topic header with suggested @mention links

---

### 2.2 SEO-Indexable Public Streams `[SHOULD]`

- [ ] Enable SvelteKit SSR for all `/(public)/` routes
- [ ] For each public topic page, set server-side:
  - [ ] `<title>`: `{topic_name} — {stream_name} — {space_name} | Pebesen`
  - [ ] `<meta name="description">`: first 160 chars of first message
  - [ ] `<link rel="canonical">`
  - [ ] `<meta property="og:*">` tags
- [ ] `robots.txt`: allow public spaces, disallow private + auth routes
- [ ] `GET /s/:slug/sitemap.xml` — paginated, max 50,000 URLs, `<lastmod>` from `last_active`
- [ ] Audit: no private message content in SSR responses

---

### 2.3 Self-Hosting Documentation `[SHOULD]`

- [ ] `docs/self-hosting.md`: prerequisites, step-by-step, SMTP config, custom domain + TLS, troubleshooting
- [ ] `docs/upgrade.md`: pull image, run compose, rollback procedure
- [ ] `docs/backup.md`: pg_dump, volume backup, recommended schedule
- [ ] Publish to GHCR via CI on tag: `ghcr.io/pebesen/pebesen:latest` + semver tag
- [ ] Test complete install on clean Ubuntu 24.04 LTS VPS (1GB RAM)

---

### 2.4 AI Topic Summaries `[NICE]`

- [ ] Migration: add `ai_summary TEXT`, `ai_summary_generated_at TIMESTAMPTZ` to `topics`
- [ ] Background job (every 15 min): find topics with 20+ messages and stale/missing AI summary
  - [ ] Fetch last 50 messages, send to configured provider
  - [ ] Provider: `AI_PROVIDER=anthropic|ollama|none` in `.env` (default `none`)
- [ ] Store in `topics.ai_summary`, manual summary always takes precedence
- [ ] Frontend: show `ai_summary` in summary card with "AI-generated" label in muted text
- [ ] Admin space setting: `ai_summaries_enabled` — defaults to `false`

---

### 2.5 Smart Topic Name Suggestion `[NICE]`

- [ ] Compose box: suggest topic when textarea has content but no topic selected
- [ ] Client-side heuristic:
  - [ ] Extract first 80 chars, strip punctuation, lowercase, remove stop words
  - [ ] Fuzzy match against cached topic list via Fuse.js
  - [ ] Show top match as chip: "Did you mean: {topic_name}?"
- [ ] Click chip: select topic; `×` dismisses

---

### 2.6 E2E Encrypted DMs `[SHOULD]`

- [ ] Migration: `dm_keys` (`user_id PK`, `public_key TEXT`, `created_at`)
- [ ] Migration: `direct_messages` (`id`, `sender_id`, `recipient_id`, `ciphertext`, `nonce`, `created_at`)
- [ ] `PUT /users/me/dm-key` — register public key (generated client-side)
- [ ] `GET /users/:id/dm-key` — fetch recipient's public key
- [ ] `POST /dm/:user_id` — store ciphertext only, no plaintext ever
- [ ] `GET /dm/:user_id` — return ciphertext thread, decrypted client-side
- [ ] Key generation: X25519 keypair on first DM use, private key in `sessionStorage` only
- [ ] Encryption: ECDH shared secret → XChaCha20-Poly1305
- [ ] `/dm/:username` route — DM thread view
- [ ] DMs NOT indexed in Meilisearch
- [ ] Warning banner: "Messages are end-to-end encrypted. Pebesen cannot read them."

---

### 2.7 Verified Credential Badges `[NICE]`

- [ ] Migration: `badge_types` (`id`, `space_id`, `name`, `description`, `icon`)
- [ ] Migration: `member_badges` (`user_id`, `space_id`, `badge_type_id`, `awarded_by`, `awarded_at`)
- [ ] `POST /spaces/:slug/badge-types` — admin only
- [ ] `POST/DELETE /spaces/:slug/members/:user_id/badges` — admin only
- [ ] Display on member profile within that space only
- [ ] No cross-space badge visibility — enforced at query level

---

### 2.8 Mobile Web — Responsive Hardening `[SHOULD]`

- [ ] Audit all Phase 0 + 1 views at 375px, 390px, 428px
  - [ ] Sidebar: full-screen overlay on mobile, hamburger trigger
  - [ ] Compose box: fixed to bottom, iOS `visualViewport` keyboard handling
  - [ ] All touch targets: 44px minimum
- [ ] Swipe left on topic list item → "Mark read" action
- [ ] PWA manifest (`static/manifest.json`): `name`, `short_name`, `theme_color`, `icons`, `display: standalone`
- [ ] Service worker: cache app shell + static assets
- [ ] Test: install as PWA on iOS Safari + Android Chrome

---

## Phase 3 — Network Effects

**Goal:** Cross-community discovery and developer ecosystem that creates compounding value.

**Gate:** No gate — continuous. These are growth levers, not survival features.

---

### 3.1 Public Community Directory `[NICE]`

- [ ] Migration: add `listed BOOLEAN DEFAULT FALSE` to `spaces`
- [ ] Admin setting: opt-in to directory
- [ ] `GET /explore` — public, no auth
  - [ ] Filters: `?sort=activity|members|created`, `?language=`
  - [ ] Returns `SpaceCardDTO`: name, slug, description, member count, top 3 streams, last activity
- [ ] Frontend: `/explore` — grid of space cards, client-side filter bar

---

### 3.2 Cross-Community Semantic Search `[NICE]`

- [ ] Migration: `CREATE EXTENSION IF NOT EXISTS vector` + `embedding vector(384)` on `messages`
- [ ] Embedding job: compute 384-dim embedding per new message (local model via `fastembed-rs`)
- [ ] `GET /search/similar?topic_id=:id&limit=10`
  - [ ] Embed topic's first message, find nearest via `<=>` operator
  - [ ] Filter to user's spaces only

---

### 3.3 Bot / Webhook API `[NICE]`

- [ ] Migration: `bot_users` (`id`, `space_id`, `name`, `api_key` hashed, `created_by`)
- [ ] Migration: `webhooks` (`id`, `space_id`, `stream_id`, `topic_id nullable`, `url`, `secret`, `events TEXT[]`)
- [ ] `POST /spaces/:slug/bots` — admin only, return plaintext API key once
- [ ] Bot posts via `Authorization: Bot <api_key>`, rate limited 60 msg/min
- [ ] Inbound webhook: `POST /webhooks/:id?token=:secret` → posts to configured topic
- [ ] Outbound webhook: on new message → HTTP POST with HMAC-SHA256 signature
- [ ] Frontend: Settings > Space > Integrations

---

### 3.4 MCP Connector `[NICE]`

- [ ] Implement MCP server in `crates/mcp`
- [ ] Tools: `post_message`, `list_topics`, `search_messages`, `get_topic_summary`, `get_unread_topics`
- [ ] Auth: same API key as bot users
- [ ] Publish to MCP registry with README and example prompts
- [ ] Optional `mcp` service in `docker-compose.yml` (disabled by default)

---

### 3.5 Federation Research `[NICE]`

- [ ] Open GitHub Discussion: "Federation protocol evaluation"
- [ ] Document: implementation complexity, user benefit, protocol maturity, maintenance burden
- [ ] Decision gate: no implementation until 3+ community operators formally request it

---

## Permanent Backlog — Excluded by Design

| Feature | Reason Excluded |
|---|---|
| Gamification (XP, streaks, levels) | Directly harms neurodivergent users. Validated by research. |
| Algorithmic feed / recommended content | Contradicts async, low-pressure model |
| Ephemeral / disappearing messages in channels | Destroys institutional memory |
| NFT / token-gating | Zero validated demand in target segments |
| Built-in project management (tasks, boards) | Scope creep. Use webhook/bot integration instead |
| Public follower graph | Social pressure layer, not community coherence |
| Read receipts visible to sender | Documented anxiety harm. Default must be off. |
| Algorithmic notification ranking | Removes user control |

---

## Open Questions (Need Data Before Deciding)

- [ ] **Pricing model**: seat-based ruled out (conflicts with lurker-first design). Evaluate: space-based flat fee vs usage-based vs hosted-only revenue. Decide before Phase 2.
- [ ] **Mobile native app**: do not start until DAU/MAU on mobile web exceeds 40%. Measure in Phase 1.
- [ ] **Message length limits**: measure median length in Phase 0 communities before setting a cap.
- [ ] **Space federation**: block on Phase 3 evaluation. Do not implement earlier.
- [ ] **Moderation tooling**: planning spike required before any public community launch. Schedule in Phase 1 planning, implement in Phase 1.
