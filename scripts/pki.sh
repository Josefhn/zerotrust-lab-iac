#!/usr/bin/env bash
# Generate a throwaway private PKI for the lab: root CA, server cert, client cert.
# LAB USE ONLY: keys are created without passphrase and the server key is
# world-readable so the unprivileged nginx container can read it.
set -euo pipefail

OUT_DIR="${1:-certs}"
DAYS="${DAYS:-30}"

mkdir -p "${OUT_DIR}"
cd "${OUT_DIR}"

if [[ -f ca.crt && -f server.crt && -f client.crt ]]; then
  echo "PKI already present in ${OUT_DIR}, nothing to do."
  exit 0
fi

echo "[1/3] Root CA"
openssl genrsa -out ca.key 4096 2>/dev/null
openssl req -x509 -new -nodes -key ca.key -sha256 -days "${DAYS}" \
  -subj "/C=MA/O=ZeroTrustLab/CN=ZeroTrustLab Root CA" -out ca.crt

echo "[2/3] Server certificate (localhost)"
openssl genrsa -out server.key 2048 2>/dev/null
openssl req -new -key server.key -subj "/C=MA/O=ZeroTrustLab/CN=localhost" -out server.csr
cat > server.ext <<'EOF'
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:localhost, IP:127.0.0.1
EOF
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days "${DAYS}" -sha256 -extfile server.ext 2>/dev/null

echo "[3/3] Client certificate (identity: alice)"
openssl genrsa -out client.key 2048 2>/dev/null
openssl req -new -key client.key -subj "/C=MA/O=ZeroTrustLab/CN=alice" -out client.csr
cat > client.ext <<'EOF'
basicConstraints = CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = clientAuth
EOF
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -days "${DAYS}" -sha256 -extfile client.ext 2>/dev/null

rm -f ./*.csr ./*.ext ./*.srl
chmod 600 ca.key client.key
chmod 644 server.key   # readable by the unprivileged container user (lab only)

echo "Done. Files in ${OUT_DIR}: $(ls | tr '\n' ' ')"
