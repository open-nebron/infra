# Nebron Infrastructure (`infra`)

Local Docker Compose orchestration and infrastructure automation for the Nebron polyrepo.

---

## 1. What This Repo Is & What It Is NOT

### What this repo IS:
- **Local Developer Orchestration**: A unified, single-command Docker Compose environment that coordinates all databases, caches, storage emulators, WebRTC servers, and backend microservices locally.
- **Selective Service Runner**: Uses Compose profiles so engineers can run the entire stack (`make up-all`), only databases (`make up-infra`), or any targeted subset of services (e.g. `make up-auth`, `make up-core`, `make up-messaging`).
- **Development Tooling**: Provides hot-reload overrides with local source bind-mounts (`make dev-auth`, `make dev-core`, `make dev-chat`), end-to-end smoke verification (`make verify`), and clean reset mechanisms (`make reset`).

### What this repo is NOT:
- **NOT for Production Deployment**: Production workloads run on Kubernetes (Helm) or managed platforms. See [Production Transition Path](docs/production-path.md).
- **NOT a Code Monorepo**: Sibling microservices (`auth-service`, `core-api`, `chat-service`, `voice-service`) own their own source code, dependencies, tests, and CI workflows. This repo only references their Dockerfiles.
- **NOT a Load Balancer / TLS Manager**: In local development, microservices and databases expose host ports directly for rapid debugging and frontend connectivity.

---

## 2. Prerequisites

Ensure your host machine satisfies the following minimum requirements:
- **Docker Engine**: version 24.0 or newer
- **Docker Compose**: version 2.20 or newer (`docker compose version`)
- **System Memory**: 8 GB RAM minimum (16 GB recommended for full stack with ScyllaDB)
- **Disk Space**: 10 GB free disk space for container images and volumes
- **Tools**: `bash`, `curl`, `make`

---

## 3. Quickstart

Get the entire Nebron ecosystem up, running, and verified in under 5 minutes:

```bash
# 1. Enter the infra directory
cd infra

# 2. Copy the sample environment file
cp .env.example .env

# 3. Build and launch all infrastructure + microservices in the background
make up-all

# 4. Run automated end-to-end integration and smoke verification
make verify
```

---

## 4. Common Developer Workflows

### First-Time Setup
```bash
cp .env.example .env
make up-all
make ps
```

### Just Want Databases for Local Host Development
If you prefer running Node services directly on your host machine with `npm run dev`:
```bash
make up-infra
```
*Starts MongoDB (`27017`), Redis (`6379`), ScyllaDB (`9042`), MinIO (`9000`), and LiveKit (`7880`), running all database initializations automatically.*

### Working on Auth Only (Hot Reload)
To mount local source files and watch for changes without rebuilding images:
```bash
make dev-auth
```
*Binds `../auth-service/src` to `/app/src` inside the container for instant hot reloading.*

### Working on Core API (Hot Reload)
```bash
make dev-core
```
*Automatically brings up databases and auth-service (JWKS provider) before starting core-api.*

### Full Stack Verification
Run end-to-end smoke tests against live running containers:
```bash
make verify
```

### Wipe and Start Over Clean
To stop all containers, delete named volumes, and prune cached layers:
```bash
make reset
```

---

## 5. Port Map

All service endpoints and host ports are documented in detail in [docs/ports.md](docs/ports.md).

| Service | Port | Container Name | Purpose |
|---|---|---|---|
| **mongo** | `27017` | `mongo` | Core + auth MongoDB database |
| **redis** | `6379` | `redis` | Rate limits, pub/sub, presence, and `nebron.events` |
| **scylla** | `9042` | `scylla` | ScyllaDB CQL chat message store |
| **minio S3** | `9000` | `minio` | S3 API endpoint (dev substitute for Cloudflare R2) |
| **minio UI** | `9001` | `minio` | MinIO web console (`minioadmin` / `minioadmin`) |
| **livekit** | `7880` | `livekit` | WebRTC HTTP and WebSocket signaling |
| **auth** | `4001` | `auth` | Authentication API & JWKS server |
| **core** | `4002` | `core` | Core API (profiles, preferences, metadata) |
| **chat** | `4003` | `chat` | Real-time chat & WebSocket messaging |
| **voice** | `4004` | `voice` | Voice room management control plane |

---

## 6. Architecture & Service Discovery

### System Topology (ASCII)

