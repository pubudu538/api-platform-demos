#!/bin/bash
# Steps 1 and 2: run both setup.sh scripts, apply the integration config, start both compose stacks.
source "$(dirname "$0")/lib.sh"
need_dir "$PORTAL_DIST" PORTAL_DIST; need_dir "$GATEWAY_DIST" GATEWAY_DIST
creds

for d in "$PORTAL_DIST" "$GATEWAY_DIST"; do
  log "setup.sh in $d (idempotent: keeps existing certs, keys and credentials)"
  (cd "$d" && ./scripts/setup.sh)
done

# Platform API webhook receiver: lets the API Portal push subscriptions and API keys to the gateway.
ENVF="$PORTAL_DIST/api-platform.env"
if ! grep -q '^APIP_CP_WEBHOOK_SECRET=' "$ENVF"; then
  set_env "$ENVF" APIP_CP_WEBHOOK_SECRET "$(openssl rand -hex 32)"; log "generated APIP_CP_WEBHOOK_SECRET"
fi
if ! grep -q '^\[platform_api.webhook\]' "$PORTAL_DIST/configs/config.toml"; then
  cat "$ROOT/config/platform-api-webhook.toml" >> "$PORTAL_DIST/configs/config.toml"; log "enabled [platform_api.webhook]"
fi
cp "$ROOT/config/portal-compose.override.yaml" "$PORTAL_DIST/docker-compose.override.yaml"; log "installed portal compose override (trust shared TLS cert)"

log "Starting API Portal + Platform API ..."
(cd "$PORTAL_DIST" && docker compose up -d)
log "Starting the gateway (not yet connected to the Platform API) ..."
(cd "$GATEWAY_DIST" && docker compose up -d)

log "Waiting for the Platform API ..."
for _ in $(seq 1 40); do curl -skf "$PLATFORM_API_URL/health" >/dev/null && break; sleep 3; done
curl -skf "$PLATFORM_API_URL/health" >/dev/null || die "Platform API did not become healthy"
log "Platform API healthy"
