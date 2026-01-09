#!/bin/bash
set -euo pipefail

WORK_DIR="$(pwd)/frama-c-test"
mkdir -p "$WORK_DIR"

log() { echo "[$(date +'%H:%M:%S')] $1"; }
error() { echo "[$(date +'%H:%M:%S')] ERROR: $1" >&2; exit 1; }

log "Working directory: $WORK_DIR"
log "Using switch: $(opam switch show)"

log "Cloning frama-c..."
[[ -d "$WORK_DIR/frama-c" ]] || \
    git clone --depth 1 https://git.frama-c.com/pub/frama-c.git "$WORK_DIR/frama-c"

log "Cloning metacsl..."
[[ -d "$WORK_DIR/meta" ]] || \
    git clone --depth 1 https://git.frama-c.com/pub/meta.git "$WORK_DIR/meta"

# Pin both packages upfront to prevent ABI mismatch when installing deps
log "Pinning packages..."
opam pin add frama-c "$WORK_DIR/frama-c" --kind=path -n -y
opam pin add frama-c-metacsl "$WORK_DIR/meta" --kind=path -n -y

log "Installing dependencies..."
opam install frama-c frama-c-metacsl --deps-only -y

# Build with dune relocatable
log "Building frama-c..."
(
    cd "$WORK_DIR/frama-c"
    opam exec -- dune build --root=. @install
    opam exec -- dune install --root=.
    opam exec -- dune install --root=. --prefix=_build/install/bundle --relocatable
)

log "Building metacsl..."
(
    cd "$WORK_DIR/meta"
    opam exec -- dune build --root=. @install
    opam exec -- dune install --root=. --prefix=_build/install/bundle --relocatable
)

log "Creating bundles..."
FRAMA_C_BUNDLE="$WORK_DIR/bundles/frama-c"
METACSL_BUNDLE="$WORK_DIR/bundles/metacsl"
mkdir -p "$FRAMA_C_BUNDLE" "$METACSL_BUNDLE"
cp -R "$WORK_DIR/frama-c/_build/install/bundle"/* "$FRAMA_C_BUNDLE/"
cp -R "$WORK_DIR/meta/_build/install/bundle"/* "$METACSL_BUNDLE/"

cat > "$FRAMA_C_BUNDLE/oui.json" << 'EOF'
{
  "name": "frama-c",
  "fullname": "Frama-C",
  "version": "32.0",
  "exec_files": ["bin/frama-c"],
  "unique_id": "F4A8C3B2-1D5E-4F9A-8B6C-7E2D1A3F5C9B",
  "wix_manufacturer": "CEA LIST",
  "plugin_dirs": {
    "plugins_dir": "lib/frama-c/plugins",
    "lib_dir": "lib/frama-c/lib"
  },
  "macos_symlink_dirs": ["lib", "share"],
  "manpages": { "man1": "man/man1" }
}
EOF

cat > "$METACSL_BUNDLE/oui.json" << 'EOF'
{
  "name": "metacsl",
  "fullname": "MetAcsl",
  "version": "0.10",
  "exec_files": [],
  "unique_id": "A1B2C3D4-5E6F-7A8B-9C0D-E1F2A3B4C5D6",
  "wix_manufacturer": "CEA LIST",
  "plugins": [{
    "name": "metacsl",
    "app_name": "frama-c",
    "plugin_dir": "lib/frama-c/plugins/metacsl",
    "lib_dir": "lib/frama-c/lib/meta",
    "dyn_deps": ["lib/frama-c-metacsl"]
  }]
}
EOF

log "Building packages..."
opam exec -- oui build --backend=pkgbuild \
    -o "$WORK_DIR/frama-c.pkg" "$FRAMA_C_BUNDLE/oui.json" "$FRAMA_C_BUNDLE"
opam exec -- oui build --backend=pkgbuild \
    -o "$WORK_DIR/metacsl.pkg" "$METACSL_BUNDLE/oui.json" "$METACSL_BUNDLE"

log "Installing packages..."
sudo installer -pkg "$WORK_DIR/frama-c.pkg" -target /
sudo installer -pkg "$WORK_DIR/metacsl.pkg" -target /

log "Verifying installation..."
frama-c --version

SHARE_PATH=$(frama-c -print-share-path 2>/dev/null || echo "FAILED")
log "Share path: $SHARE_PATH"
[[ "$SHARE_PATH" != *"//"* && "$SHARE_PATH" != *"_build"* ]] || \
    error "Share path broken - relocatable failed"

log "Checking symlinks..."
ls -la /Applications/Frama-c.app/Contents/Resources/lib/frama-c/plugins/ \
    | grep metacsl || error "metacsl symlink missing"
ls -la /Applications/Frama-c.app/Contents/Resources/lib/ \
    | grep frama-c-metacsl || error "frama-c-metacsl symlink missing"

# Test that MetAcsl plugin actually loads and responds to -meta-h
# Success: shows "Plug-in name: MetAcsl"
# Failure (ABI mismatch, missing deps): warnings, no plugin help
log "Testing MetAcsl plugin..."
PLUGIN_OUTPUT=$(frama-c -meta-h 2>&1) || true
echo "$PLUGIN_OUTPUT" | head -40
echo "$PLUGIN_OUTPUT" | grep -q "Plug-in name: MetAcsl" || \
    error "MetAcsl plugin failed to load"
log "MetAcsl plugin works!"

log "Testing uninstall..."
sudo /Applications/Metacsl.app/Contents/Resources/uninstall.sh
sudo /Applications/Frama-c.app/Contents/Resources/uninstall.sh

[[ ! -d /Applications/Frama-c.app ]] || error "Frama-c.app not removed"
[[ ! -d /Applications/Metacsl.app ]] || error "Metacsl.app not removed"
[[ ! -f /usr/local/bin/frama-c ]] || error "frama-c symlink not removed"

log "All tests passed!"
