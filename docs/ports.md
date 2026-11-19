# Nebron Port Mapping & Network Allocation

All microservices and backing infrastructure services in the Nebron local development stack are exposed directly on the host machine to allow straightforward testing, browser access, and direct integration with local client apps (web and mobile).

## Port Map Table

| Service | Host Port | Container Name | Protocol | Purpose |
|---|---|---|---|---|
| **mongo** | `27017` | `mongo` | TCP | MongoDB database for `auth-service` and `core-api` |
| **redis** | `6379` | `redis` | TCP | Redis instance for rate limiting, pub/sub, streams (`nebron.events`), and presence |
| **scylla** | `9042` | `scylla` | TCP | ScyllaDB CQL native port for chat history and messaging |
| **minio S3** | `9000` | `minio` | HTTP | S3 API endpoint for avatars and media uploads (dev substitute for Cloudflare R2) |
| **minio UI** | `9001` | `minio` | HTTP | MinIO Web Console dashboard (login with `minioadmin` / `minioadmin`) |
| **livekit** | `7880` | `livekit` | HTTP/WS | LiveKit WebRTC signaling HTTP and WebSocket endpoint |
| **livekit** | `7881` | `livekit` | TCP | WebRTC RTC TCP fallback port |
| **livekit** | `50000-50050/udp` | `livekit` | UDP | WebRTC media UDP port range for audio/video streaming |
| **auth** | `4001` | `auth` | HTTP | Auth API service (registration, login, refresh, JWKS, identity) |
| **core** | `4002` | `core` | HTTP | Core API service (profiles, preferences, metadata, media uploads) |
| **chat** | `4003` | `chat` | HTTP/WS | Chat API & real-time messaging WebSocket service |
| **voice** | `4004` | `voice` | HTTP | Voice room management and audio control plane |

## Client Access Architecture

When developing frontend clients (`web-frontend`, `mobile-app`, or `desktop-app`):
- Frontend applications run natively on the host machine (e.g. `http://localhost:3000` or React Native Metro packager).
- Frontend applications communicate directly with each microservice via `http://localhost:<port>`.
- Internal service-to-service communication within Docker Compose occurs over the dedicated bridge network (`infra_nebron`) using internal DNS service names:
  - `http://auth:4001`
  - `http://core:4002`
  - `http://chat:4003`
  - `http://voice:4004`
  - `mongodb://mongo:27017`
  - `redis://redis:6379`
  - `scylla:9042`
  - `http://minio:9000`
  - `ws://livekit:7880`
