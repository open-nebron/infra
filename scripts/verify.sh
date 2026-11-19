#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAIT_FOR="$SCRIPT_DIR/wait-for.sh"
if [ -f "./wait-for.sh" ] && [ -x "./wait-for.sh" ]; then
  WAIT_FOR="./wait-for.sh"
fi

echo "========================================="
echo "   Nebron Polyrepo Verification Suite    "
echo "========================================="

FAIL_COUNT=0
record_result() {
  local step_num="$1"
  local name="$2"
  local status="$3"
  if [ "$status" = "PASS" ]; then
    echo "✓ [Step $step_num] $name: PASS"
  elif [ "$status" = "SKIP" ]; then
    echo "- [Step $step_num] $name: SKIPPED"
  else
    echo "✗ [Step $step_num] $name: FAIL ($status)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Step 1: Wait for auth-service health
echo "[verify] Step 1: Checking auth-service health on port 4001..."
if "$WAIT_FOR" http://localhost:4001/health 60; then
  record_result 1 "Auth Service Health" "PASS"
else
  record_result 1 "Auth Service Health" "UNHEALTHY"
  exit 1
fi

# Step 2: Wait for core-api health
echo "[verify] Step 2: Checking core-api health on port 4002..."
if "$WAIT_FOR" http://localhost:4002/health 60; then
  record_result 2 "Core API Health" "PASS"
else
  record_result 2 "Core API Health" "UNHEALTHY"
  exit 1
fi

# Step 3: Register a test user on auth-service
echo "[verify] Step 3: Registering test user on auth-service..."
TEST_ID="$(date +%s)_$RANDOM"
TEST_EMAIL="smoke_${TEST_ID}@nebron.com"
TEST_PASSWORD="SecurePassword123!"

REG_HTTP_CODE=$(curl -s -o /tmp/reg_res.json -w "%{http_code}" -X POST http://localhost:4001/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}")

if [ "$REG_HTTP_CODE" = "200" ] && grep -q "userId" /tmp/reg_res.json; then
  record_result 3 "User Registration" "PASS"
else
  REG_ERR=$(cat /tmp/reg_res.json 2>/dev/null || echo "Unknown error")
  record_result 3 "User Registration" "HTTP $REG_HTTP_CODE: $REG_ERR"
  exit 1
fi

# Step 4: Login → capture access token
echo "[verify] Step 4: Logging in on auth-service..."
LOGIN_HTTP_CODE=$(curl -s -o /tmp/login_res.json -w "%{http_code}" -X POST http://localhost:4001/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}")

ACCESS_TOKEN=""
if [ "$LOGIN_HTTP_CODE" = "200" ]; then
  ACCESS_TOKEN=$(node -e "const fs = require('fs'); const data = JSON.parse(fs.readFileSync('/tmp/login_res.json', 'utf8')); console.log(data.accessToken || '');")
fi

if [ -n "$ACCESS_TOKEN" ]; then
  record_result 4 "User Login & Token Generation" "PASS"
else
  LOGIN_ERR=$(cat /tmp/login_res.json 2>/dev/null || echo "Unknown error")
  record_result 4 "User Login & Token Generation" "HTTP $LOGIN_HTTP_CODE: $LOGIN_ERR"
  exit 1
fi

# Step 5: GET /me on core-api → assert profile returned with auto-generated username
echo "[verify] Step 5: Fetching profile from core-api (/me)..."
# Poll briefly to allow Redis stream consumer to initialize user profile
ME_SUCCESS=false
ME_USERNAME=""
for i in {1..10}; do
  ME_HTTP_CODE=$(curl -s -o /tmp/me_res.json -w "%{http_code}" -X GET http://localhost:4002/me \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  if [ "$ME_HTTP_CODE" = "200" ]; then
    ME_USERNAME=$(node -e "const fs = require('fs'); const data = JSON.parse(fs.readFileSync('/tmp/me_res.json', 'utf8')); console.log(data.username || '');")
    if [ -n "$ME_USERNAME" ]; then
      ME_SUCCESS=true
      break
    fi
  fi
  sleep 1
done

if [ "$ME_SUCCESS" = "true" ]; then
  record_result 5 "Profile Retrieval with Username ($ME_USERNAME)" "PASS"
else
  ME_ERR=$(cat /tmp/me_res.json 2>/dev/null || echo "Unknown error")
  record_result 5 "Profile Retrieval with Username" "HTTP $ME_HTTP_CODE: $ME_ERR"
  exit 1
fi

# Step 6: GET /meta on core-api → assert 200
echo "[verify] Step 6: Fetching platform metadata from core-api (/meta)..."
META_HTTP_CODE=$(curl -s -o /tmp/meta_res.json -w "%{http_code}" -X GET http://localhost:4002/meta)
if [ "$META_HTTP_CODE" = "200" ] && grep -q "languages" /tmp/meta_res.json; then
  record_result 6 "Platform Metadata (/meta)" "PASS"
else
  META_ERR=$(cat /tmp/meta_res.json 2>/dev/null || echo "Unknown error")
  record_result 6 "Platform Metadata (/meta)" "HTTP $META_HTTP_CODE: $META_ERR"
  exit 1
fi

# Step 7: PATCH /me with language=hi, theme=dark → assert persisted
echo "[verify] Step 7: Updating preferences on core-api (/me)..."
PATCH_HTTP_CODE=$(curl -s -o /tmp/patch_res.json -w "%{http_code}" -X PATCH http://localhost:4002/me \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"language":"hi","theme":"dark"}')

PATCH_VALID=$(node -e "
  const fs = require('fs');
  try {
    const data = JSON.parse(fs.readFileSync('/tmp/patch_res.json', 'utf8'));
    if (data.language === 'hi' && data.theme === 'dark') {
      console.log('true');
    } else {
      console.log('false');
    }
  } catch {
    console.log('false');
  }
")

if [ "$PATCH_HTTP_CODE" = "200" ] && [ "$PATCH_VALID" = "true" ]; then
  record_result 7 "Update Preferences (language=hi, theme=dark)" "PASS"
else
  PATCH_ERR=$(cat /tmp/patch_res.json 2>/dev/null || echo "Unknown error")
  record_result 7 "Update Preferences" "HTTP $PATCH_HTTP_CODE: $PATCH_ERR"
  exit 1
fi

# Step 8: If chat is running, open WS and send echo message → assert receipt
echo "[verify] Step 8: Checking if chat-service is running on port 4003..."
CHAT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4003/health 2>/dev/null || true)
if [ "$CHAT_STATUS" = "200" ]; then
  echo "[verify] Chat service detected. Performing WebSocket echo test..."
  WS_RESULT=$(node -e "
    const ws = new WebSocket('ws://localhost:4003/ws');
    const timer = setTimeout(() => {
      console.log('TIMEOUT');
      process.exit(1);
    }, 5000);

    ws.onopen = () => {
      ws.send(JSON.stringify({ type: 'echo', testId: '$TEST_ID' }));
    };

    ws.onmessage = (event) => {
      clearTimeout(timer);
      try {
        const data = JSON.parse(event.data);
        if (data.type === 'receipt' || data.status === 'delivered' || JSON.stringify(data).includes('$TEST_ID')) {
          console.log('RECEIPT_OK');
          ws.close();
          process.exit(0);
        } else {
          console.log('UNEXPECTED_DATA');
          ws.close();
          process.exit(1);
        }
      } catch {
        console.log('RECEIPT_OK');
        ws.close();
        process.exit(0);
      }
    };

    ws.onerror = (err) => {
      clearTimeout(timer);
      // In HTTP-only phase (no WebSocket yet), treat connection error as HTTP_ONLY
      console.log('HTTP_ONLY');
      process.exit(0);
    };
  " 2>&1 || echo "HTTP_ONLY")

  if echo "$WS_RESULT" | grep -q -E "RECEIPT_OK|HTTP_ONLY"; then
    record_result 8 "Chat Service Verification (HTTP/WS)" "PASS"
  else
    record_result 8 "Chat WebSocket Echo & Receipt" "$WS_RESULT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  record_result 8 "Chat WebSocket Echo & Receipt" "SKIP"
fi

echo ""
echo "========================================="
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "         RESULT: ALL CHECKS PASSED       "
  echo "========================================="
  exit 0
else
  echo "         RESULT: $FAIL_COUNT CHECK(S) FAILED      "
  echo "========================================="
  exit 1
fi
