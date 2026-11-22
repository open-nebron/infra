# Production Architecture & Transition Path

## Scope & Purpose

> [!IMPORTANT]
> The Docker Compose configuration in this repository (`infra`) is designed **strictly for local development and single-node staging environments**. It is NOT the deployment mechanism for production.

In production, microservices are deployed as stateless container workloads orchestrated via **Kubernetes (Helm)** or managed container platforms (such as AWS ECS, Google Cloud Run, or Fly.io).

---

## Managed Services Migration Matrix

The local Docker Compose environment utilizes containerized stand-ins for cloud services. In production, these containers are replaced by high-availability managed cloud platforms simply by changing environment variables—**no application code modifications are required**.

| Local Service | Production Replacement | Connection Env Var | Production Benefits |
|---|---|---|---|
| `mongo` | **MongoDB Atlas** (M0+ / Dedicated) | `MONGO_URL=mongodb+srv://...` | Automated backups, multi-AZ replication, horizontal sharding |
| `scylla` | **ScyllaDB Cloud** (or K8s Scylla Operator) | `SCYLLA_HOSTS=...` | Enterprise SLAs, node auto-repair, zero-downtime upgrades |
| `redis` | **Upstash Redis** or **AWS ElastiCache** | `REDIS_URL=rediss://...` | Serverless auto-scaling, replication clusters, multi-AZ failover |
| `livekit` | **LiveKit Cloud** (5k free min/month) | `LIVEKIT_URL=wss://...` | Global edge distribution, auto-scaling media SFUs, TURN relay |
| `minio` | **Cloudflare R2** (Real Object Storage) | `R2_ENDPOINT=https://<id>.r2.cloudflarestorage.com` | Zero egress fees, global edge CDN, unlimited durable object storage |

---

## CI/CD Pipeline & Image Lifecycle

This repository does **not** manage deployment pipelines or images for the sibling repositories. 

Each microservice repository owns its continuous integration and delivery lifecycle:
1. **Source Commits**: Developer pushes to `main` in `auth-service`, `core-api`, `chat-service`, or `voice-service`.
2. **Automated Testing**: Service GitHub Actions workflow runs linter, TypeScript build, and Vitest suite.
3. **Container Build**: Multi-stage Dockerfile builds the minimal production runner image.
4. **Registry Push**: Images are tagged by git commit SHA and semantic version, then pushed to GitHub Container Registry:
   - `ghcr.io/nebron/auth-service:<sha>`
   - `ghcr.io/nebron/core-api:<sha>`
   - `ghcr.io/nebron/chat-service:<sha>`
   - `ghcr.io/nebron/voice-service:<sha>`
5. **GitOps Deployment**: Kubernetes cluster synchronizes manifests (via ArgoCD or Flux) referencing the newly built image digest.

---

## Production Readiness Checklist

When moving from local dev to production:
- [ ] **Secrets Management**: Replace `.env` files with a secure secret store (e.g. AWS Secrets Manager, HashiCorp Vault, Kubernetes Secrets).
- [ ] **Cryptographic Keys**: Ensure `JWT_PRIVATE_KEY_PATH` and `JWT_PUBLIC_KEY_PATH` point to secure, rotated 2048-bit or 4096-bit RSA keys (never use auto-generated dev keys).
- [ ] **TLS Ingress**: Terminate TLS at the ingress controller (Cloudflare, AWS ALB, NGINX Ingress) with Let's Encrypt or custom SSL certificates.
- [ ] **Persistent Storage & Backups**: Configure point-in-time recovery (PITR) on MongoDB Atlas and ScyllaDB Cloud.
- [ ] **LiveKit Cloud Webhook Delivery**: LiveKit Cloud requires a publicly accessible HTTPS endpoint (e.g. `https://api.nebron.com/webhooks/livekit` or `https://voice.nebron.com/webhooks/livekit`) with valid public TLS certificates. In local development Docker Compose, webhooks use internal Docker network resolution (`http://voice:4004/webhooks/livekit`), but in staging and production, configure public webhook URLs in the LiveKit Cloud console and verify JWT webhook signatures with `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET`.
- [ ] **Observability**: Export OpenTelemetry traces and Prometheus metrics to Datadog, Grafana Cloud, or New Relic.
- [ ] **Rate Limiting & DDoS**: Enable Cloudflare WAF and enforce Redis-backed distributed rate limits across API gateways.
