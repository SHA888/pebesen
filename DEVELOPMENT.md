# Development Guide

This guide covers the complete development workflow for Pebesen, from setup to deployment.

## Table of Contents

- [Quick Start](#quick-start)
- [Development Environment](#development-environment)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Database Management](#database-management)
- [Code Quality](#code-quality)
- [Debugging](#debugging)
- [Deployment](#deployment)

## Quick Start

```bash
# Clone and set up everything
git clone https://github.com/SHA888/pebesen
cd pebesen
make setup

# Start development environment
make dev
```

## Development Environment

### Prerequisites

- **Rust 1.85+** (2024 edition)
- **Node.js 22+** (latest LTS)
- **pnpm 9+**
- **Docker & Docker Compose**
- **Python 3.8+** (for pre-commit hooks)
- **uv** (recommended Python package manager)

### Installation Commands

```bash
# Rust
rustup update stable
rustup component add rustfmt clippy

# Node.js & pnpm
curl -fsSL https://core.nodejs.org/dist/v22.12.0/node-v22.12.0-linux-x64.tar.xz | tar -xz
# Or use your system package manager

# pnpm
npm install -g pnpm

# Python tools
uv tool install pre-commit
```

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Required variables:
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `MEILISEARCH_URL` - Search service URL
- `MEILISEARCH_MASTER_KEY` - Search service master key
- `JWT_SECRET` - JWT signing secret (min 64 chars)

## Project Structure

```
pebesen/
├── crates/                 # Rust workspace
│   ├── api/               # HTTP API handlers
│   ├── core/              # Domain models
│   ├── db/                # Database queries
│   ├── search/            # Search functionality
│   ├── notifications/     # Notification system
│   └── bin/               # Binary applications
├── frontend/               # SvelteKit frontend
│   ├── src/
│   │   ├── lib/           # App utilities
│   │   ├── routes/        # SvelteKit routes
│   │   ├── stores/        # State management
│   │   └── components/     # Reusable components
│   ├── static/            # Static assets
│   └── tests/             # Frontend tests
├── migrations/             # Database migrations
├── scripts/                # Helper scripts
├── .github/workflows/     # CI/CD pipelines
├── docker-compose.yml     # Development services
├── Makefile               # Development commands
├── Cargo.toml             # Rust workspace config
├── pnpm-workspace.yaml    # pnpm workspace config
└── .pre-commit-config.yaml # Pre-commit hooks
```

## Development Workflow

### Daily Development

```bash
# Start everything
make dev

# Backend only
make dev-backend

# Frontend only
make dev-frontend

# View logs
make logs
```

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature
   ```

2. Make your changes

3. Run quality checks:
   ```bash
   make check
   ```

4. Commit changes (pre-commit hooks run automatically):
   ```bash
   git add .
   git commit -m "feat: add your feature"
   ```

5. Push and create pull request

### Database Changes

```bash
# Create new migration
echo "-- Your SQL here" > migrations/0002_new_table.sql

# Run migrations
make migrate

# Reset database (development only)
make db-reset
```

## Testing

### Running Tests

```bash
# All tests
make test

# Rust tests only
cargo test --all-features

# Frontend tests only
cd frontend && pnpm test

# Watch mode
cargo test --all-features --watch
```

### Test Organization

- **Unit Tests**: Test individual functions and modules
- **Integration Tests**: Test API endpoints and database interactions
- **Frontend Tests**: Component testing and user interactions

### Coverage

```bash
# Rust coverage (requires tarpaulin)
cargo install tarpaulin
cargo tarpaulin --all-features --workspace

# Frontend coverage (requires vitest coverage plugin)
cd frontend && pnpm test --coverage
```

## Database Management

### Services

- **PostgreSQL**: Primary database (port 5434 internally)
- **Redis**: Cache and pub/sub (port 6380)
- **Meilisearch**: Search engine (port 7701)

### Commands

```bash
# Start database services
make db-up

# Stop database services
make db-down

# Reset database (WARNING: destroys data)
make db-reset

# Run migrations
make migrate

# Connect to PostgreSQL
docker exec -it pebesen_postgres psql -U pebesen -d pebesen

# Connect to Redis
docker exec -it pebesen_redis redis-cli

# Check Meilisearch
curl http://localhost:7701/health
```

### Migration Guidelines

1. Use descriptive names with numeric prefixes
2. Write reversible migrations when possible
3. Test migrations on fresh database
4. Update corresponding model types

## Code Quality

### Pre-commit Hooks

Automatic checks run before each commit:
- Rust: `cargo fmt`, `cargo clippy`, `cargo check`
- Frontend: `prettier`, `eslint`, `svelte-check`
- General: trailing whitespace, file endings, large files

### Manual Quality Checks

```bash
# Format all code
make format

# Run all linters
make lint

# Run security audits
make check-security

# Update dependencies
make deps
```

### Linting Rules

- **Rust**: Deny all clippy warnings, enforce formatting
- **TypeScript/Svelte**: ESLint recommended rules, Prettier formatting
- **General**: No trailing whitespace, proper file endings

## Debugging

### Backend Debugging

```bash
# Enable debug logging
RUST_LOG=debug cargo run

# Database query logging
RUST_LOG=sqlx=debug cargo run

# Debug build
cargo build

# Run specific tests with debugging
RUST_LOG=debug cargo test your_test
```

### Frontend Debugging

```bash
# Development with debugging
cd frontend && pnpm dev --debug

# Type checking
cd frontend && pnpm check

# Build analysis
cd frontend && pnpm build --analyze
```

### Database Debugging

```bash
# Check database status
docker compose ps

# View database logs
docker compose logs postgres

# Connect and explore
docker exec -it pebesen_postgres psql -U pebesen -d pebesen
\dt  # List tables
\d  # Describe table
```

## Performance

### Backend Performance

```bash
# Profile Rust code
cargo install cargo-flamegraph
cargo flamegraph --bin pebesen

# Benchmark database queries
cargo install cargo-criterion
cargo bench
```

### Frontend Performance

```bash
# Bundle analysis
cd frontend && pnpm build --analyze

# Lighthouse audit
npx lighthouse http://localhost:5173
```

## Deployment

### Development Deployment

```bash
# Build all components
make build

# Start with Docker Compose
docker compose up -d
```

### Production Considerations

- Use environment-specific configuration
- Enable security headers and HTTPS
- Set up proper logging and monitoring
- Configure database backups
- Use container orchestration (Kubernetes/Docker Swarm)

### Environment Configuration

Different environments require different `.env` files:

```bash
# Development
cp .env.example .env.development

# Production
cp .env.example .env.production
# Edit with production values
```

## Troubleshooting

### Common Issues

**Port conflicts:**
```bash
# Check what's using ports
netstat -tulpn | grep :5173
netstat -tulpn | grep :3000

# Stop conflicting services
make db-down
```

**Database connection errors:**
```bash
# Check database status
make db-up
docker compose ps

# Reset database
make db-reset
```

**Frontend build errors:**
```bash
# Clear frontend cache
cd frontend && rm -rf .svelte-kit build dist
pnpm install
```

**Rust compilation errors:**
```bash
# Clear Rust cache
cargo clean
cargo update
```

### Getting Help

1. Check this guide first
2. Run `make help` for available commands
3. Check GitHub issues and discussions
4. Review architecture documentation
5. Ask in community channels

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for detailed contribution guidelines.

### Code Review Process

1. All changes must pass `make check`
2. Pull requests require at least one approval
3. Tests must be added for new features
4. Documentation must be updated for API changes

### Release Process

1. Update version numbers
2. Update CHANGELOG.md
3. Create git tag
4. Build and publish packages
5. Update documentation
