#!/bin/bash
# Runs the whole flow, steps 1 to 8. Prompts once for the admin password unless ADMIN_PASSWORD is set.
cd "$(dirname "$0")"
export ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
if [ -z "${ADMIN_PASSWORD:-}" ]; then read -r -s -p "Admin password for $ADMIN_USERNAME: " ADMIN_PASSWORD; echo; fi
export ADMIN_PASSWORD
for s in 01-setup 02-register-gateway 03-create-api 04-deploy-api 05-create-devportal-artifact 06-subscribe-and-key 07-invoke; do
  echo; echo "===== $s ====="; ./$s.sh || { echo "!!! $s failed"; exit 1; }
done
