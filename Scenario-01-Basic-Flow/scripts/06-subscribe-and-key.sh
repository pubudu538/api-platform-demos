#!/bin/bash
# Step 7: subscribe to the API (gives the subscription token) and generate an API key tied to that subscription.
# The portal then pushes both to the gateway through the webhook.
source "$(dirname "$0")/lib.sh"
need PORTAL_API_ID
login

call POST "$PORTAL_BASE/subscriptions" -H 'Content-Type: application/json' -d "$(render "$ART/subscription.json")"
if ! ok; then
  [ "$CODE" = 409 ] || { show; die "subscribe: HTTP $CODE"; }
  log "already subscribed, reusing the existing subscription"
  call GET "$PORTAL_BASE/subscriptions"
  BODY=$(echo "$BODY" | jq -c --arg a "$PORTAL_API_ID" '[.. | objects | select(.artifactId? == $a)][0] // empty')
fi
save SUBSCRIPTION_ID    "$(echo "$BODY" | jq -r .subscriptionId)"
save SUBSCRIPTION_TOKEN "$(echo "$BODY" | jq -r .subscriptionToken)"

export KEY_ID="demo-key-$(date +%s)" SUBSCRIPTION_ID
call POST "$PORTAL_BASE/apis/$PORTAL_API_ID/api-keys/generate" -H 'Content-Type: application/json' -d "$(render "$ART/api-key.json")"
ok || { show; die "api key: HTTP $CODE"; }
save API_KEY "$(echo "$BODY" | jq -r .key)"
log "subscription $SUBSCRIPTION_ID and API key '$KEY_ID' created (values saved in .state.env, shown once by the portal)"
