# Troubleshooting Guide

This guide covers common issues encountered when managing local development environments with Docker Compose in the Zenuxs polyrepo.

---

## 1. ScyllaDB takes up to 60 seconds to become healthy

### Symptoms
During `make up-all` or `make up-infra`, Docker Compose waits at `scylla` before proceeding to dependent services (`scylla-init`, `chat`), and `docker compose ps` shows `scylla` in a `(health: starting)` state.

### Cause
ScyllaDB is a distributed, high-performance database written in C++. On container startup, it performs initial hardware memory allocation, disk page formatting, and gossip protocol initialization before the native CQL protocol daemon binds and begins accepting queries.

### Resolution
This is expected behavior. The healthcheck has `start_period: 60s`, `interval: 15s`, and up to 20 retries:
```yaml
healthcheck:
  test: ["CMD-SHELL", "nodetool status 2>/dev/null | grep -q '^UN'"]
  interval: 15s
  timeout: 10s
  retries: 20
  start_period: 60s
```
Wait for `nodetool` to report `UN` (Up/Normal). You can check Scylla's live status at any time with:
```bash
docker compose exec scylla nodetool status
```

---

## 2. Port already in use (e.g. Port 27017 or 6379)

### Symptoms
Docker error: `Bind for 0.0.0.0:27017 failed: port is already allocated` or `listen tcp 0.0.0.0:6379: bind: address already in use`.

### Cause
A local instance of MongoDB (`mongod`), Redis (`redis-server`), or PostgreSQL is running directly on the host system as a background daemon (via systemd or brew).

### Resolution
Option A: Stop the host service:
```bash
sudo systemctl stop mongodb || sudo systemctl stop mongod
sudo systemctl stop redis-server || sudo systemctl stop redis
```

Option B: Identify and kill the occupying process:
```bash
sudo lsof -i :27017
sudo kill -9 <PID>
```

Option C: Change the host port mapping in `docker-compose.yml`:
For example, change `"27017:27017"` to `"27018:27017"`. Note that any direct host clients connecting to Mongo must use port `27018`.

---

## 3. "JWKS unavailable" or Token Signature Verification Fails

### Symptoms
`core-api`, `chat-service`, or `voice-service` log warnings or errors:
`[CoreAPI] JWKS initial load warning (will retry in background): fetch failed` or `Token missing sub claim`.

### Cause
`core-api`, `chat`, and `voice` rely on `http://auth:4001/.well-known/jwks.json` to verify incoming RS256 JWT tokens. If `auth` has not fully completed its database connection and key generation, token verification will fail.

### Resolution
1. Verify `auth` is healthy:
   ```bash
   curl -i http://localhost:4001/health
   curl -i http://localhost:4001/.well-known/jwks.json
   ```
2. Verify container networking:
   ```bash
   docker compose exec core wget -qO- http://auth:4001/.well-known/jwks.json
   ```
3. Restart `core-api`:
   ```bash
   make down-core && make up-core
   ```

---

## 4. MinIO Bucket Missing (`zenuxs-media`)

### Symptoms
Uploading avatars or banners fails with: `NoSuchBucket: The specified bucket does not exist`.

### Cause
The initialization container `minio-init` runs only once to create the `zenuxs-media` bucket and configure anonymous download policies for avatars. If MinIO's volume was wiped or corrupted without re-running initialization, the bucket may be absent.

### Resolution
Re-run the initialization job directly:
```bash
docker compose --profile infra up minio-init
```
Or perform a full stack reset:
```bash
make reset && make up-all
```

---

## 5. How to view container logs individually

Use the Makefile shortcuts:
```bash
make logs-auth    # auth-service logs
make logs-core    # core-api logs
make logs-chat    # chat-service logs
make logs-voice   # voice-service logs
```
Or use Docker Compose directly for any container:
```bash
docker compose logs -f --tail=100 mongo
docker compose logs -f --tail=100 redis
docker compose logs -f --tail=100 scylla
docker compose logs -f --tail=100 minio
docker compose logs -f --tail=100 livekit
```

---

## 6. How to exec into a container

You can open an interactive shell or CLI tool inside any running container:
- **MongoDB shell**:
  ```bash
  docker compose exec mongo mongosh
  ```
- **Redis CLI**:
  ```bash
  docker compose exec redis redis-cli
  ```
- **ScyllaDB CQL shell**:
  ```bash
  docker compose exec scylla cqlsh
  ```
- **MinIO MC client**:
  ```bash
  docker compose exec minio-init mc ls local/zenuxs-media
  ```
- **Application container shell**:
  ```bash
  docker compose exec auth sh
  docker compose exec core sh
  ```

---

## 7. How to wipe one service's data only

If you want to clear the state of a single service without resetting the entire stack:

```bash
# Example for MongoDB:
docker compose rm -sf mongo && docker volume rm infra_mongo_data

# Example for Redis:
docker compose rm -sf redis && docker volume rm infra_redis_data

# Example for ScyllaDB:
docker compose rm -sf scylla && docker volume rm infra_scylla_data

# Example for MinIO:
docker compose rm -sf minio && docker volume rm infra_minio_data
```
Then restart the service and its init job:
```bash
make up-infra
```
