#!/bin/bash
set -x

BASE_URL="http://localhost:8080/api"

echo "=== 1. Setup Alice and Acme Corp ==="
ALICE_TOKEN=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "alice2@example.com", "password": "Password123!", "display_name": "Alice"}' | jq -r '.data.token')

ORG_A_ID=$(curl -s -X POST "$BASE_URL/organizations" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Org", "description": "Isolated"}' | jq -r '.data.id')

echo "=== 2. Alice creates a task in Alice Org ==="
TASK_ID=$(curl -s -X POST "$BASE_URL/tasks" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Org-Id: $ORG_A_ID" \
  -H "Content-Type: application/json" \
  -d '{"title": "Alice Secret Task"}' | jq -r '.data.id')
echo "Task ID: $TASK_ID"

echo -e "\n=== 3. Register Bob and create Bob Org ==="
BOB_TOKEN=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "bob2@example.com", "password": "Password123!", "display_name": "Bob"}' | jq -r '.data.token')

ORG_B_ID=$(curl -s -X POST "$BASE_URL/organizations" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob Org"}' | jq -r '.data.id')

echo -e "\n=== 4. Bob tries to list Alice's task (Should be empty or Bob Org tasks only) ==="
# Bob is NOT a member of Alice Org, so he can't even use Org A ID in header
# If he tries to list tasks with Org B ID, he shouldn't see Alice's task
curl -s -X GET "$BASE_URL/tasks" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "X-Org-Id: $ORG_B_ID" | jq '.data | length'

echo -e "\n=== 5. Bob tries to access Alice's task directly (Should fail with 403 or 404) ==="
# Alice's task is scoped to Org A.
# Bob shouldn't be able to see it even if he knows the ID.
curl -s -I -X GET "$BASE_URL/tasks/$TASK_ID" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "X-Org-Id: $ORG_B_ID" | grep HTTP
