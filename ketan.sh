#!/usr/bin/env bash
# alfresco-reconcile-extras-fixed.sh
# Robust reconciliation of Alfresco counts (repo, outside sites, inside sites, sum of doclibs, extras).
set -euo pipefail

BASE="http://127.0.0.1:8080/alfresco"
AUTH="admin:admin"   # change if needed
CURL="curl -s --noproxy 127.0.0.1,localhost -u $AUTH"
MAX_SITES=1000

# Ensure jq exists
if ! command -v jq >/dev/null 2>&1; then
  echo "Please install jq (sudo apt/yum install jq) and re-run." >&2
  exit 1
fi

# Helper: run a search JSON and return numeric count (or 0)
search_count() {
  local json="$1"
  # send JSON to search API, return pagination.totalItems or 0
  echo "$json" \
    | $CURL -H "Content-Type: application/json" \
        -d @- "$BASE/api/-default-/public/search/versions/1/search" \
    | jq '.list.pagination.totalItems // 0'
}

# Fetch repo-wide totals
REPO_DOCS_JSON='{"query":{"language":"afts","query":"TYPE:\"cm:content\" AND PATH:\"/app:company_home//*\""},"paging":{"maxItems":1,"skipCount":0}}'
REPO_FOLDERS_JSON='{"query":{"language":"afts","query":"TYPE:\"cm:folder\" AND PATH:\"/app:company_home//*\""},"paging":{"maxItems":1,"skipCount":0}}'
repo_docs=$(search_count "$REPO_DOCS_JSON")
repo_folders=$(search_count "$REPO_FOLDERS_JSON")

# Fetch counts outside sites (not under /st:sites)
OUTSIDE_DOCS_JSON='{"query":{"language":"afts","query":"TYPE:\"cm:content\" AND -PATH:\"/app:company_home/st:sites//*\""},"paging":{"maxItems":1,"skipCount":0}}'
OUTSIDE_FOLDERS_JSON='{"query":{"language":"afts","query":"TYPE:\"cm:folder\" AND -PATH:\"/app:company_home/st:sites//*\""},"paging":{"maxItems":1,"skipCount":0}}'
outside_docs=$(search_count "$OUTSIDE_DOCS_JSON")
outside_folders=$(search_count "$OUTSIDE_FOLDERS_JSON")

# Derived: inside sites totals
inside_sites_docs=$((repo_docs - outside_docs))
inside_sites_folders=$((repo_folders - outside_folders))
[ "$inside_sites_docs" -lt 0 ] && inside_sites_docs=0
[ "$inside_sites_folders" -lt 0 ] && inside_sites_folders=0

# Get site ids safely (avoid null)
SITES_JSON=$($CURL "$BASE/api/-default-/public/alfresco/versions/1/sites?maxItems=${MAX_SITES}")
# Debug: if you want to inspect raw response, uncomment:
# echo "$SITES_JSON" | sed -n '1,120p' >&2

# Extract site ids in a way that yields empty when missing
SITES=$(echo "$SITES_JSON" | jq -r '.list.entries[]?.entry.id // empty')

# If no sites found, handle gracefully
if [ -z "$SITES" ]; then
  echo "No sites found ('.list.entries' empty). Exiting with reconciliation using repo/outside counts only."
  cat <<EOF
REPOSITORY DOCS: $repo_docs
REPOSITORY FOLDERS: $repo_folders
OUTSIDE SITES DOCS: $outside_docs
OUTSIDE SITES FOLDERS: $outside_folders
INSIDE SITES DOCS (derived): $inside_sites_docs
INSIDE SITES FOLDERS (derived): $inside_sites_folders
EOF
  exit 0
fi

# Sum per-site documentLibrary counts
sum_doclibs_docs=0
sum_doclibs_folders=0

for SITE in $SITES; do
  DOC_JSON=$(cat <<EOF
{
  "query":{"language":"afts","query":"TYPE:\\"cm:content\\" AND PATH:\\"/app:company_home/st:sites/cm:${SITE}/cm:documentLibrary//*\\""},
  "paging":{"maxItems":1,"skipCount":0}
}
EOF
)
  FOL_JSON=$(cat <<EOF
{
  "query":{"language":"afts","query":"TYPE:\\"cm:folder\\" AND PATH:\\"/app:company_home/st:sites/cm:${SITE}/cm:documentLibrary//*\\""},
  "paging":{"maxItems":1,"skipCount":0}
}
EOF
)
  dcount=$(search_count "$DOC_JSON")
  fcount=$(search_count "$FOL_JSON")
  # ensure numeric
  dcount=${dcount:-0}
  fcount=${fcount:-0}

  sum_doclibs_docs=$((sum_doclibs_docs + dcount))
  sum_doclibs_folders=$((sum_doclibs_folders + fcount))
done

# Extra inside sites but outside documentLibrary (by subtraction)
extra_inside_docs=$(( inside_sites_docs - sum_doclibs_docs ))
extra_inside_folders=$(( inside_sites_folders - sum_doclibs_folders ))
[ "$extra_inside_docs" -lt 0 ] && extra_inside_docs=0
[ "$extra_inside_folders" -lt 0 ] && extra_inside_folders=0

# Print reconciliation
cat <<EOF
========================================================
 Alfresco counts reconciliation (robust)
========================================================

REPOSITORY-WIDE (under /app:company_home//*)
  Documents (cm:content)  : $repo_docs
  Folders   (cm:folder)   : $repo_folders

OUTSIDE SITES (not under /st:sites)
  Documents (outside sites): $outside_docs
  Folders   (outside sites): $outside_folders

INSIDE SITES  (derived: repo - outside)
  Documents (inside sites): $inside_sites_docs
  Folders   (inside sites): $inside_sites_folders

SUM OF PER-SITE documentLibrary (sums across all sites)
  Documents (sum doclibs) : $sum_doclibs_docs
  Folders   (sum doclibs) : $sum_doclibs_folders

EXTRA ITEMS INSIDE SITES (inside sites but NOT in documentLibrary)
  Extra Documents : $extra_inside_docs
  Extra Folders   : $extra_inside_folders

RECONCILIATION CHECK:
  sum_doclibs_docs + extra_inside_docs + outside_docs == repo_docs
    -> $sum_doclibs_docs + $extra_inside_docs + $outside_docs = $((sum_doclibs_docs + extra_inside_docs + outside_docs))

  sum_doclibs_folders + extra_inside_folders + outside_folders == repo_folders
    -> $sum_doclibs_folders + $extra_inside_folders + $outside_folders = $((sum_doclibs_folders + extra_inside_folders + outside_folders))

========================================================
EOF

exit 0
