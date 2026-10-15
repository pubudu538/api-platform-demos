#!/bin/bash
# Step 3: register the gateway, mint its token, give the token to the gateway and restart it.
source "$(dirname "$0")/lib.sh"
need_dir "$GATEWAY_DIST" GATEWAY_DIST
GATEWAY_ID="$(art gateway.json .id)"; export GATEWAY_ID
login

json POST "$PLATFORM_BASE/gateways" gateway.json; created_or_exists "gateway '$GATEWAY_ID'"
call POST "$PLATFORM_BASE/gateways/$GATEWAY_ID/tokens" -H 'Content-Type: application/json' -d '{}'
ok || { show; die "token: HTTP $CODE"; }
save GATEWAY_ID "$GATEWAY_ID"
save GATEWAY_TOKEN "$(echo "$BODY" | jq -r .token)"

ENVF="$GATEWAY_DIST/api-platform.env"
set_env "$ENVF" APIP_GW_CONTROLLER_CONTROLPLANE_HOST  "$CONTROLPLANE_HOST"
set_env "$ENVF" APIP_GW_CONTROLLER_CONTROLPLANE_TOKEN "$GATEWAY_TOKEN"
log "Wrote control plane host and token to $ENVF; restarting the gateway ..."
(cd "$GATEWAY_DIST" && docker compose up -d --force-recreate gateway-controller gateway-runtime)

log "Waiting for the gateway to connect ..."
for _ in $(seq 1 30); do
  call GET "$PLATFORM_BASE/gateways/$GATEWAY_ID"
  [ "$(echo "$BODY" | jq -r '.isActive // false')" = true ] && { log "gateway '$GATEWAY_ID' is active"; exit 0; }; sleep 3
done
log "gateway not active yet; check: docker compose -f $GATEWAY_DIST/docker-compose.yaml logs gateway-controller"