```
                 +----------------------------------------------------+
                 |                   Host Machine                     |
                 |  Web Frontend (3000)      Mobile App / Metro       |
                 +---------+-------------------------+----------------+
                           |                         |
                           v                         v
+------------------------------------------------------------------------------------+
| Docker Network: infra_nebron                                                        |
|                                                                                    |
|   +-------------------+    HTTP JWKS     +-------------------+                     |
|   |   auth-service    |<=================|     core-api      |                     |
|   |    (port 4001)    |                  |    (port 4002)    |                     |
|   +----+---------+----+                  +----+---------+----+                     |
|        |         |                            |         |                          |
|        |         |  Redis Stream:             |         |                          |
|        |         |  nebron.events             |         |                          |
|        |         +-------------------+        |         |                          |
|        |                             v        |         |                          |
|        |                         +------------+---+     |                          |
|        |                         |     redis      |     |                          |
|        |                         |  (port 6379)   |     |                          |
|        |                         +-------+--------+     |                          |
|        |                                 ^              |                          |
|        v                                 |              v                          |
|   +----+--------------+                  |       +------+------------+             |
|   |       mongo       |                  |       |       minio       |             |
|   |   (port 27017)    |                  |       | (ports 9000/9001) |             |
|   +-------------------+                  |       +-------------------+             |
|                                          |                                         |
|   +-------------------+                  |       +-------------------+             |
|   |   chat-service    |------------------+       |   voice-service   |             |
|   |    (port 4003)    |                          |    (port 4004)    |             |
|   +----+---------+----+                          +----+---------+----+             |
|        |         |                                    |         |                  |
|        |         | HTTP JWKS                          |         | WebRTC           |
|        |         +------------> auth                  |         +--------+         |
|        v                                              v                  v         |
|   +----+--------------+                          +----+--------+   +-----+-------+ |
|   |      scylla       |                          |    auth     |   |   livekit   | |
|   |   (port 9042)     |                          | (HTTP JWKS) |   | (port 7880) | |
|   +-------------------+                          +-------------+   +-------------+ |
+------------------------------------------------------------------------------------+
```

### How Services Find Each Other
1. **Container DNS Resolution**:
   All containers attach to the shared `nebron` bridge network (`infra_nebron`). Docker's embedded DNS server resolves container names automatically (e.g. `http://auth:4001`, `mongodb://mongo:27017`, `redis://redis:6379`, `http://minio:9000`).
2. **Asymmetric Key Verification (JWKS)**:
   `auth-service` generates RS256 RSA keypairs and exposes public keys at `http://auth:4001/.well-known/jwks.json`. Verifying services (`core-api`, `chat`, `voice`) fetch and cache these public keys. They never talk through `core-api` to authenticate users.
3. **Domain Event Stream (`nebron.events`)**:
   Asynchronous integration is decoupled via Redis Streams. When a user registers in `auth-service`, an `auth.user.registered` event is published to `nebron.events`. `core-api` consumes this stream in the background to automatically create the initial profile record in `nebron_core`.

---

## 7. Makefile Command Reference

| Target | Description |
|---|---|
| `make help` | Display list of all available make targets with descriptions (default goal) |
| `make up-all` | Build and start all backing infra and 4 backend services in the background |
| `make up-infra` | Build and start backing databases and infrastructure only (Mongo, Redis, Scylla, MinIO, LiveKit) |
| `make up-auth` | Start backing infrastructure dependencies and `auth-service` |
| `make up-core` | Start backing infra, `auth-service` (JWKS), and `core-api` |
| `make up-chat` | Start backing infra, `auth-service` (JWKS), and `chat-service` |
| `make up-voice` | Start backing infra, `auth-service` (JWKS), and `voice-service` |
| `make up-messaging` | Start backing infra, `auth-service`, `core-api`, and `chat-service` |
| `make down` | Stop and remove all service and infrastructure containers |
| `make down-auth` | Stop and remove only the `auth-service` container |
| `make down-core` | Stop and remove only the `core-api` container |
| `make down-chat` | Stop and remove only the `chat-service` container |
| `make down-voice` | Stop and remove only the `voice-service` container |
| `make logs` | Tail logs for all services and infrastructure (last 100 lines) |
| `make logs-auth` | Tail logs for `auth-service` container |
| `make logs-core` | Tail logs for `core-api` container |
| `make logs-chat` | Tail logs for `chat-service` container |
| `make logs-voice` | Tail logs for `voice-service` container |
| `make ps` | Display status and health check state of all containers |
| `make dev-auth` | Start `auth-service` in foreground dev mode with live source bind mounts |
| `make dev-core` | Start `core-api` in foreground dev mode with live source bind mounts |
| `make dev-chat` | Start `chat-service` in foreground dev mode with live source bind mounts |
| `make verify` | Run automated end-to-end smoke tests and integration assertions |
| `make reset` | Tear down all containers, purge volumes, and clean docker build cache |

---

## 8. Documentation Index

- [Port Map & Network Table](docs/ports.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Production Architecture & Transition Path](docs/production-path.md)
