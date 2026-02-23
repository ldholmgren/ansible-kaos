#!/usr/bin/env bash
# bootstrap.sh - One-shot provisioning for CachyOS
# Usage: ./scripts/bootstrap.sh [ansible-playbook args...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
export ANSIBLE_CONFIG="$REPO_DIR/ansible.cfg"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }
info() { echo -e "${CYAN}[i]${NC} $*"; }

# ── Pre-flight checks ───────────────────────────────────────────────────

# Must be Arch/CachyOS
if ! command -v pacman &>/dev/null; then
    err "This script requires pacman (Arch/CachyOS)."
    exit 1
fi

# Don't run as root
if [[ $EUID -eq 0 ]]; then
    err "Do not run as root. It will use sudo when needed."
    exit 1
fi

# Check sudo works
if ! sudo -v 2>/dev/null; then
    err "sudo access required. Make sure your user is in the wheel group."
    exit 1
fi

# Suppress noisy kernel messages to console
sudo dmesg -n 1 2>/dev/null || true

log "Starting CachyOS provisioning..."

# ── Network check ────────────────────────────────────────────────────────

log "Checking network..."
if ! ping -c1 -W3 archlinux.org &>/dev/null; then
    err "No internet. Check your network connection."
    info "IP addresses:"
    ip -br addr show | grep -v "^lo"
    exit 1
fi
log "Network OK"

# ── Enable SSH ───────────────────────────────────────────────────────────

log "Enabling SSH..."
sudo pacman -S --noconfirm --needed openssh

# Generate host keys if missing
sudo ssh-keygen -A 2>/dev/null || true

# Enable password auth (covers fresh installs and locked-down defaults)
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
# Also check sshd_config.d drop-ins
if ls /etc/ssh/sshd_config.d/*.conf &>/dev/null; then
    sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
fi

# Ensure sshd listens on port 22 (not overridden)
sudo sed -i 's/^#\?Port .*/Port 22/' /etc/ssh/sshd_config

sudo systemctl enable --now sshd
sudo systemctl restart sshd

# Open firewall for SSH — CachyOS uses ufw by default
if command -v ufw &>/dev/null; then
    log "ufw detected, allowing SSH..."
    sudo ufw allow ssh
    sudo ufw --force enable
fi
# Fallback: iptables / nftables
if iptables -L INPUT -n 2>/dev/null | grep -q "DROP\|REJECT"; then
    log "iptables rules detected, opening port 22..."
    sudo iptables -I INPUT -p tcp --dport 22 -j ACCEPT
fi
if command -v nft &>/dev/null && nft list ruleset 2>/dev/null | grep -q "drop"; then
    log "nftables rules detected, opening port 22..."
    sudo nft add rule inet filter input tcp dport 22 accept 2>/dev/null || true
fi

# Verify sshd is actually listening
if ss -tlnp | grep -q ":22 "; then
    log "SSH listening on port 22"
    info "SSH access: ssh $(whoami)@$(hostname -I | awk '{print $1}')"
else
    warn "SSH not listening on port 22 — check 'journalctl -u sshd' for errors"
fi

# ── Install Ansible ──────────────────────────────────────────────────────

if ! command -v ansible-playbook &>/dev/null; then
    log "Installing Ansible..."
    sudo pacman -Sy --noconfirm ansible python-passlib
else
    log "Ansible already installed."
fi

# ── Install Galaxy collections ───────────────────────────────────────────

log "Installing Ansible Galaxy dependencies..."
if ! ansible-galaxy collection install -r "$REPO_DIR/requirements.yml" --force; then
    warn "Galaxy install failed, retrying..."
    ansible-galaxy collection install -r "$REPO_DIR/requirements.yml" --force
fi

# ── Detect environment ───────────────────────────────────────────────────

LIMIT="localhost"
VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")

if [[ "$VIRT" == "vmware" ]]; then
    LIMIT="vmware-test"
    log "Detected VMware VM — using vmware-test profile"
elif [[ "$VIRT" != "none" ]]; then
    info "Running in virtualized environment: $VIRT"
fi

info "Host: $(hostname)"
info "Kernel: $(uname -r)"
info "Profile: $LIMIT"

# ── Run playbook ─────────────────────────────────────────────────────────

log "Running site.yml playbook..."
ansible-playbook "$REPO_DIR/playbooks/site.yml" \
    --limit "$LIMIT" \
    "$@"

log "Provisioning complete!"
log "Please reboot to apply kernel parameters and start fresh."
