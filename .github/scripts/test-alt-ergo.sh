#!/bin/bash
set -euo pipefail

SYSTEM=$1

# This script tests installer creation, installation, and functionality for
# alt-ergo and one of its builtin plugins.

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%H:%M:%S')] ERROR: $1" >&2
    exit 1
}

case "$SYSTEM" in
  linux)
    BRANCH="alt-ergo-linux-builds"
    INSTALLER_NAME="alt-ergo-dev.run"
    ;;
  macos)
    BRANCH="alt-ergo-mac-builds"
    INSTALLER_NAME="alt-ergo-dev.pkg"
    ;;
  *)
    error "Unsupported system: $SYSTEM"
    ;;
esac

ARTIFACTS=(alt-ergo-bundle alt-ergo-oui.json semantic_triggers.ae)
BINARY_NAME="alt-ergo"

log "Fetching alt-ergo artifacts from ${BRANCH}"
git fetch origin ${BRANCH}
git checkout origin/${BRANCH} -- ${ARTIFACTS[*]}

# Build installer
log "Building ${INSTALLER_NAME}"
opam exec -- oui build alt-ergo-oui.json alt-ergo-bundle
[[ -f "${INSTALLER_NAME}" ]] || error "Package file not found: ${INSTALLER_NAME}"

# Install package
log "Installing ${INSTALLER_NAME}"
case "$SYSTEM" in
  linux)
    sudo ./${INSTALLER_NAME}
    ;;
  macos)
    sudo installer -pkg ${INSTALLER_NAME} -target /
    ;;
  *);;
esac

# Verify installation
log "Verifying ${BINARY_NAME} installation"
${BINARY_NAME} --version

# Run semantic triggers test
log "Testing with semantic triggers"
${BINARY_NAME} --inequalities-plugin fm-simplex -o smtlib2 semantic_triggers.ae

# Verify man page
log "Verifying man page installation"
man -w ${BINARY_NAME} >/dev/null

log "All tests passed"
