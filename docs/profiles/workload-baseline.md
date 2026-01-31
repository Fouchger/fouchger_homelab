# Workload Baseline Profile

Last updated: 2026-02-01 (Pacific/Auckland)


## Purpose

A mandatory baseline installed on every workload node to reduce drift and enforce minimum standards.

## Recommended applications

Security and patching:
- openssh-server
- ufw
- unattended-upgrades
- chrony
- fail2ban (recommended where node is exposed beyond LAN)

Operational basics:
- ca-certificates
- curl
- dnsutils
- iproute2
- logrotate

Observability agents:
- Prometheus node exporter (node_exporter)
- Log shipper agent: promtail or fluent-bit (choose one standard for the platform)

## Policy defaults

- Default firewall stance: deny inbound, allow required ports only.
- Time sync mandatory for certificates and cluster behaviour.
- Security updates automatic, with a controlled reboot strategy as per your governance.
