# zerotrust-lab-iac

A small, reproducible **Zero Trust lab** deployed with Infrastructure as Code and validated by a CI/CD pipeline.

Core idea: *never trust, always verify*. Every request to the service must present a client certificate issued by a private CA (mutual TLS). The backend is not exposed and lives on an isolated network, reachable only through the verifying proxy.

## Architecture

```
 client (cert: CN=alice) --mTLS--> [ nginx proxy :8443 ] --> [ app (whoami) ]
                                    edge + backend nets       backend net only
                                    verifies client cert      internal: true (no egress)
```

| Zero Trust principle | Implementation |
|---|---|
| Verify explicitly | `ssl_verify_client on`, private root CA (`scripts/pki.sh`) |
| Identity passed to backend | `X-Client-DN` / `X-Client-Verify` headers, visible in the backend response |
| Least privilege | containers run with `cap_drop: ALL`, `no-new-privileges`, read-only filesystem, non-root image/user |
| Network segmentation | `backend` network is `internal: true`; the app publishes no port |
| Assume breach | proxy bound to `127.0.0.1`, TLS 1.2+ only, short-lived (30 days) lab certificates |

## What is inside

| Path | Role |
|---|---|
| `scripts/pki.sh` | Generates a root CA, a server cert (SAN: localhost) and a client cert (CN=alice) with OpenSSL |
| `compose.yaml` | Hardened container stack (proxy + backend, segmented networks) |
| `nginx/nginx.conf` | mTLS configuration |
| `ansible/site.yml` | Idempotent deployment + verification (cert accepted, no cert rejected) |
| `tests/smoke.sh` | curl-based smoke tests, also used in CI |
| `.github/workflows/ci.yml` | CI: ShellCheck, yamllint, ansible-lint, Compose validation, Trivy IaC scan, then a full deploy and mTLS test |
| `Makefile` | `make up`, `make test`, `make down`, `make deploy` |

## Quick start

Requirements: Docker with Compose v2, OpenSSL, curl (Ansible optional).

```bash
make up        # generate PKI and start the stack
make test      # expect: PASS x3
make down      # stop and clean up
```

Manual check:

```bash
# Accepted: backend echoes your identity (CN=alice)
curl --cacert certs/ca.crt --cert certs/client.crt --key certs/client.key https://localhost:8443/

# Rejected: HTTP 400 "No required SSL certificate was sent"
curl -i --cacert certs/ca.crt https://localhost:8443/
```

With Ansible: `ansible-playbook ansible/site.yml` generates the PKI, starts the stack and runs the same checks.

## Security notes

This is a **lab**. Keys have no passphrase, the server key is world-readable so the unprivileged container can read it, and `certs/` is git-ignored: never commit private keys. For real systems use a managed PKI/secret store, certificate rotation and revocation.

## Roadmap

- [ ] Terraform module (Docker provider) replacing the Compose file
- [ ] Short-lived certificates and rotation with step-ca or Vault PKI
- [ ] Policy per identity (authorize `alice`, deny other valid certs)
- [ ] SBOM + image scan (Trivy / Syft) as a CI gate
- [ ] Deploy the same stack on a local Kubernetes (kind) with network policies

## Skills demonstrated

Zero Trust (mTLS, segmentation, least privilege), PKI/OpenSSL, Docker/Compose hardening, Ansible, CI/CD with GitHub Actions (DevSecOps), shell scripting, automated security testing.
