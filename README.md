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
| Code Quality | Pre-commit hooks, CI/CD | Automated formatting, linting, testing |

---

## Quick Start

### Prerequisites

- **Rust 1.85+** (2024 edition)
- **Node.js 22+** (latest LTS)
- **pnpm 9+**
- **Docker & Docker Compose**
- **Python 3.8+** (for pre-commit hooks)
- **uv** (recommended Python package manager)

### One-Command Setup

```bash
# Clone and set up everything
git clone https://github.com/SHA888/pebesen
cd pebesen
make setup

# Start development environment
make dev
```

### Manual Setup

```bash
# Clone
git clone https://github.com/SHA888/pebesen
cd pebesen

# Install dependencies
make setup

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Start development
make dev
```

### Development Commands

```bash
make help          # Show all available commands
make dev           # Start full development environment
make dev-backend   # Backend only
make dev-frontend  # Frontend only
make test          # Run all tests
make lint          # Run all linters
make format        # Format all code
make check         # Run all checks (format + lint + test)
make db-reset      # Reset database
make clean         # Clean build artifacts
```

---

## Self-Hosting

### Development Setup

```bash
# Start database services
make db-up

# Run migrations
make migrate

# Start application
make dev
```

### Production Setup

```bash
# Clone
git clone https://github.com/SHA888/pebesen
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

## Development

### Architecture

- **Rust Workspace**: 6 crates (api, core, db, search, notifications, bin)
- **Frontend**: SvelteKit with TypeScript and TailwindCSS
- **Database**: PostgreSQL with migrations
- **Search**: Meilisearch for full-text search
- **Cache**: Redis for session state and pub/sub

### Code Quality

- **Pre-commit hooks**: Automatic formatting and linting
- **CI/CD**: GitHub Actions for automated testing
- **Security**: Automated dependency audits
- **Documentation**: Comprehensive setup and API docs

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `make check` to ensure quality
5. Submit a pull request

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for detailed guidelines.

---

## Project Status

**Phase**: Pre-Phase Complete ✅
**Next**: Phase 0 MVP Implementation

### Completed ✅

- ✅ Rust workspace with 2024 edition
- ✅ SvelteKit frontend with TypeScript
- ✅ Docker Compose development environment
- ✅ Database migrations and extensions
- ✅ CI/CD pipeline with GitHub Actions
- ✅ Pre-commit hooks and code quality tools
- ✅ Comprehensive Makefile for development
- ✅ Documentation and contribution guidelines

### In Progress 🚧

- 🚧 Phase 0: Core Architecture Validation
- 🚧 Authentication system (users, spaces, memberships)
- 🚧 Real-time messaging with WebSocket
- 🚧 Topic-based conversation structure
- 🚧 Full-text search integration

### Planned 📋

- 📋 Phase 1: Community retention features
- 📋 Phase 2: Expertise discovery and SEO
- 📋 Phase 3: Advanced features and federation

---

## License

AGPL-3.0 — free for self-hosting and community use.
Commercial license available for hosted deployments and enterprise features.

---

## Status

**Pre-alpha.** Core infrastructure complete, starting MVP development.
See [`TODO.md`](./TODO.md) for detailed implementation roadmap.
