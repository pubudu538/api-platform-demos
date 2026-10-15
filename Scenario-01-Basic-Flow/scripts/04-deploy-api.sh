#!/bin/bash
# Step 5: attach the API to the gateway and deploy it.
source "$(dirname "$0")/lib.sh"
need API_ID; need GATEWAY_ID
export GATEWAY_ID TIMESTAMP="$(date +%s)"
login
call POST "$PLATFORM_BASE/rest-apis/$API_ID/gateways" -H 'Content-Type: application/json' -d "$(jq -n --arg g "$GATEWAY_ID" '[{gatewayId:$g}]')"
if ok; then :; elif [ "$CODE" = 409 ]; then log "already associated"; else show; die "associate: HTTP $CODE"; fi
json POST "$PLATFORM_BASE/rest-apis/$API_ID/deployments" deployment.json
ok || { show; die "deploy: HTTP $CODE"; }
DEP=$(echo "$BODY" | jq -r .deploymentId); save DEPLOYMENT_ID "$DEP"
for _ in $(seq 1 20); do
  call GET "$PLATFORM_BASE/rest-apis/$API_ID/deployments/$DEP"; ST=$(echo "$BODY" | jq -r '.status // empty')
  [ "$ST" = DEPLOYING ] || break; sleep 2
done
log "deployment $DEP status: $ST"
[ "$ST" = DEPLOYED ] || { show; die "deployment did not reach DEPLOYED (is the gateway connected?)"; }
