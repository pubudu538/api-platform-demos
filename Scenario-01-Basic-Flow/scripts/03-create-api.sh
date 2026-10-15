#!/bin/bash
# Step 4: create the project and the REST API with its policies (api-key-auth + subscription-validation).
source "$(dirname "$0")/lib.sh"
API_ID="$(art rest-api.json .id)"
login
json POST "$PLATFORM_BASE/projects" project.json; created_or_exists "project"
json POST "$PLATFORM_BASE/rest-apis" rest-api.json
if [ "$CODE" = 409 ]; then log "API exists, updating (PUT) so artifact changes apply"; json PUT "$PLATFORM_BASE/rest-apis/$API_ID" rest-api.json; ok || { show; die "update: HTTP $CODE"; }
else ok || { show; die "create: HTTP $CODE"; }; fi
save API_ID "$API_ID"
echo "$BODY" | jq '{id, context, version, policies: [.policies[].name]}'
