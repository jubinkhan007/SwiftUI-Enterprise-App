#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Live OCC (Optimistic Concurrency Control) Conflict Resolution Simulation
# ==============================================================================
# Validates live concurrency against http://127.0.0.1:8080:
#   1. Creates a task (version 1)
#   2. Client A updates title to "Client A Title" (succeeds -> version 2)
#   3. Client B attempts update with stale expectedVersion: 1 (fails -> 409 Conflict)
#   4. Client B resolves with "Keep Mine" retrying with expectedVersion: 2 (succeeds -> version 3)
#   5. Deletes the test task
# ==============================================================================

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
EMAIL="${EMAIL:-alice@acme.com}"
PASSWORD="${PASSWORD:-Password123!}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  Starting Live OCC Conflict Resolution Simulation against ${BASE_URL}${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# 1. Health check
echo -n "Checking Backend Server Health... "
HEALTH_RESP=$(curl -s "${BASE_URL}/health")
if [[ "$HEALTH_RESP" == *"ok"* ]]; then
  echo -e "${GREEN}✓ Online${NC}"
else
  echo -e "${RED}✗ Backend server not responding at ${BASE_URL}${NC}"
  exit 1
fi

# 2. Authentication
echo -n "Authenticating as ${EMAIL}... "
AUTH_JSON=$(curl -s -X POST "${BASE_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")

TOKEN=$(echo "$AUTH_JSON" | python3 -c 'import sys, json; data=json.load(sys.stdin); print(data.get("data", {}).get("token", ""))')
if [[ -z "$TOKEN" ]]; then
  echo -e "${RED}✗ Failed to authenticate${NC}"
  echo "$AUTH_JSON"
  exit 1
fi
echo -e "${GREEN}✓ Authenticated${NC}"

# 3. Retrieve Organization ID and List ID
echo -n "Fetching Workspace Context (/api/me)... "
ME_JSON=$(curl -s -X GET "${BASE_URL}/api/me" -H "Authorization: Bearer ${TOKEN}")
ORG_ID=$(echo "$ME_JSON" | python3 -c 'import sys, json; data=json.load(sys.stdin); orgs=data.get("data", {}).get("organizations", []); print(orgs[0]["id"] if orgs else "")')
if [[ -z "$ORG_ID" ]]; then
  echo -e "${RED}✗ No organization found${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Org ID: ${ORG_ID}${NC}"

echo -n "Fetching List & Status IDs... "
TASKS_JSON=$(curl -s -X GET "${BASE_URL}/api/tasks" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Org-Id: ${ORG_ID}")

LIST_ID=$(echo "$TASKS_JSON" | python3 -c 'import sys, json; data=json.load(sys.stdin); tasks=data.get("data", []); print(tasks[0]["list_id"] if tasks else "")')
STATUS_ID=$(echo "$TASKS_JSON" | python3 -c 'import sys, json; data=json.load(sys.stdin); tasks=data.get("data", []); print(tasks[0]["status_id"] if tasks else "")')

if [[ -z "$LIST_ID" || -z "$STATUS_ID" ]]; then
  echo -e "${RED}✗ Could not obtain list_id or status_id${NC}"
  exit 1
fi
echo -e "${GREEN}✓ List ID: ${LIST_ID}, Status ID: ${STATUS_ID}${NC}"

# 4. Step 1: Create a test task (expected initial version: 1)
TIMESTAMP=$(date +%s)
TASK_TITLE="OCC-Test-Task-${TIMESTAMP}"
echo -e "\n${YELLOW}[Step 1] Creating Task: '${TASK_TITLE}'...${NC}"

CREATE_PAYLOAD=$(cat <<EOF
{
  "title": "${TASK_TITLE}",
  "listId": "${LIST_ID}",
  "statusId": "${STATUS_ID}",
  "taskType": "task",
  "priority": "medium"
}
EOF
)

CREATE_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/tasks" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Org-Id: ${ORG_ID}" \
  -H "Content-Type: application/json" \
  -d "$CREATE_PAYLOAD")

