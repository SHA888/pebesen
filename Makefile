.PHONY: help dev migrate test lint reindex

# Default target
help:
	@echo "Available commands:"
	@echo "  dev      - Start development environment"
	@echo "  migrate  - Run database migrations"
	@echo "  test     - Run all tests"
	@echo "  lint     - Run all linters"
	@echo "  reindex  - Rebuild search index"

# Development
dev:
	@echo "Starting development environment..."
	docker compose up -d postgres redis meilisearch
	@echo "Starting Rust development server..."
	cargo watch -x run &
	@echo "Starting frontend development server..."
	cd frontend && pnpm dev &
	@echo "Development environment started!"
	@echo "Frontend: http://localhost:5173"
	@echo "Backend: http://localhost:3000 (when implemented)"

# Database
migrate:
	@echo "Running database migrations..."
	docker exec -i pebesen_postgres psql -U pebesen -d pebesen < migrations/0001_extensions.sql

# Testing
test:
	@echo "Running Rust tests..."
	cargo test --all
	@echo "Running frontend tests..."
	cd frontend && pnpm test

# Linting
lint:
	@echo "Running Rust linters..."
	cargo fmt --check
	cargo clippy -- -D warnings
	@echo "Running frontend linters..."
	cd frontend && pnpm lint

# Search indexing
reindex:
	@echo "Rebuilding search index..."
	cargo run --bin reindex -- --space all
