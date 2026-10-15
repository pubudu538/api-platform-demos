#!/bin/bash
# Step 8: invoke the API through the gateway. Only a request carrying BOTH credentials may succeed.
source "$(dirname "$0")/lib.sh"
need API_KEY; need SUBSCRIPTION_TOKEN; need PORTAL_API_ID
# Prefer the server URL published in the API Portal; fall back to gateway URL + API context.
login
call GET "$PORTAL_BASE/apis/$PORTAL_API_ID"
BASE=$(echo "$BODY" | jq -r '[.. | strings | select(startswith("http") and endswith("'"$(art rest-api.json .context)"'"))][0] // empty' 2>/dev/null || true)
[ -n "$BASE" ] || BASE="$GATEWAY_URL$(art rest-api.json .context)"
URL="$BASE/books"; log "target: $URL"

status() { curl -sk -o /dev/null -w '%{http_code}' "$URL" "$@"; }
# The portal pushes the key and subscription to the gateway asynchronously; wait until they arrive.
for _ in $(seq 1 20); do [ "$(status -H "x-api-key: $API_KEY" -H "Subscription-Key: $SUBSCRIPTION_TOKEN")" = 200 ] && break; sleep 2; done

printf '%-30s %s\n' "Request" "HTTP status" "------------------------------ -----------"
printf '%-30s %s\n' "no credentials"             "$(status)"
printf '%-30s %s\n' "API key only"               "$(status -H "x-api-key: $API_KEY")"
printf '%-30s %s\n' "subscription token only"    "$(status -H "Subscription-Key: $SUBSCRIPTION_TOKEN")"
printf '%-30s %s\n' "BOTH (expect 200)"          "$(status -H "x-api-key: $API_KEY" -H "Subscription-Key: $SUBSCRIPTION_TOKEN")"
printf '%-30s %s\n' "valid key, wrong token"     "$(status -H "x-api-key: $API_KEY" -H "Subscription-Key: wrong")"
printf '%-30s %s\n' "wrong key, valid token"     "$(status -H "x-api-key: wrong" -H "Subscription-Key: $SUBSCRIPTION_TOKEN")"
echo; log "response with both credentials:"
curl -sk "$URL" -H "x-api-key: $API_KEY" -H "Subscription-Key: $SUBSCRIPTION_TOKEN" | jq . 2>/dev/null
