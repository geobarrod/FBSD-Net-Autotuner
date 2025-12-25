#!/bin/sh
# uninstall.sh - Uninstaller for FreeBSD Network Autotuner
# Author: Geovanni B.R. (geobarrod)
# Date: 2025-12-25

set -e

# Verify root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This uninstaller must be run as root."
  exit 1
fi

# Paths
BIN_DIR="/root/bin"
RC_DIR="/usr/local/etc/rc.d"
SCRIPT_NAME="fbsd-net-autotuner"
SERVICE_NAME="net_autotuner"

echo "Uninstalling FreeBSD Network Autotuner..."

# Remove main script
if [ -f "$BIN_DIR/$SCRIPT_NAME" ]; then
  echo "Removing $BIN_DIR/$SCRIPT_NAME..."
  rm -f "$BIN_DIR/$SCRIPT_NAME"
fi

# Remove service script
if [ -f "$RC_DIR/$SERVICE_NAME" ]; then
  echo "Removing $RC_DIR/$SERVICE_NAME..."
  rm -f "$RC_DIR/$SERVICE_NAME"
fi

# Remove /root/bin if empty
if [ -d "$BIN_DIR" ] && [ -z "$(ls -A "$BIN_DIR")" ]; then
  echo "Removing empty directory $BIN_DIR..."
  rmdir "$BIN_DIR"
fi

echo "Uninstallation complete."
