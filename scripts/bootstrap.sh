#!/usr/bin/env bash
# bootstrap.sh - One-shot provisioning for CachyOS
# Usage: curl -fsSL <url>/bootstrap.sh | bash
#    or: ./scripts/bootstrap.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

# Check we're on Arch/CachyOS
if ! command -v pacman &>/dev/null; then
    err "This script requires pacman (Arch/CachyOS)."
    exit 1
fi

# Check root
if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root. It will use sudo when needed."
    exit 1
fi

log "Starting CachyOS provisioning..."

# Install Ansible if not present
if ! command -v ansible-playbook &>/dev/null; then
    log "Installing Ansible..."
    sudo pacman -Sy --noconfirm ansible
else
    log "Ansible already installed."
fi

# Install required collections
log "Installing Ansible Galaxy dependencies..."
ansible-galaxy collection install -r "$REPO_DIR/requirements.yml" --force

# Run the full site playbook
log "Running site.yml playbook..."
ansible-playbook "$REPO_DIR/playbooks/site.yml" \
    --ask-become-pass \
    "$@"

log "Provisioning complete!"
log "Please reboot to apply kernel parameters and start fresh."
