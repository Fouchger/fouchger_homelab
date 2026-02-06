#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: branch_tool.sh
# Purpose:
#   1) Create an empty (orphan) branch in a NEW FOLDER (worktree), commit, push.
#   2) Create a branch from an existing remote branch in a NEW FOLDER (worktree),
#      commit, push.
#
# Notes:
# - Run this from inside your existing local repo.
# - Uses git worktree so each branch gets its own directory.
# - Requires a remote named 'origin'.
# - Does not force-push.
# - After creation, you can remove the folder safely using:
#     git worktree remove <folder>
# -----------------------------------------------------------------------------

set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }
info() { echo "Info: $*"; }

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a Git repository."
}

require_origin_remote() {
  git remote get-url origin >/dev/null 2>&1 || die "Remote 'origin' not found. Add it first (git remote add origin ...)."
}

fetch_all() {
  info "Fetching latest refs from origin..."
  git fetch --prune origin
}

branch_exists_local() {
  git show-ref --verify --quiet "refs/heads/$1"
}

branch_exists_remote() {
  git ls-remote --exit-code --heads origin "$1" >/dev/null 2>&1
}

worktree_path_exists() {
  local p="$1"
  [[ -e "$p" ]]
}

prompt_nonempty() {
  local prompt="$1"
  local val
  read -r -p "$prompt" val
  [[ -n "${val// }" ]] || die "Value cannot be empty."
  echo "$val"
}

select_remote_branch() {
  mapfile -t branches < <(git branch -r | sed 's/^[[:space:]]*//' | grep -vE '^origin/HEAD ->' | sort)
  ((${#branches[@]} > 0)) || die "No remote branches found under origin."

  echo
  echo "Available remote branches:"
  local i=1
  for b in "${branches[@]}"; do
    echo "  [$i] $b"
    ((i++))
  done

  echo
  local choice
  read -r -p "Choose a branch number to base from: " choice
  [[ "$choice" =~ ^[0-9]+$ ]] || die "Please enter a valid number."
  ((choice >= 1 && choice <= ${#branches[@]})) || die "Choice out of range."

  local selected="${branches[$((choice-1))]}"
  echo "${selected#origin/}"
}

create_empty_branch_in_new_folder() {
  local new_branch
  new_branch="$(prompt_nonempty "Enter NEW empty branch name: ")"

  if branch_exists_local "$new_branch"; then
    die "Local branch '$new_branch' already exists. Choose a different name."
  fi
  if branch_exists_remote "$new_branch"; then
    die "Remote branch 'origin/$new_branch' already exists. Choose a different name."
  fi

  local folder
  folder="$(prompt_nonempty "Enter folder name/path for this branch worktree (e.g., ../$new_branch): ")"

  if worktree_path_exists "$folder"; then
    die "Folder/path '$folder' already exists. Choose a new folder or delete it first."
  fi

  # Create a worktree based on current HEAD (any commit), then switch it to an orphan branch.
  info "Creating worktree folder '$folder'..."
  git worktree add "$folder" HEAD >/dev/null

  info "Switching worktree to orphan branch '$new_branch' (empty baseline)..."
  (
    cd "$folder"
    git checkout --orphan "$new_branch" >/dev/null

    # Clear working tree to truly empty (safe inside orphan branch)
    info "Clearing working tree in '$folder'..."
    git rm -rf . >/dev/null 2>&1 || true
    git clean -fdx >/dev/null 2>&1 || true

    # Practical marker file so the first commit has content
    echo "# $new_branch" > README.md

    git add -A
    git commit -m "Initial empty branch: $new_branch" >/dev/null

    info "Pushing '$new_branch' to origin and setting upstream..."
    git push -u origin "$new_branch" >/dev/null
  )

  info "Done."
  echo "Worktree created at: $folder"
  echo "Branch pushed to: origin/$new_branch"
}

create_branch_from_existing_in_new_folder() {
  local base_branch
  base_branch="$(select_remote_branch)"

  local new_branch
  new_branch="$(prompt_nonempty "Enter NEW branch name to create from '$base_branch': ")"

  if branch_exists_local "$new_branch"; then
    die "Local branch '$new_branch' already exists. Choose a different name."
  fi
  if branch_exists_remote "$new_branch"; then
    die "Remote branch 'origin/$new_branch' already exists. Choose a different name."
  fi

  local folder
  folder="$(prompt_nonempty "Enter folder name/path for this branch worktree (e.g., ../$new_branch): ")"

  if worktree_path_exists "$folder"; then
    die "Folder/path '$folder' already exists. Choose a new folder or delete it first."
  fi

  info "Creating worktree for '$new_branch' from 'origin/$base_branch' in '$folder'..."
  git worktree add -b "$new_branch" "$folder" "origin/$base_branch" >/dev/null

  (
    cd "$folder"
    # Make a commit so there is always something new to push, even if identical to base.
    info "Creating an empty commit on '$new_branch' (ensures a new commit exists)..."
    git commit --allow-empty -m "Create branch '$new_branch' from '$base_branch'" >/dev/null

    info "Pushing '$new_branch' to origin and setting upstream..."
    git push -u origin "$new_branch" >/dev/null
  )

  info "Done."
  echo "Worktree created at: $folder"
  echo "Branch pushed to: origin/$new_branch (based on $base_branch)"
}

main_menu() {
  require_git_repo
  require_origin_remote
  fetch_all

  echo
  echo "Branch Tool (with new folder per branch via git worktree)"
  echo "  [1] Create empty (orphan) branch in a new folder, commit, push"
  echo "  [2] Create branch from existing remote branch in a new folder, commit, push"
  echo "  [q] Quit"
  echo

  local action
  read -r -p "Select an option: " action

  case "$action" in
    1) create_empty_branch_in_new_folder ;;
    2) create_branch_from_existing_in_new_folder ;;
    q|Q) info "Exiting."; exit 0 ;;
    *) die "Invalid option." ;;
  esac
}

main_menu
