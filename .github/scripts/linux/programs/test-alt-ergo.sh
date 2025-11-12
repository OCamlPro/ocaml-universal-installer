#!/bin/bash
set -euo pipefail

# This script tests .pkg installer creation, installation, and functionality

REMOTE_USER="origin"
REMOTE_BRANCH="alt-ergo-linux-builds"
ARTIFACTS=(alt-ergo-bundle alt-ergo-oui.json semantic_triggers.ae)
INSTALLER_NAME="alt-ergo-dev.run"
BINARY_NAME="alt-ergo"

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%H:%M:%S')] ERROR: $1" >&2
    exit 1
}

log "Fetching alt-ergo artifacts from ${REMOTE_USER}/${REMOTE_BRANCH}"
git fetch ${REMOTE_USER} ${REMOTE_BRANCH}
git checkout ${REMOTE_USER}/${REMOTE_BRANCH} -- ${ARTIFACTS[*]}

# Build package
log "Building ${INSTALLER_NAME}"
opam exec -- oui alt-ergo-oui.json alt-ergo-bundle
[[ -f "${INSTALLER_NAME}" ]] || error "Package file not found: ${INSTALLER_NAME}"

# Install package
log "Installing ${INSTALLER_NAME}"
sudo ./${INSTALLER_NAME}

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
