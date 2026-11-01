#!/usr/bin/env bash
# Smoke test for the Zero Trust lab (stack must be running).
set -euo pipefail

URL="${URL:-https://localhost:8443/}"
CERTS="${CERTS:-certs}"
fail=0

check() { # name expected actual
  if [[ "$2" == "$3" ]]; then echo "PASS  $1 (HTTP $3)"; else echo "FAIL  $1: expected $2, got $3"; fail=1; fi
}

code=$(curl -s -o /dev/null -w '%{http_code}' --cacert "${CERTS}/ca.crt" \
  --cert "${CERTS}/client.crt" --key "${CERTS}/client.key" "${URL}" || true)
check "valid client certificate is accepted" 200 "${code}"

code=$(curl -s -o /dev/null -w '%{http_code}' --cacert "${CERTS}/ca.crt" "${URL}" || true)
check "no client certificate is rejected" 400 "${code}"

if curl -s -o /dev/null --max-time 5 http://localhost:8080/ 2>/dev/null; then
  echo "FAIL  backend must not be exposed on the host"; fail=1
else
  echo "PASS  backend is not reachable from the host"
fi

exit "${fail}"
