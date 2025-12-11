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
