.PHONY: help setup dev deps clean build test lint format check-security db-up db-down db-reset migrate

# Default target
help:
	@echo "Pebesen Development Commands"
	@echo ""
	@echo "Setup & Dependencies:"
	@echo "  setup          - Install all dependencies and set up environment"
	@echo "  deps           - Install/update all project dependencies"
	@echo "  check-security - Run security audits on dependencies"
	@echo ""
	@echo "Development:"
	@echo "  dev            - Start full development environment"
	@echo "  dev-backend    - Start only backend services"
	@echo "  dev-frontend   - Start only frontend development server"
	@echo "  build          - Build all project components"
	@echo ""
	@echo "Database:"
	@echo "  db-up          - Start database services"
	@echo "  db-down        - Stop database services"
	@echo "  db-reset       - Reset database (WARNING: destroys data)"
	@echo "  migrate        - Run database migrations"
	@echo ""
	@echo "Quality Assurance:"
	@echo "  test           - Run all tests"
	@echo "  lint           - Run all linters"
	@echo "  format         - Format all code"
	@echo "  check          - Run all checks (format + lint + test)"
	@echo ""
	@echo "Utilities:"
	@echo "  clean          - Clean build artifacts and caches"
	@echo "  reindex        - Rebuild search index"
	@echo "  logs           - Show development logs"

# Setup & Dependencies
setup:
	@echo "Setting up Pebesen development environment..."
	@echo "Installing Rust toolchain..."
	rustup update stable
	rustup component add rustfmt clippy
	@echo "Installing sqlx-cli..."
	cargo install sqlx-cli --no-default-features --features native-tls,postgres || true
	@echo "Installing cargo-audit..."
	cargo install cargo-audit || true
	@echo "Installing pre-commit..."
	uv tool install pre-commit || pip install pre-commit || true
	@echo "Installing pre-commit hooks..."
	uv run pre-commit install || pre-commit install || true
	@echo "Installing frontend dependencies..."
	cd frontend && pnpm install
	@echo "Starting database services..."
	$(MAKE) db-up
	@echo "Running migrations..."
	$(MAKE) migrate
	@echo "Setup complete! Run 'make dev' to start development."

deps:
	@echo "Updating all dependencies..."
	@echo "Updating Rust dependencies..."
	cargo update
	@echo "Updating frontend dependencies..."
	cd frontend && pnpm update
	@echo "Dependencies updated!"

check-security:
	@echo "Running security audits..."
	@echo "Auditing Rust dependencies..."
	cargo audit
	@echo "Auditing frontend dependencies..."
	cd frontend && pnpm audit --audit-level moderate

# Development
dev:
	@echo "Starting full development environment..."
	$(MAKE) db-up
	@echo "Starting Rust development server..."
	cargo watch -x run &
	@echo "Starting frontend development server..."
	cd frontend && pnpm dev &
	@echo "Development environment started!"
	@echo "Frontend: http://localhost:5173"
	@echo "Backend: http://localhost:3000 (when implemented)"

dev-backend:
	@echo "Starting backend development environment..."
	$(MAKE) db-up
	cargo watch -x run

dev-frontend:
	@echo "Starting frontend development server..."
	cd frontend && pnpm dev

build:
	@echo "Building all components..."
	@echo "Building Rust workspace..."
	cargo build --release
	@echo "Building frontend..."
	cd frontend && pnpm build
	@echo "Build complete!"

# Database Management
db-up:
	@echo "Starting database services..."
	docker compose up -d postgres redis meilisearch
	@echo "Waiting for services to be ready..."
	sleep 10
	@echo "Database services started!"

db-down:
	@echo "Stopping database services..."
	docker compose down postgres redis meilisearch
	@echo "Database services stopped!"

db-reset:
	@echo "Resetting database (WARNING: This will destroy all data)..."
	docker compose down -v
	docker compose up -d postgres redis meilisearch
	sleep 10
	$(MAKE) migrate
	@echo "Database reset complete!"

migrate:
	@echo "Running database migrations..."
	docker exec -i pebesen_postgres psql -U pebesen -d pebesen < migrations/0001_extensions.sql
	@echo "Migrations complete!"

# Quality Assurance
test:
	@echo "Running all tests..."
	@echo "Running Rust tests..."
	cargo test --all-features
	@echo "Running frontend tests..."
	cd frontend && pnpm test
	@echo "All tests complete!"

lint:
	@echo "Running all linters..."
	@echo "Running Rust linters..."
	cargo fmt --check
	cargo clippy --all-targets --all-features -- -D warnings
	@echo "Running frontend linters..."
	cd frontend && pnpm lint
	@echo "Linting complete!"

format:
	@echo "Formatting all code..."
	@echo "Formatting Rust code..."
	cargo fmt
	@echo "Formatting frontend code..."
	cd frontend && pnpm format
	@echo "Code formatting complete!"

check: format lint test
	@echo "All checks completed successfully!"

# Utilities
clean:
	@echo "Cleaning build artifacts and caches..."
	@echo "Cleaning Rust artifacts..."
	cargo clean
	@echo "Cleaning frontend artifacts..."
	cd frontend && rm -rf .svelte-kit build dist node_modules/.cache
	@echo "Cleaning Docker resources..."
	docker compose down -v || true
	docker system prune -f || true
	@echo "Cleanup complete!"

reindex:
	@echo "Rebuilding search index..."
	cargo run --bin reindex -- --space all

logs:
	@echo "Showing development logs..."
	docker compose logs -f
