# Contributing to Pebesen

Thank you for your interest in contributing! This document covers the essential setup and workflow for contributors.

## Development Setup

### Prerequisites

- Rust 1.85+ (2024 edition)
- Node.js 20+
- pnpm 10+
- Docker & Docker Compose
- PostgreSQL client tools (optional)

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/pebesen/pebesen.git
   cd pebesen
   ```

2. Install dependencies:
   ```bash
   # Rust dependencies are handled by Cargo
   # Frontend dependencies
   cd frontend && pnpm install
   ```

3. Start development environment:
   ```bash
   make dev
   ```

4. Run database migrations:
   ```bash
   make migrate
   ```

### Environment Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

Required variables:
- `DATABASE_URL` - PostgreSQL connection
- `REDIS_URL` - Redis connection  
- `MEILISEARCH_URL` - Search service URL
- `MEILISEARCH_MASTER_KEY` - Search service key
- `JWT_SECRET` - At least 64 characters

## Architecture

### Rust Workspace Structure

- `crates/api` - HTTP API handlers and routing
- `crates/core` - Domain models and shared types
- `crates/db` - Database queries and migrations
- `crates/search` - Search indexing and queries
- `crates/notifications` - Notification system
- `crates/bin` - Binary applications (main server, reindex tool)

### Frontend Structure

- `frontend/src/lib.ts` - App entry point
- `frontend/src/routes/` - SvelteKit routes
- `frontend/src/stores/` - Svelte stores for state
- `frontend/src/components/` - Reusable components

## Development Workflow

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting: `make test && make lint`
5. Submit a pull request

### Code Style

- Rust: `cargo fmt` and `cargo clippy` must pass
- TypeScript: ESLint and Prettier must pass
- Use meaningful commit messages
- Document public APIs

## Testing

### Running Tests

```bash
# All tests
make test

# Rust only
cargo test --all

# Frontend only
cd frontend && pnpm test
```

### Test Coverage

- Aim for >80% coverage on new code
- Write unit tests for business logic
- Write integration tests for API endpoints

## Database

### Migrations

Migrations are in the `migrations/` directory with numeric prefixes:

```bash
# Create new migration
echo "-- Your SQL here" > migrations/0002_new_table.sql

# Run migrations
make migrate
```

### Schema Changes

1. Create migration file
2. Write SQL changes
3. Test migration on fresh database
4. Update model types if needed

## Debugging

### Backend

```bash
# Debug build
cargo build

# Run with logs
RUST_LOG=debug cargo run

# Database queries
RUST_LOG=sqlx=debug cargo run
```

### Frontend

```bash
# Development mode
cd frontend && pnpm dev

# Type checking
cd frontend && pnpm check
```

## Common Issues

### Port Conflicts

If you encounter port conflicts, the services use:
- PostgreSQL: internal only (no host port)
- Redis: 6380
- Meilisearch: 7701
- Frontend: 5173
- Backend: 3000

### Database Connection

Ensure Docker services are running:
```bash
docker compose ps
```

Reset database if needed:
```bash
docker compose down -v
docker compose up -d postgres
make migrate
```

## Getting Help

- Check existing issues on GitHub
- Ask questions in discussions
- Review architecture documentation in `ARCHITECTURE.md`

## License

By contributing, you agree that your contributions will be licensed under the AGPL-3.0 license.
