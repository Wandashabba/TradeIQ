.PHONY: setup dev app stop restart test backend-test app-test wait-for-db help

FLUTTER ?= flutter

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## One-time setup: start Postgres, install deps, migrate, seed
	@echo "==> Starting Postgres..."
	docker compose up -d
	@$(MAKE) wait-for-db
	@if [ ! -f backend/.env ]; then cp .env.example backend/.env; echo "==> Created backend/.env"; fi
	@echo "==> Installing backend dependencies..."
	cd backend && npm install
	@echo "==> Applying migrations..."
	cd backend && npx prisma migrate deploy
	@echo "==> Seeding demo data..."
	cd backend && npm run seed
	@echo ""
	@echo "==> Setup complete."
	@echo "    Run 'make dev' to start the backend, then in another terminal 'make app' for the Flutter app."

wait-for-db: ## Block until the Postgres container reports healthy
	@echo "==> Waiting for Postgres to become healthy..."
	@for i in $$(seq 1 30); do \
		status=$$(docker inspect --format='{{.State.Health.Status}}' tradeiq-postgres-1 2>/dev/null || echo "starting"); \
		if [ "$$status" = "healthy" ]; then echo "==> Postgres is healthy"; exit 0; fi; \
		sleep 1; \
	done; \
	echo "==> Postgres did not become healthy in time. Run 'docker compose logs postgres' to investigate." && exit 1

dev: ## Start Postgres (if needed) and the backend dev server
	docker compose up -d
	@$(MAKE) wait-for-db
	cd backend && npm run dev

app: ## Install deps and launch the Flutter app in Chrome (override Flutter binary with FLUTTER=/path/to/flutter)
	cd app && $(FLUTTER) pub get && $(FLUTTER) run -d chrome

test: backend-test app-test ## Run both test suites

backend-test: ## Lint + test the backend
	cd backend && npm run lint && npm test

app-test: ## Analyze + test the Flutter app
	cd app && $(FLUTTER) analyze && $(FLUTTER) test

stop: ## Stop Postgres
	docker compose down

restart: stop dev ## Stop and restart Postgres + backend dev server
