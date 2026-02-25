#!/bin/bash
set -x

BASE_URL="http://localhost:8080/api"
JQ_CMD="jq -r"

echo "=== 1. Register Alice ==="
ALICE_TOKEN=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "Password123!", "display_name": "Alice"}' | jq -r '.data.token')

if [ "$ALICE_TOKEN" == "null" ] || [ -z "$ALICE_TOKEN" ]; then
  echo "Failed to register Alice"
  exit 1
fi
echo "Alice Token: ${ALICE_TOKEN:0:10}..."

echo -e "\n=== 2. Register Bob ==="
BOB_TOKEN=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "bob@example.com", "password": "Password123!", "display_name": "Bob"}' | jq -r '.data.token')
echo "Bob Token: ${BOB_TOKEN:0:10}..."

echo -e "\n=== 3. Alice creates Acme Corp ==="
ORG_ID=$(curl -s -X POST "$BASE_URL/organizations" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Acme Corp", "description": "The best company"}' | jq -r '.data.id')
echo "Org ID: $ORG_ID"

echo -e "\n=== 4. Alice invites Bob as Manager ==="
INVITE_ID=$(curl -s -X POST "$BASE_URL/organizations/$ORG_ID/invites" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Org-Id: $ORG_ID" \
  -H "Content-Type: application/json" \
  -d '{"email": "bob@example.com", "role": "manager"}' | jq -r '.data.id')
echo "Invite ID: $INVITE_ID"

echo -e "\n=== 5. Alice checks audit log (Verify invite log) ==="
curl -s -X GET "$BASE_URL/organizations/$ORG_ID/audit-log" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Org-Id: $ORG_ID" | jq '.data[] | {action: .action, details: .details}'

echo -e "\n=== 6. Bob accepts invite ==="
curl -s -X POST "$BASE_URL/organizations/invites/$INVITE_ID/accept" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" | jq '.status'

echo -e "\n=== 7. Bob checks his workspaces ==="
curl -s -X GET "$BASE_URL/me" \
  -H "Authorization: Bearer $BOB_TOKEN" | jq '.data.organizations[] | {name: .name, role: .role}'

echo -e "\n=== 8. Alice checks members list ==="
curl -s -X GET "$BASE_URL/organizations/$ORG_ID/members" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Org-Id: $ORG_ID" | jq '.data[] | {name: .display_name, role: .role}'

echo -e "\n=== 9. Alice promotes Bob to Admin ==="
BOB_MEMBER_ID=$(curl -s -X GET "$BASE_URL/organizations/$ORG_ID/members" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Org-Id: $ORG_ID" | jq -r '.data[] | select(.email == "bob@example.com") | .id')

curl -s -X PUT "$BASE_URL/organizations/$ORG_ID/members/$BOB_MEMBER_ID/role" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Org-Id: $ORG_ID" \
  -H "Content-Type: application/json" \
  -d '{"role": "admin"}' | jq '.data | {name: .display_name, new_role: .role}'

echo -e "\n=== 10. Verify audit log again ==="
curl -s -X GET "$BASE_URL/organizations/$ORG_ID/audit-log" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Org-Id: $ORG_ID" | jq '.data[] | {action: .action, details: .details}'
