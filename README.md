# Pebesen

> Structured conversations. Approachable by everyone. Built for the users most platforms ignore.

---

## What This Is

Pebesen is an open-source messaging platform built around a single architectural bet:

**Most messaging tools are optimized for the sender. This one is optimized for the reader.**

It enforces topic discipline at the input layer, maintains a single user identity across all communities, and treats knowledge preservation as a first-class feature — not a side effect.

---

## Why It Exists

Existing platforms made deliberate tradeoffs that served their primary use cases well. Those same tradeoffs create gaps for other users:

| Design Tradeoff | Optimized For | Underserved By |
|---|---|---|
| Workspace-scoped identity | Enterprise security isolation | Users who belong to many communities |
| Casual, low-friction UX | Fast consumer adoption | Teams that need long-lived structured knowledge |
| Federation-first architecture | Decentralization | Non-technical users facing setup complexity |
| Real-time presence and engagement | Synchronous collaboration | Async-first, deep-work users |

These are rational product decisions — not mistakes. Pebesen simply makes different ones, optimized for a different set of users.

Specifically, Pebesen makes four architectural decisions that compound differently:

1. **Single identity, multi-community** — one account joins unlimited spaces
2. **Mandatory topic tagging** — every message belongs to a Stream and a Topic, enforced at input
3. **Per-topic unread state** — you track what you've read at topic granularity, not channel granularity
4. **No presence indicators by default** — async-first, opt-in sync

These four decisions compose into a system where institutional knowledge accumulates structurally, without requiring users to do anything extra.

---

## Who This Is For

### Primary Segments (validated pain, documented migration intent)

**Open source and technical communities**
- Projects with distributed contributors across global timezones
- Need structured, long-lived topic history that newcomers can navigate independently
- Size: 5–500 active contributors, long-lived projects

**Research and academic groups**
- Labs, cohorts, reading groups, conference communities
- Need permanent, searchable, topic-organized history
- Currently fragmented across multiple tools with no single coherent knowledge store

### Secondary Segments (real pain, addressable in Phase 2+)

**Context multiplexers** — consultants, DevRel, open source contributors in 10+ communities simultaneously
**Neurodivergent users** — ADHD/autism users harmed at the model level, not just the surface level
**Longitudinal participants** — community veterans who hold institutional memory with no platform support
**Knowledge consumers (lurkers)** — the ~75% of any community who read without posting

---

## Core Thesis

> A messaging platform that enforces structure at input produces knowledge as a side effect.
> Knowledge that accumulates structurally is irreplaceable.
> Irreplaceable tools do not churn.

The retention model is not engagement loops or notifications. It is **accumulated, structured, irretrievable-elsewhere knowledge.**

---

## What It Is Not

- Not a feature-for-feature alternative to any existing platform
- Not optimized for casual, ephemeral conversation
- Not an AI chat product — AI accelerates the model, it does not replace it
- Not a project management tool

---

## Validation Status

This project was preceded by structured demand validation across five stages:

- **Stage 0**: Confirmed active user migration intent across the messaging platform landscape. Documented workaround products (MentionFlow, Regarding) built to fill gaps — proving unmet demand. Studied failure modes of prior entrants (HipChat/Stride, Guilded, Spectrum) to understand what does not work.
- **Stage 1**: Primary segment identified as open source and technical communities. Secondary: context multiplexers and neurodivergent users.
- **Stage 2**: Qualitative patterns confirmed: newcomer onboarding friction, knowledge retrieval difficulty, multi-workspace fatigue, communication model mismatches for neurodivergent users.
- **Stage 3**: Quantitative proxies — measurable spikes in alternative platform searches (2025–2026), active community migration behavior driven by privacy, pricing, and policy changes across the industry.
- **Stage 4**: Behavior proxies exist and are monetizing. Forum-style threading features are being adopted industry-wide — confirming that structured conversation is a validated need.
- **Stage 5**: Structural defensibility confirmed. Seat-based pricing models are structurally incompatible with lurker-first design. Casual-UX brand positioning is structurally incompatible with mandatory topic discipline. Single-identity multi-community requires an identity layer rebuild that existing platforms have not undertaken.

See [`ARCHITECTURE.md`](./ARCHITECTURE.md) for system design.
See [`TODO.md`](./TODO.md) for phased build plan.

---

## Tech Stack

| Layer | Choice | Rationale |
|---|---|---|
| Backend | Rust (Axum + Tokio) | Performance, safety, single binary deployment |
| Real-time | WebSocket (tokio-tungstenite) | Native async, no runtime overhead |
| Database | PostgreSQL | Relational integrity for topic/stream hierarchy |
| Cache / PubSub | Redis | Session state, fan-out, ephemeral presence |
| Search | Meilisearch | Self-hostable, fast, typo-tolerant, open source |
| Frontend | TypeScript + SvelteKit (pnpm) | Lightweight, fast, component-scoped CSS |
| Self-host | Docker Compose | Single-command deployment |
| Package managers | pnpm (TS), uv (Python tools), Cargo (Rust) | Per-language best-in-class |

---

## Self-Hosting

```bash
# Clone
git clone https://github.com/pebesen/pebesen
cd pebesen

# Configure
cp .env.example .env
# Edit .env — set DATABASE_URL, REDIS_URL, SECRET_KEY

# Start
docker compose up -d

# Pebesen is now running at http://localhost:3000
```

Full self-hosting documentation: `docs/self-hosting.md` *(Phase 2)*

---

## License

AGPL-3.0 — free for self-hosting and community use.
Commercial license available for hosted deployments and enterprise features.

---

## Status

**Pre-alpha.** Core architecture under active development.
See [`TODO.md`](./TODO.md) for current phase and open tasks.
