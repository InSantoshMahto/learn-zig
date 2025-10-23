.PHONY: help build run test clean docker-build docker-up docker-down docker-logs migrate dev install-deps

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

install-deps: ## Install system dependencies (macOS with Homebrew)
	@echo "Installing dependencies..."
	brew install postgresql@18 redis hiredis libpq
	@echo "Dependencies installed!"

build: ## Build the application
	zig build

run: ## Run the application
	zig build run

test: ## Run tests
	zig build test

clean: ## Clean build artifacts
	rm -rf zig-out zig-cache .zig-cache

docker-build: ## Build Docker image
	docker build -t zig-crud-api .

docker-up: ## Start services with Docker Compose
	docker compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 5
	@echo "Services are up!"

docker-down: ## Stop services with Docker Compose
	docker compose down

docker-logs: ## View Docker Compose logs
	docker compose logs -f

docker-restart: ## Restart Docker Compose services
	docker compose restart

migrate: ## Run database migrations
	@echo "Running migrations..."
	docker compose exec -T postgres psql -U postgres -d crud_api < migrations/001_create_users_table.sql
	@echo "Migrations completed!"

dev: docker-up migrate ## Start development environment
	@echo "Development environment ready!"
	@echo ""
	@echo "PostgreSQL: localhost:5432"
	@echo "Redis: localhost:6379"
	@echo ""
	@echo "Run 'make run' to start the API server"

db-connect: ## Connect to PostgreSQL database
	docker compose exec postgres psql -U postgres -d crud_api

redis-cli: ## Connect to Redis CLI
	docker compose exec redis redis-cli

curl-test: ## Test API endpoints with curl
	@echo "Testing API endpoints..."
	@echo "\n1. Health check:"
	curl -s http://localhost:8080/health | jq
	@echo "\n2. Get all users:"
	curl -s http://localhost:8080/api/users | jq
	@echo "\n3. Create user:"
	curl -s -X POST http://localhost:8080/api/users \
		-H "Content-Type: application/json" \
		-d '{"name":"Test User","email":"test@example.com"}' | jq
	@echo "\n4. Get user by ID:"
	curl -s http://localhost:8080/api/users/1 | jq

watch: ## Watch and rebuild on file changes (requires entr)
	find src -name '*.zig' | entr -r zig build run

format: ## Format Zig source files
	zig fmt src/

check: ## Check for compile errors without building
	zig build-exe src/main.zig --check

all: clean build ## Clean and build
