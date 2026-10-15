#!/bin/bash
# Shared helpers, sourced by every script. Requires: bash, curl, jq, perl, docker.
set -euo pipefail
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$LIB_DIR/.." && pwd)"
ART="$ROOT/artifacts"
STATE_FILE="${STATE_FILE:-$ROOT/.state.env}"

# --- Configuration (override with environment variables) ---------------------------------------
PORTAL_DIST="${PORTAL_DIST:-$HOME/Downloads/wso2apip-api-portal-1.0.0}"     # contains docker-compose.yaml with platform-api + api-portal
GATEWAY_DIST="${GATEWAY_DIST:-$HOME/Downloads/wso2apip-api-gateway-1.2.0}"  # contains docker-compose.yaml with the gateway
PLATFORM_API_URL="${PLATFORM_API_URL:-https://localhost:9243}"
API_PORTAL_URL="${API_PORTAL_URL:-https://localhost:9543}"
export GATEWAY_URL="${GATEWAY_URL:-https://localhost:8443}"                  # gateway ingress as seen by clients
CONTROLPLANE_HOST="${CONTROLPLANE_HOST:-host.docker.internal:9243}"         # Platform API as seen from the gateway container
PLATFORM_BASE="$PLATFORM_API_URL/api/v0.9"
PORTAL_BASE="$API_PORTAL_URL/api-portal/api/v0.9"

for c in curl jq perl docker; do command -v "$c" >/dev/null || { echo "$c is required" >&2; exit 1; }; done
[ -f "$STATE_FILE" ] && source "$STATE_FILE" || true

# --- Output helpers ------------------------------------------------------------------------------
log()  { echo "[$(basename "$0")] $*" >&2; }
die()  { echo "[$(basename "$0")] ERROR: $*" >&2; exit 1; }
need() { [ -n "${!1:-}" ] || die "$1 is not set. Run the earlier step first (or export $1)."; }
need_dir() { [ -d "$1" ] || die "directory not found: $1 (set $2)"; }

# save KEY VALUE: persist a value for later scripts (kept out of git by .gitignore)
save() {
  touch "$STATE_FILE"; grep -v "^$1=" "$STATE_FILE" > "$STATE_FILE.tmp" || true
  printf '%s=%q\n' "$1" "$2" >> "$STATE_FILE.tmp"; mv "$STATE_FILE.tmp" "$STATE_FILE"
  eval "$1=\$2"
}

# set_env FILE KEY VALUE: replace or append KEY=VALUE in an env file
set_env() {
  local f="$1" k="$2" v="$3"; touch "$f"
  grep -v "^$k=" "$f" > "$f.tmp" || true; printf '%s=%s\n' "$k" "$v" >> "$f.tmp"; cat "$f.tmp" > "$f"; rm -f "$f.tmp"
}

# --- Artifacts -----------------------------------------------------------------------------------
# render FILE: print the file with {{NAME}} placeholders replaced from exported environment variables
render() { perl -pe 's/\{\{(\w+)\}\}/exists $ENV{$1} ? $ENV{$1} : die "unset placeholder $1\n"/ge' "$1"; }
art()    { jq -r "$2" "$ART/$1"; }   # art FILE JQ_EXPR: read a value out of a JSON artifact
export API_CONTEXT="$(art rest-api.json .context)"   # gateway path of the API; used in the portal artifacts below

# --- Authentication and HTTP -------------------------------------------------------------------
creds() {
  ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
  if [ -z "${ADMIN_PASSWORD:-}" ]; then read -r -s -p "Admin password for $ADMIN_USERNAME: " ADMIN_PASSWORD; echo >&2; fi
  export ADMIN_USERNAME ADMIN_PASSWORD
}
# login: Platform API JWT, accepted by the Platform API and the API Portal
login() {
  creds
  TOKEN=$(curl -sk -X POST "$PLATFORM_API_URL/api/portal/v0.9/auth/login" \
    --data-urlencode "username=$ADMIN_USERNAME" --data-urlencode "password=$ADMIN_PASSWORD" | jq -r '.token // empty')
  [ -n "$TOKEN" ] || die "login failed (credentials wrong, or $PLATFORM_API_URL not reachable)"
  AUTH="Authorization: Bearer $TOKEN"
}
# call METHOD URL [curl args]: result in $CODE and $BODY; never exits on an HTTP error
call() { local m="$1" u="$2"; shift 2; local out
  out=$(curl -sk -X "$m" "$u" -H "$AUTH" -w $'\n%{http_code}' "$@"); CODE=${out##*$'\n'}; BODY=${out%$'\n'*}; }
# json METHOD URL ARTIFACT_FILE: send a rendered artifact as the JSON body
json() { call "$1" "$2" -H 'Content-Type: application/json' -d "$(render "$ART/$3")"; }
ok()   { [ "$CODE" -ge 200 ] && [ "$CODE" -lt 300 ]; }
show() { echo "$BODY" | jq . 2>/dev/null || echo "$BODY"; }
# created_or_exists WHAT: 2xx or 409 is fine, anything else aborts
created_or_exists() { if ok; then log "$1 created"; elif [ "$CODE" = 409 ]; then log "$1 already exists"; else show; die "$1: HTTP $CODE"; fi; }