HTTP_STATUS=$(echo "$CREATE_RESP" | tail -n1)
BODY=$(echo "$CREATE_RESP" | sed '$d')

if [[ "$HTTP_STATUS" -ne 200 ]]; then
  echo -e "${RED}✗ Failed to create task. HTTP ${HTTP_STATUS}${NC}"
  echo "$BODY"
  exit 1
fi

TASK_ID=$(echo "$BODY" | python3 -c 'import sys, json; print(json.load(sys.stdin)["data"]["id"])')
INITIAL_VERSION=$(echo "$BODY" | python3 -c 'import sys, json; print(json.load(sys.stdin)["data"]["version"])')

echo -e "${GREEN}✓ Task created: ID = ${TASK_ID}, Version = ${INITIAL_VERSION}${NC}"
if [[ "$INITIAL_VERSION" -ne 1 ]]; then
  echo -e "${RED}Expected version 1, got ${INITIAL_VERSION}${NC}"
  exit 1
fi

# 5. Step 2: Client A updates task with expectedVersion = 1 (succeeds -> version 2)
echo -e "\n${YELLOW}[Step 2] Client A updates title to 'Client A Title' with expectedVersion=1...${NC}"

CLIENT_A_PAYLOAD=$(cat <<EOF
{
  "title": "Client A Title",
  "expectedVersion": 1
}
EOF
)

CLIENT_A_RESP=$(curl -s -i -X PUT "${BASE_URL}/api/tasks/${TASK_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Org-Id: ${ORG_ID}" \
  -H "Content-Type: application/json" \
  -d "$CLIENT_A_PAYLOAD")

CLIENT_A_STATUS=$(echo "$CLIENT_A_RESP" | grep -E "^HTTP" | awk '{print $2}' | tail -n1)
CLIENT_A_ETAG=$(echo "$CLIENT_A_RESP" | grep -i "^etag:" | awk '{print $2}' | tr -d '\r')
CLIENT_A_BODY=$(echo "$CLIENT_A_RESP" | awk '/^\r?$/ {found=1; next} found')
VERSION_AFTER_A=$(echo "$CLIENT_A_BODY" | python3 -c 'import sys, json; print(json.load(sys.stdin)["data"]["version"])')

if [[ "$CLIENT_A_STATUS" -eq 200 && "$VERSION_AFTER_A" -eq 2 ]]; then
  echo -e "${GREEN}✓ Client A update succeeded: HTTP 200, Version = ${VERSION_AFTER_A}, ETag = ${CLIENT_A_ETAG}${NC}"
else
  echo -e "${RED}✗ Client A update unexpected result. HTTP ${CLIENT_A_STATUS}, Version = ${VERSION_AFTER_A}${NC}"
  exit 1
fi

# 6. Step 3: Client B attempts to update task with stale expectedVersion = 1 (fails -> 409 Conflict)
echo -e "\n${YELLOW}[Step 3] Client B attempts update with STALE expectedVersion=1 (simulating concurrent overwrite)...${NC}"

CLIENT_B_STALE_PAYLOAD=$(cat <<EOF
{
  "title": "Client B Overwrite Attempt",
  "expectedVersion": 1
}
EOF
)

CLIENT_B_RESP=$(curl -s -i -X PUT "${BASE_URL}/api/tasks/${TASK_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Org-Id: ${ORG_ID}" \
  -H "Content-Type: application/json" \
  -d "$CLIENT_B_STALE_PAYLOAD")

CLIENT_B_STATUS=$(echo "$CLIENT_B_RESP" | grep -E "^HTTP" | awk '{print $2}' | tail -n1)
CLIENT_B_ETAG=$(echo "$CLIENT_B_RESP" | grep -i "^etag:" | awk '{print $2}' | tr -d '\r')
CLIENT_B_BODY=$(echo "$CLIENT_B_RESP" | awk '/^\r?$/ {found=1; next} found')

