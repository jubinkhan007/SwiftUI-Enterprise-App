#!/bin/bash
set -e

BASE_URL="http://localhost:8080/api"

echo "1. Registering User..."
RES=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin6@hierarchy.com", "password":"password123", "display_name":"Admin User", "organization_name":"Hierarchy Corp"}')

TOKEN=$(echo "$RES" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['token'])")
echo "Token: $TOKEN"

echo -e "\n2. Fetching Me (to get Org ID)..."
ME_RES=$(curl -s -X GET "$BASE_URL/me" \
  -H "Authorization: Bearer $TOKEN")
ORG_ID=$(echo "$ME_RES" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['organizations'][0]['id'])")
echo "Org ID: $ORG_ID"

echo -e "\n3. Fetching Hierarchy (Expect auto-generated defaults from Migration 2)..."
HIERARCHY_RES=$(curl -s -X GET "$BASE_URL/hierarchy" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Org-Id: $ORG_ID")

echo "$HIERARCHY_RES"
echo "$HIERARCHY_RES" | grep '"name":"Default Space"' > /dev/null && echo "✅ Default Space Found!" || echo "❌ Failed to find Default Space"
