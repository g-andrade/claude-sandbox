#!/usr/bin/env bash
# Install and start the nftables backstop as a systemd service.
# Usage: sudo ./firewall/install.sh
# Re-run after editing claude-sandbox.nft. Remove with:
#   sudo systemctl disable --now claude-sandbox-firewall
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

nft -c -f claude-sandbox.nft
install -Dm644 claude-sandbox.nft /etc/claude-sandbox/claude-sandbox.nft
install -Dm644 claude-sandbox-firewall.service /etc/systemd/system/claude-sandbox-firewall.service
systemctl daemon-reload
systemctl enable claude-sandbox-firewall.service
systemctl restart claude-sandbox-firewall.service
nft list table inet claude_sandbox