if [[ "$CLIENT_B_STATUS" -eq 409 ]]; then
  CONFLICT_SERVER_TITLE=$(echo "$CLIENT_B_BODY" | python3 -c 'import sys, json; print(json.load(sys.stdin)["data"]["title"])')
  CONFLICT_SERVER_VER=$(echo "$CLIENT_B_BODY" | python3 -c 'import sys, json; print(json.load(sys.stdin)["data"]["version"])')
  echo -e "${GREEN}✓ Server correctly issued 409 Conflict!${NC}"
  echo -e "  - Server ETag: ${CLIENT_B_ETAG}"
  echo -e "  - Server Snapshot Version: ${CONFLICT_SERVER_VER}"
  echo -e "  - Server Snapshot Title: '${CONFLICT_SERVER_TITLE}'"
else
  echo -e "${RED}✗ Expected HTTP 409 Conflict, received HTTP ${CLIENT_B_STATUS}${NC}"
  echo "$CLIENT_B_BODY"
  exit 1
fi

# 7. Step 4: Client B resolves with "Keep Mine" strategy by submitting with expectedVersion = 2
echo -e "\n${YELLOW}[Step 4] Client B resolves conflict using 'Keep Mine' (retrying with expectedVersion=2)...${NC}"

CLIENT_B_RESOLVED_PAYLOAD=$(cat <<EOF
{
  "title": "Client B Resolved (Keep Mine)",
  "expectedVersion": ${CONFLICT_SERVER_VER}
}
EOF
)

CLIENT_B_RESOLVED_RESP=$(curl -s -i -X PUT "${BASE_URL}/api/tasks/${TASK_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Org-Id: ${ORG_ID}" \
  -H "Content-Type: application/json" \
  -d "$CLIENT_B_RESOLVED_PAYLOAD")

RESOLVED_STATUS=$(echo "$CLIENT_B_RESOLVED_RESP" | grep -E "^HTTP" | awk '{print $2}' | tail -n1)
RESOLVED_ETAG=$(echo "$CLIENT_B_RESOLVED_RESP" | grep -i "^etag:" | awk '{print $2}' | tr -d '\r')
RESOLVED_BODY=$(echo "$CLIENT_B_RESOLVED_RESP" | awk '/^\r?$/ {found=1; next} found')
VERSION_AFTER_RESOLVED=$(echo "$RESOLVED_BODY" | python3 -c 'import sys, json; print(json.load(sys.stdin)["data"]["version"])')
FINAL_TITLE=$(echo "$RESOLVED_BODY" | python3 -c 'import sys, json; print(json.load(sys.stdin)["data"]["title"])')

if [[ "$RESOLVED_STATUS" -eq 200 && "$VERSION_AFTER_RESOLVED" -eq 3 ]]; then
  echo -e "${GREEN}✓ Client B resolution succeeded: HTTP 200, Version = ${VERSION_AFTER_RESOLVED}, ETag = ${RESOLVED_ETAG}${NC}"
  echo -e "  - Final Task Title: '${FINAL_TITLE}'"
else
  echo -e "${RED}✗ Resolution failed. HTTP ${RESOLVED_STATUS}, Version = ${VERSION_AFTER_RESOLVED}${NC}"
  exit 1
fi

# 8. Step 5: Clean up test task
echo -e "\n${YELLOW}[Step 5] Cleaning up test task...${NC}"
DELETE_RESP=$(curl -s -w "%{http_code}" -X DELETE "${BASE_URL}/api/tasks/${TASK_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Org-Id: ${ORG_ID}")

if [[ "$DELETE_RESP" == "200" || "$DELETE_RESP" == "204" ]]; then
  echo -e "${GREEN}✓ Test task successfully deleted.${NC}"
else
  echo -e "${YELLOW}! Delete returned HTTP ${DELETE_RESP} (task may have been soft-deleted).${NC}"
fi

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${GREEN}  ✓ OCC Conflict Resolution Simulation Completed Successfully with 100% Pass Rate!${NC}"
echo -e "${BLUE}==============================================================================${NC}"
