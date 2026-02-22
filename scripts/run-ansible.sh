#!/usr/bin/env bash
# run-ansible.sh - Wrapper for running Ansible playbooks
# Usage: ./scripts/run-ansible.sh [playbook] [extra args...]
# Example: ./scripts/run-ansible.sh site.yml --tags base,hardware
#          ./scripts/run-ansible.sh site.yml --tags kde -e install_kde=true
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PLAYBOOK="${1:-site.yml}"
shift 2>/dev/null || true

# Resolve playbook path
if [[ ! -f "$PLAYBOOK" ]]; then
    PLAYBOOK="$REPO_DIR/playbooks/$PLAYBOOK"
fi

if [[ ! -f "$PLAYBOOK" ]]; then
    echo "Error: Playbook not found: $PLAYBOOK" >&2
    echo "Usage: $0 [playbook.yml] [ansible-playbook args...]" >&2
    exit 1
fi

# Ensure collections are installed
ansible-galaxy collection install -r "$REPO_DIR/requirements.yml" 2>/dev/null

# Run playbook
exec ansible-playbook "$PLAYBOOK" \
    --ask-become-pass \
    "$@"
