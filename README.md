
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Fouchger/fouchger_homelab/main/install.sh)"

bash -c "$(curl -fsSL https://raw.githubusercontent.com/Fouchger/fouchger_homelab/refs/heads/rewrite/bootstrap.sh)"


## Target structure
```
fouchger_homelab/
  README.md
  VERSION

  bootstrap.sh                     # Entry point users run (from anywhere)
  homelab.sh                       # Repo entry wrapper (calls menu)

  bin/
    menu.sh                        # The dialog UI menu (main controller)
    lib/
      ui.sh                        # dialog helpers, theme, common widgets
      log.sh                       # logging helpers
      os.sh                        # OS detection + minimal package install
      perms.sh                     # chmod + executable enforcement
      validate.sh                  # input validation (IP, tokens, etc.)
      config.sh                    # load/save config

  config/
    settings.env                   # persisted config (non-secret)
    secrets.env.example            # template only (never commit secrets.env)
    profiles.yml                   # predefined profiles -> app lists
    apps.yml                       # app catalogue, install/uninstall handlers
    proxmox.env.example            # example for Proxmox auth details

  state/
    selections.env                 # persisted selections (generated)
    logs/
      homelab.log

  modules/
    apps/
      install/                     # scripts called by apps.yml
        docker.sh
        tailscale.sh
        nfs.sh
        vscode-server.sh
      uninstall/
        docker.sh
        tailscale.sh
        nfs.sh
        vscode-server.sh

    proxmox/
      setup_access.sh              # create role/user/token (via pve API/CLI)
      download_templates.sh         # Ubuntu 22.04+ LXC + Talos latest
      terraform/
        main.tf
        variables.tf
        outputs.tf
        versions.tf
        providers.tf
        modules/
          lxc/
          vm/
      ansible/
        ansible.cfg
        inventory/
          proxmox_dynamic.yml       # optional
          hosts.ini                 # fallback
        playbooks/
          site.yml
          base.yml
          k8s_talos.yml
        roles/
          common/
          hardening/
          docker/
          monitoring/

  docs/
    ADRs/
    runbooks/
```

## Design intent:

- bootstrap.sh is the only thing you run manually. It installs the bare minimum: `git` (or `curl` + `tar` if you prefer), `dialog`, and CA certs. Then it clones the repo and hands off to `homelab.sh`.
- `bin/menu.sh` is the single source of truth for user workflow. Everything else is a module invoked by the menu.
- Executable permissions are enforced in one place (`bin/lib/perms.sh`) and run after download and before menu.