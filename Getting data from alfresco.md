## Getting name  of sites
```
curl -s -u admin:admin \
  "http://localhost:8080/alfresco/api/-default-/public/alfresco/versions/1/sites?maxItems=1000" \
  | jq -r '.list.entries[].entry.id'
```
## Getting number of files
```
SITE_ID="icircular"
BASE_URL="http://localhost:8080/alfresco"
AUTH="admin:admin"

curl -s -u "$AUTH" -H "Content-Type: application/json" \
  -d @- "$BASE_URL/api/-default-/public/search/versions/1/search" <<EOF \
  | jq '.list.pagination.totalItems'
{
  "query": {
    "language": "afts",
    "query": "TYPE:\"cm:content\" AND PATH:\"/app:company_home/st:sites/cm:${SITE_ID}/cm:documentLibrary//*\""
  },
  "paging": {
    "maxItems": 1,
    "skipCount": 0
  }
}
EOF

```
## Getting number of folder
```
SITE_ID="icircular"
BASE_URL="http://localhost:8080/alfresco"
AUTH="admin:admin"

curl -s -u "$AUTH" -H "Content-Type: application/json" \
  -d @- "$BASE_URL/api/-default-/public/search/versions/1/search" <<EOF \
  | jq '.list.pagination.totalItems'
{
  "query": {
    "language": "afts",
    "query": "TYPE:\"cm:folder\" AND PATH:\"/app:company_home/st:sites/cm:${SITE_ID}/cm:documentLibrary//*\""
  },
  "paging": {
    "maxItems": 1,
    "skipCount": 0
  }
}
EOF

```


## Getting all files and folder from sites
create sh files 
```
#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG ======
BASE_URL="http://localhost:8080/alfresco"
AUTH="admin:admin"
MAX_ITEMS=1000
# ====================

# Function to get count for one site + one type (cm:content or cm:folder)
get_count() {
  local SITE_ID="$1"
  local TYPE="$2"   # cm:content or cm:folder

  curl -s -u "$AUTH" -H "Content-Type: application/json" \
    -d @- "$BASE_URL/api/-default-/public/search/versions/1/search" <<EOF \
    | jq '.list.pagination.totalItems'
{
  "query": {
    "language": "afts",
    "query": "TYPE:\"${TYPE}\" AND PATH:\"/app:company_home/st:sites/cm:${SITE_ID}/cm:documentLibrary//*\""
  },
  "paging": {
    "maxItems": 1,
    "skipCount": 0
  }
}
EOF
}

# 1) Get all site IDs
SITES=$(curl -s -u "$AUTH" \
  "$BASE_URL/api/-default-/public/alfresco/versions/1/sites?maxItems=${MAX_ITEMS}" \
  | jq -r '.list.entries[].entry.id')

TOTAL_SITES=$(echo "$SITES" | wc -l | tr -d ' ')

echo "Total sites: $TOTAL_SITES"
echo

# 2) Print header
printf "%-20s %15s %15s\n" "SITE" "DOCUMENTS" "FOLDERS"
printf "%-20s %15s %15s\n" "--------------------" "-------------" "-------------"

# 3) Loop over each site and calculate counts
for SITE in $SITES; do
  DOCS=$(get_count "$SITE" "cm:content")
  FOLDERS=$(get_count "$SITE" "cm:folder")

  printf "%-20s %15s %15s\n" "$SITE" "$DOCS" "$FOLDERS"
done


```
