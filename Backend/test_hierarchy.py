import urllib.request
import json
import uuid
import sys

base_url = "http://localhost:8080/api"
email = f"admin_{uuid.uuid4().hex[:8]}@hierarchy.com"

print("1. Registering user...")
req = urllib.request.Request(f"{base_url}/auth/register", data=json.dumps({
    "email": email,
    "password": "password123",
    "display_name": "Admin User"
}).encode(), headers={"Content-Type": "application/json"})

try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        token = res["data"]["token"]
        print(f"Token: {token[:20]}...")
except urllib.error.HTTPError as e:
    print("Registration failed:", e.read().decode())
    sys.exit(1)

print("\n2. Creating org...")
req = urllib.request.Request(f"{base_url}/organizations", data=json.dumps({
    "name": f"Hierarchy Corp {uuid.uuid4().hex[:8]}"
}).encode(), headers={
    "Content-Type": "application/json",
    "Authorization": f"Bearer {token}"
})
try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        org_id = res["data"]["id"]
        print(f"Org ID: {org_id}")
except urllib.error.HTTPError as e:
    print("Org creation failed:", e.read().decode())
    sys.exit(1)

print("\n3. Fetching hierarchy...")
req = urllib.request.Request(f"{base_url}/hierarchy", headers={
    "Authorization": f"Bearer {token}",
    "X-Org-Id": org_id
})
try:
    with urllib.request.urlopen(req) as response:
        res_hierarchy = json.loads(response.read().decode())
        print("Hierarchy Response:")
        print(json.dumps(res_hierarchy, indent=2))
        list_id = res_hierarchy["data"]["spaces"][0]["projects"][0]["lists"][0]["id"]
except urllib.error.HTTPError as e:
    print("Hierarchy fetch failed:", e.read().decode())
    sys.exit(1)

print(f"\n4. Creating task in list {list_id}...")
req = urllib.request.Request(f"{base_url}/tasks", data=json.dumps({
    "title": "Test Task 1",
    "description": "Hierarchy Test",
    "listId": list_id,
    "status": "todo",
    "priority": "medium"
}).encode(), headers={
    "Content-Type": "application/json",
    "Authorization": f"Bearer {token}",
    "X-Org-Id": org_id
})
try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        task_id = res["data"]["id"]
        print(f"Task ID: {task_id}")
except urllib.error.HTTPError as e:
    print("Task creation failed:", e.read().decode())
    sys.exit(1)

print(f"\n5. Fetching tasks for list {list_id}...")
req = urllib.request.Request(f"{base_url}/lists/{list_id}/tasks", headers={
    "Authorization": f"Bearer {token}",
    "X-Org-Id": org_id
})
try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        print(f"Tasks in list: {len(res['data'])}")
        if len(res['data']) > 0:
            print("✅ Task successfully retrieved from list!")
except urllib.error.HTTPError as e:
    print("List tasks fetch failed:", e.read().decode())
    sys.exit(1)

print(f"\n6. Creating second list in project...")
project_id = res_hierarchy["data"]["spaces"][0]["projects"][0]["project"]["id"]
req = urllib.request.Request(f"{base_url}/projects/{project_id}/lists", data=json.dumps({
    "name": "Second List"
}).encode(), headers={
    "Content-Type": "application/json",
    "Authorization": f"Bearer {token}",
    "X-Org-Id": org_id
})
try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        second_list_id = res["data"]["id"]
        print(f"Second List ID: {second_list_id}")
except urllib.error.HTTPError as e:
    print("Second list creation failed:", e.read().decode())
    sys.exit(1)

print(f"\n7. Moving task to second list...")
req = urllib.request.Request(f"{base_url}/tasks/{task_id}/move", data=json.dumps({
    "targetListId": second_list_id,
    "position": 500.0
}).encode(), headers={
    "Content-Type": "application/json",
    "Authorization": f"Bearer {token}",
    "X-Org-Id": org_id
}, method="PATCH")
try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        print("Move Response Data:")
        print(json.dumps(res["data"], indent=2))
        updated_list_id = res['data'].get('list_id') or res['data'].get('listId')
        print(f"Task updated list: {updated_list_id}")
        if updated_list_id == second_list_id:
            print("✅ Task successfully moved!")
except urllib.error.HTTPError as e:
    print("Task move failed:", e.read().decode())
    sys.exit(1)
