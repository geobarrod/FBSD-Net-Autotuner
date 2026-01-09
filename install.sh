#!/bin/sh
# install.sh - Installer for FreeBSD Network Autotuner
# Author: Geovanni B.R. (geobarrod)
# Date: 2025-12-25

set -e

# Verify root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This installer must be run as root."
  exit 1
fi

# Paths
BIN_DIR="/root/bin"
RC_DIR="/usr/local/etc/rc.d"
SCRIPT_NAME="fbsd-net-autotuner"
SERVICE_NAME="net_autotuner"

echo "Installing FreeBSD Network Autotuner..."

# Create /root/bin if it doesn't exist
if [ ! -d "$BIN_DIR" ]; then
  echo "Creating $BIN_DIR..."
  mkdir -p "$BIN_DIR"
fi

# Copy main script
echo "Copying $SCRIPT_NAME to $BIN_DIR..."
cp "$SCRIPT_NAME" "$BIN_DIR/"
chmod 755 "$BIN_DIR/$SCRIPT_NAME"

# Copy service script
echo "Copying $SERVICE_NAME to $RC_DIR..."
cp "$SERVICE_NAME" "$RC_DIR/"
chmod 755 "$RC_DIR/$SERVICE_NAME"

echo "Installation complete."
echo "You can now for testing run: $BIN_DIR/$SCRIPT_NAME"
echo "And manage the service via: service $SERVICE_NAME enable|start|restart|stop|disable"
