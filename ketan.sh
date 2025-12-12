#!/usr/bin/env bash
# alfresco-reconcile-extras.sh
# Reconcile doc/folder counts and compute "extra items" inside sites but outside documentLibrary.
set -euo pipefail

BASE="http://127.0.0.1:8080/alfresco"
AUTH="admin:admin"   # change if necessary
CURL="curl -s --noproxy 127.0.0.1,localhost -u $AUTH"
MAX_SITES=1000

jq_exists() { command -v jq >/dev/null 2>&1; }
if ! jq_exists; then
  echo "Please install jq and re-run (sudo dnf/apt install jq)." >&2
  exit 1
fi

# helper to run a search JSON and return numeric count (or 0)
search_count() {
  local json="$1"
  echo "$json" \
    | $CURL -H "Content-Type: application/json" \
        -d @- "$BASE/api/-default-/public/search/versions/1/search" \
    | jq '.list.pagination.totalItems // 0'
}

# 1) Repo-wide totals (everything under /app:company_home//* )
REPO_DOCS_JSON='{"query":{"language":"afts","query":"TYPE:\"cm:content\" AND PATH:\"/app:company_home//*\""},"paging":{"maxItems":1,"skipCount":0}}'
REPO_FOLDERS_JSON='{"query":{"language":"afts","query":"TYPE:\"cm:folder\" AND PATH:\"/app:company_home//*\""},"paging":{"maxItems":1,"skipCount":0}}'
repo_docs=$(search_count "$REPO_DOCS_JSON")
repo_folders=$(search_count "$REPO_FOLDERS_JSON")

# 2) Items OUTSIDE sites (NOT under /app:company_home/st:sites//* )
OUTSIDE_DOCS_JSON='{"query":{"language":"afts","query":"TYPE:\"cm:content\" AND -PATH:\"/app:company_home/st:sites//*\""},"paging":{"maxItems":1,"skipCount":0}}'
OUTSIDE_FOLDERS_JSON='{"query":{"language":"afts","query":"TYPE:\"cm:folder\" AND -PATH:\"/app:company_home/st:sites//*\""},"paging":{"maxItems":1,"skipCount":0}}'
outside_docs=$(search_count "$OUTSIDE_DOCS_JSON")
outside_folders=$(search_count "$OUTSIDE_FOLDERS_JSON")

# 3) Inside sites totals (derived)
inside_sites_docs=$((repo_docs - outside_docs))
inside_sites_folders=$((repo_folders - outside_folders))

# 4) Sum per-site documentLibrary counts (documents + folders) — re-use robust loop
SITES=$($CURL "$BASE/api/-default-/public/alfresco/versions/1/sites?maxItems=${MAX_SITES}" \
  | jq -r '.list.entries[].entry.id')

sum_doclibs_docs=0
sum_doclibs_folders=0

for SITE in $SITES; do
  DOC_JSON=$(cat <<EOF
{
  "query":{"language":"afts","query":"TYPE:\"cm:content\" AND PATH:\"/app:company_home/st:sites/cm:${SITE}/cm:documentLibrary//*\""},
  "paging":{"maxItems":1,"skipCount":0}
}
EOF
)
  FOL_JSON=$(cat <<EOF
{
  "query":{"language":"afts","query":"TYPE:\"cm:folder\" AND PATH:\"/app:company_home/st:sites/cm:${SITE}/cm:documentLibrary//*\""},
  "paging":{"maxItems":1,"skipCount":0}
}
EOF
)
  dcount=$(search_count "$DOC_JSON")
  fcount=$(search_count "$FOL_JSON")
  sum_doclibs_docs=$((sum_doclibs_docs + dcount))
  sum_doclibs_folders=$((sum_doclibs_folders + fcount))
done

# 5) Extra inside sites but outside documentLibrary
extra_inside_docs=$(( inside_sites_docs - sum_doclibs_docs ))
extra_inside_folders=$(( inside_sites_folders - sum_doclibs_folders ))

# Avoid negative due to any mismatch
[ "$extra_inside_docs" -lt 0 ] && extra_inside_docs=0
[ "$extra_inside_folders" -lt 0 ] && extra_inside_folders=0

# 6) Print reconciliation
cat <<EOF
========================================================
 Alfresco counts reconciliation
 (repo-wide vs sites vs documentLibrary sums)
========================================================

REPOSITORY-WIDE (all nodes under /app:company_home//*)
  Documents (cm:content)  : $repo_docs
  Folders   (cm:folder)   : $repo_folders

OUTSIDE SITES (not under /st:sites)
  Documents (outside sites): $outside_docs
  Folders   (outside sites): $outside_folders

INSIDE SITES  (derived: repo - outside)
  Documents (inside sites): $inside_sites_docs
  Folders   (inside sites): $inside_sites_folders

SUM OF PER-SITE documentLibrary (your previous per-site totals)
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
