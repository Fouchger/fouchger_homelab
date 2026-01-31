# Server Role Profile Catalogue

Last updated: 2026-02-01 (Pacific/Auckland)


Each server must use the Workload Baseline plus exactly one role profile.

## DNS Server

Purpose: Central name resolution and service discovery.

Applications:
- unbound (preferred) or bind9
- optional: Pi-hole or AdGuard Home
- optional (HA): keepalived

Security:
- UFW allow DNS from LAN only

Observability:
- node exporter (via baseline)
- optional: blackbox exporter checks for DNS availability

## Container Host

Purpose: Run application workloads cleanly without OS clutter.

Applications:
- docker engine + compose plugin, or podman (choose one as a platform standard)
- optional ingress for containers: Traefik or Nginx Proxy Manager

Notes:
- Watchtower is opt-in only with governance guardrails.

## Kubernetes (Talos)

Purpose: Cloud-native orchestration and scaling using Talos Linux.

Applications (admin node tools):
- talosctl
- kubectl
- helm (recommended)

Cluster add-ons:
- MetalLB (LAN LoadBalancer)
- Ingress controller: Traefik or NGINX

See: `docs/platform/kubernetes-talos.md`

## Ingress Gateway

Purpose: Secure entry point for web services.

Applications:
- Traefik or NGINX or Caddy (choose one)
- certbot or acme.sh
- fail2ban

Security:
- UFW hardened policy, allow 80/443 (and VPN if required)

## Observability Stack

Purpose: Central place for health, metrics, and logs.

Applications:
- Prometheus
- Grafana
- Loki
- Alertmanager
- optional: Uptime Kuma

Notes:
- Start single-stack on one node, split metrics/logs later if needed.

## Storage and Backup

Purpose: Resilient storage and recovery.

Applications:
- zfsutils-linux (if using ZFS)
- nfs-kernel-server
- samba (only if needed)
- restic or borgbackup (choose one standard)
- optional: syncthing

Risk control:
- Treat storage nodes as stable and least experimental.

## Identity and Access

Purpose: Central authentication and SSO.

Applications:
- Authentik (recommended) or Keycloak

Notes:
- Keep behind VPN where possible.
- Strong backup and change control requirements.

## VPN Remote Access

Purpose: Secure remote entry.

Applications:
- wireguard or tailscale (choose one standard)
- fail2ban

Security:
- VPN-only ingress as default policy.

## CI/CD Runner

Purpose: Build and automation execution without destabilising the admin node.

Applications:
- GitLab Runner or GitHub Actions Runner
- build-essential
- container runtime if required by your runner strategy

## Sandbox

Purpose: Experimentation lane without risk to production services.

Applications:
- test cluster tooling
- developer utilities as required
- non-standard repos allowed

Notes:
- Nothing critical should live here.
