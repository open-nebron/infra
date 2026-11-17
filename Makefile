.DEFAULT_GOAL := help
.PHONY: help up-all up-infra up-auth up-core up-chat up-voice up-messaging \
        down down-auth down-core down-chat down-voice \
        logs logs-auth logs-core logs-chat logs-voice \
        ps dev-auth dev-core dev-chat verify reset

help:
	@echo "Zenuxs Local Infrastructure Orchestration"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Lifecycle Targets:"
	@echo "  up-all        Build and start databases, cache, storage, WebRTC, and all 4 microservices in background"
	@echo "  up-infra      Build and start core databases and infrastructure only (Mongo, Redis, Scylla, MinIO, LiveKit)"
	@echo "  up-auth       Start infra dependencies and auth-service (port 4001)"
	@echo "  up-core       Start infra dependencies, auth-service, and core-api (port 4002)"
	@echo "  up-chat       Start infra dependencies, auth-service, and chat-service (port 4003)"
	@echo "  up-voice      Start infra dependencies, auth-service, and voice-service (port 4004)"
	@echo "  up-messaging  Start infra dependencies, auth-service, core-api, and chat-service"
	@echo "  down          Stop and remove all service and infrastructure containers"
	@echo "  down-auth     Stop and remove only the auth-service container"
	@echo "  down-core     Stop and remove only the core-api container"
	@echo "  down-chat     Stop and remove only the chat-service container"
	@echo "  down-voice    Stop and remove only the voice-service container"
	@echo ""
	@echo "Monitoring & Observability:"
	@echo "  ps            List all running containers and their health status"
	@echo "  logs          Tail logs for all services and infrastructure (last 100 lines)"
	@echo "  logs-auth     Tail logs for auth-service only"
	@echo "  logs-core     Tail logs for core-api only"
	@echo "  logs-chat     Tail logs for chat-service only"
	@echo "  logs-voice    Tail logs for voice-service only"
	@echo ""
	@echo "Development Mode (Hot Reload):"
	@echo "  dev-auth      Start auth-service in foreground development mode with live source bind mounts"
	@echo "  dev-core      Start core-api in foreground development mode with live source bind mounts"
	@echo "  dev-chat      Start chat-service in foreground development mode with live source bind mounts"
	@echo ""
	@echo "Validation & Cleanup:"
	@echo "  verify        Run automated end-to-end smoke tests and integration assertions"
	@echo "  reset         Wipe all containers, named volumes, and prune docker cache for a clean state"

up-all:
	docker compose --profile infra --profile auth --profile core --profile chat --profile voice up -d --build

up-infra:
	docker compose --profile infra up -d --build

up-auth:
	docker compose --profile infra --profile auth up -d --build

up-core:
	docker compose --profile infra --profile auth --profile core up -d --build

up-chat:
	docker compose --profile infra --profile auth --profile chat up -d --build

up-voice:
	docker compose --profile infra --profile auth --profile voice up -d --build

up-messaging:
	docker compose --profile infra --profile auth --profile core --profile chat up -d --build

down:
	docker compose --profile infra --profile auth --profile core --profile chat --profile voice down

down-auth:
	docker compose --profile '*' rm -sf auth

down-core:
	docker compose --profile '*' rm -sf core

down-chat:
	docker compose --profile '*' rm -sf chat

down-voice:
	docker compose --profile '*' rm -sf voice

logs:
	docker compose --profile infra --profile auth --profile core --profile chat --profile voice logs -f --tail=100

logs-auth:
	docker compose --profile '*' logs -f --tail=100 auth

logs-core:
	docker compose --profile '*' logs -f --tail=100 core

logs-chat:
	docker compose --profile '*' logs -f --tail=100 chat

logs-voice:
	docker compose --profile '*' logs -f --tail=100 voice

ps:
	docker compose --profile infra --profile auth --profile core --profile chat --profile voice ps

dev-auth:
	docker compose --profile infra --profile auth -f docker-compose.yml -f docker-compose.dev.yml up auth

dev-core:
	docker compose --profile infra --profile auth --profile core -f docker-compose.yml -f docker-compose.dev.yml up core

dev-chat:
	docker compose --profile infra --profile auth --profile chat -f docker-compose.yml -f docker-compose.dev.yml up chat

verify:
	./scripts/verify.sh

reset:
	docker compose --profile infra --profile auth --profile core --profile chat --profile voice down -v && docker system prune -f
