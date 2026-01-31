# Kubernetes on Talos Linux

Last updated: 2026-02-01 (Pacific/Auckland)


## Decision

Kubernetes nodes run **Talos Linux**. The admin node performs cluster creation and configuration using client tooling.

## Scope

This document covers:
- Admin node prerequisites
- Cluster bootstrap flow (high level)
- Mandatory add-ons: MetalLB and Ingress controller
- Operational notes and guardrails

## Admin node prerequisites

Install on the admin node (client tools only):
- talosctl
- kubectl
- helm (recommended)

Secrets:
- Store Talos config and kubeconfig securely (sops+age preferred).

## Cluster model

Recommended starting model:
- 3 control plane nodes (Talos)
- 2+ worker nodes (Talos)

Small lab model:
- 1 control plane node and 1 worker node is acceptable, with acknowledged availability risk.

## Mandatory add-ons

### MetalLB

Purpose: Provide `LoadBalancer` services on a LAN without cloud provider integration.

Implementation:
- Deployed to the cluster (Helm or manifests as standardised in your automation)
- Uses an IP address pool on your LAN (document and reserve it)

Operational guardrails:
- Reserve an IP range in DHCP/IPAM for MetalLB
- Ensure ARP/NDP behaviour aligns with your network (especially across VLANs)

### Ingress controller

Purpose: HTTP routing into services.

Choose one standard for the platform:
- Traefik, or
- NGINX Ingress Controller

Notes:
- If you plan to use Traefik broadly across Docker and Kubernetes, standardising on Traefik reduces cognitive load.
- If you prefer maximum enterprise familiarity, NGINX Ingress is a common default.

## Recommended pattern

- Use MetalLB for LAN load balancer IPs.
- Expose only the ingress controller via `LoadBalancer`.
- Keep internal services as ClusterIP by default.
- Prefer VPN access for admin and dashboards.

## Install and uninstall behaviour

Cluster add-ons are treated as managed components:
- Install: via Helm/manifests driven from admin node automation
- Uninstall: via the same automation, with safeguards to avoid accidental removal of shared ingress

## Risks and mitigations

- Risk: Misconfigured IP pools causing LAN conflicts
  Mitigation: Reserve ranges and enforce validation gates.

- Risk: Ingress sprawl and inconsistent routing
  Mitigation: Standardise on one ingress controller and one pattern.

- Risk: Talos learning curve
  Mitigation: Document operational runbooks and keep changes scripted.
