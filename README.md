# fouchger_homelab

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Fouchger/fouchger_homelab/main/install.sh)"
```

## To keep multiple branches on machine

From inside your existing repo:

```bash
cd ~/Fouchger/fouchger_homelab
```

Now create a new worktree directory for the new branch:

```bash
# Add branch back_to_basic
git worktree add -b back_to_basic ~/Fouchger/fouchger_homelab-back_to_basic
```

This will:
• Create the branch back_to_basic
• Check it out in a new folder outside your current one
• Keep everything linked to the same underlying Git repo

Move into your new working directory

```bash
cd ~/Fouchger/fouchger_homelab-back_to_basic
```

Now you can work independently on back_to_basic while still keeping your rewrite branch active in the original folder.
