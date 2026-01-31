# Ansible configuration specification

## Purpose
Run configuration on provisioned workloads from the admin node using Ansible playbooks. In dry run mode, perform safe checks only. In live mode, apply changes and update `latest.env` with completion markers and artefact paths.

## Execution model
- Ansible is executed on the admin node only.
- Targets are workload nodes (LXC/VM) created via Terraform.
- Inventory may be static or generated from Terraform outputs (see infra handoff contracts).

## Modes
Dry run
- Validate inventory is present and non-empty.
- Run `ansible-lint` where available.
- Run `ansible-playbook --check --diff` for supported playbooks.
- Do not mutate remote hosts outside what Ansible check-mode inherently reads.

Live run
- Run the selected playbooks.
- Record playbook results into the per-run logs and summary.

## Kubernetes on Talos
Kubernetes nodes use Talos Linux. Configuration is applied from the admin node, with Talos-specific tasks driven by a dedicated playbook.

Expected playbooks (as referenced in higher-level docs)
- `k8s_talos.yml` (cluster enablement and post-install add-ons)

Mandatory add-ons
- MetalLB (to provide `LoadBalancer` services on your LAN)
- Ingress controller (Traefik or NGINX, selected by profile or config)

Documentation reference
- [docs/platform/kubernetes-talos.md](/fouchger_homelab/docs/platform/kubernetes-talos.md)

