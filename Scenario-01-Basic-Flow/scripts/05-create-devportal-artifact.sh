#!/bin/bash
# Step 6: publish the API in the API Portal with the gateway URL as its server URL, and wire the portal to the gateway.
#   a) webhook subscriber: portal -> Platform API -> gateway (subscriptions and API keys)
#   b) organization cpRefId: so the Platform API can resolve the portal's organization from events
#   c) subscription plan on both sides, linked by refId
#   d) the API itself (api.yaml + OpenAPI definition); referenceId = Platform API id
source "$(dirname "$0")/lib.sh"
need_dir "$PORTAL_DIST" PORTAL_DIST
export WEBHOOK_SECRET="$(grep '^APIP_CP_WEBHOOK_SECRET=' "$PORTAL_DIST/api-platform.env" | cut -d= -f2-)"
[ -n "$WEBHOOK_SECRET" ] || die "APIP_CP_WEBHOOK_SECRET missing in $PORTAL_DIST/api-platform.env (run 01-setup.sh)"
login

# a) webhook subscriber
SUB_ID="$(art webhook-subscriber.json .id)"
json POST "$PORTAL_BASE/webhook-subscribers" webhook-subscriber.json
if [ "$CODE" = 409 ]; then json PUT "$PORTAL_BASE/webhook-subscribers/$SUB_ID" webhook-subscriber.json; ok || { show; die "webhook update: HTTP $CODE"; }
else ok || { show; die "webhook: HTTP $CODE"; }; fi
log "webhook subscriber '$SUB_ID' ready"

# b) organization link. The portal serves one organization (handle from its config, default "default"); PUT overwrites cpRefId, so merge.
ORG_HANDLE="${PORTAL_ORG_HANDLE:-default}"
call GET "$PORTAL_BASE/organizations/$ORG_HANDLE"; ok || { show; die "get org: HTTP $CODE"; }
ORG=$(echo "$BODY" | jq -c '{displayName,businessOwner,businessOwnerContact,businessOwnerEmail,id,idpRefId,configuration} | with_entries(select(.value != null))')
call PUT "$PORTAL_BASE/organizations/$ORG_HANDLE" -H 'Content-Type: application/json' -d "$(jq -c -s '.[0] * .[1]' <(echo "$ORG") "$ART/portal-organization.json")"
ok || { show; die "link org: HTTP $CODE"; }
log "organization cpRefId set to '$(art portal-organization.json .cpRefId)'"

# c) subscription plan on both sides
json POST "$PLATFORM_BASE/subscription-plans" subscription-plan.platform.json; created_or_exists "platform plan"
json PUT "$PORTAL_BASE/subscription-plans" subscription-plan.portal.json; ok || { show; die "portal plan: HTTP $CODE"; }
log "portal plan '$(art subscription-plan.portal.json .id)' linked to platform plan '$(art subscription-plan.portal.json .refId)'"

# d) the API
PORTAL_API_ID="$(grep -m1 '^  name:' "$ART/portal-api/api.yaml" | awk '{print $2}')"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
render "$ART/portal-api/api.yaml" > "$TMP/api.yaml"
render "$ART/portal-api/definition.yaml" > "$TMP/definition.yaml"   # servers.url = gateway URL + API context
FORMS=(-F "metadata=@$TMP/api.yaml;type=application/yaml" -F "definition=@$TMP/definition.yaml;type=application/octet-stream")
call POST "$PORTAL_BASE/apis" "${FORMS[@]}"
if [ "$CODE" = 409 ]; then log "API exists, updating (PUT)"; call PUT "$PORTAL_BASE/apis/$PORTAL_API_ID" "${FORMS[@]}"; fi
ok || { show; die "portal API: HTTP $CODE"; }
save PORTAL_API_ID "$PORTAL_API_ID"
log "portal API '$PORTAL_API_ID' published, server URL = $GATEWAY_URL$API_CONTEXT (api.yaml endpoints and definition servers)"
