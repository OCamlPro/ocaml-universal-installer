#!/bin/bash
set -euo pipefail

# This script tests .pkg installer creation, installation, and functionality

REMOTE_USER="arozovyk"
REMOTE_BRANCH="alt-ergo-mac-builds"
ARTIFACTS=(alt-ergo alt-ergo-oui.json semantic_triggers.ae)
PACKAGE_NAME="alt-ergo-dev.pkg"
BINARY_NAME="alt-ergo"

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%H:%M:%S')] ERROR: $1" >&2
    exit 1
}

log "Fetching alt-ergo artifacts from ${REMOTE_USER}/${REMOTE_BRANCH}"
git remote add ${REMOTE_USER} https://github.com/${REMOTE_USER}/ocaml-universal-installer.git 2>/dev/null || true
git fetch ${REMOTE_USER} ${REMOTE_BRANCH}
git checkout ${REMOTE_USER}/${REMOTE_BRANCH} -- ${ARTIFACTS[*]}

# Build package
log "Building ${PACKAGE_NAME}"
opam exec -- oui alt-ergo-oui.json alt-ergo
[[ -f "${PACKAGE_NAME}" ]] || error "Package file not found: ${PACKAGE_NAME}"

# Install package
log "Installing ${PACKAGE_NAME}"
sudo installer -pkg ${PACKAGE_NAME} -target /

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
