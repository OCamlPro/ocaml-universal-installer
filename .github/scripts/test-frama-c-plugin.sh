#!/bin/bash
# test-frama-c-plugin.sh - integration test for macOS plugin support
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(pwd)/frama-c-test"
mkdir -p "$WORK_DIR"

log() { echo "[$(date +'%H:%M:%S')] $1"; }
error() { echo "[$(date +'%H:%M:%S')] ERROR: $1" >&2; exit 1; }

log "work: $WORK_DIR, switch: $(opam switch show)"

[[ -d "$WORK_DIR/frama-c" ]] || git clone --depth 1 https://git.frama-c.com/pub/frama-c.git "$WORK_DIR/frama-c"
[[ -d "$WORK_DIR/meta" ]] || git clone --depth 1 https://git.frama-c.com/pub/meta.git "$WORK_DIR/meta"

# pin both to avoid ABI mismatch
opam pin add frama-c "$WORK_DIR/frama-c" --kind=path -n -y
opam pin add frama-c-metacsl "$WORK_DIR/meta" --kind=path -n -y
opam install frama-c frama-c-metacsl --deps-only -y

log "building frama-c..."
(
    cd "$WORK_DIR/frama-c"
    opam exec -- dune build --root=. @install
    opam exec -- dune install --root=.
    opam exec -- dune install --root=. --prefix=_build/install/bundle --relocatable
)

log "building metacsl..."
(
    cd "$WORK_DIR/meta"
    opam exec -- dune build --root=. @install
    opam exec -- dune install --root=. --prefix=_build/install/bundle --relocatable
)

log "creating bundles..."
FRAMA_C_BUNDLE="$WORK_DIR/bundles/frama-c"
METACSL_BUNDLE="$WORK_DIR/bundles/metacsl"
mkdir -p "$FRAMA_C_BUNDLE" "$METACSL_BUNDLE"
cp -R "$WORK_DIR/frama-c/_build/install/bundle"/* "$FRAMA_C_BUNDLE/"
cp -R "$WORK_DIR/meta/_build/install/bundle"/* "$METACSL_BUNDLE/"

# dune relocatable doesn't include external deps
OPAM_LIB="$(opam var lib)"
for dep in unionFind yojson ppx_deriving ppx_deriving_yojson why3; do
  [[ -d "$OPAM_LIB/$dep" ]] && cp -R "$OPAM_LIB/$dep" "$FRAMA_C_BUNDLE/lib/"
done

cat > "$FRAMA_C_BUNDLE/oui.json" << 'EOF'
{
  "name": "frama-c",
  "fullname": "Frama-C",
  "version": "32.0",
  "unique_id": "com.cea.frama-c",
  "exec_files": ["bin/frama-c", "bin/frama-c-config", "bin/frama-c-script"],
  "wix_manufacturer": "CEA LIST",
  "plugin_dirs": { "plugins_dir": "lib/frama-c/plugins", "lib_dir": "lib" },
  "macos_symlink_dirs": ["lib", "share"],
  "manpages": { "man1": "man/man1" }
}
EOF

cat > "$METACSL_BUNDLE/oui.json" << 'EOF'
{
  "name": "metacsl",
  "fullname": "MetAcsl",
  "version": "0.10",
  "unique_id": "com.cea.frama-c-metacsl",
  "exec_files": [],
  "wix_manufacturer": "CEA LIST",
  "plugins": [{
    "name": "metacsl",
    "app_name": "frama-c",
    "plugin_dir": "lib/frama-c/plugins/metacsl",
    "lib_dir": "lib/frama-c-metacsl"
  }]
}
EOF

log "building packages..."
opam exec -- oui build --backend=pkgbuild -o "$WORK_DIR/frama-c.pkg" "$FRAMA_C_BUNDLE/oui.json" "$FRAMA_C_BUNDLE"
opam exec -- oui build --backend=pkgbuild -o "$WORK_DIR/metacsl.pkg" "$METACSL_BUNDLE/oui.json" "$METACSL_BUNDLE"

log "installing packages..."
sudo installer -pkg "$WORK_DIR/frama-c.pkg" -target /
sudo installer -pkg "$WORK_DIR/metacsl.pkg" -target /

log "verifying..."
frama-c --version
SHARE_PATH=$(frama-c -print-share-path 2>/dev/null || echo "FAILED")
log "share path: $SHARE_PATH"
[[ "$SHARE_PATH" != *"//"* && "$SHARE_PATH" != *"_build"* ]] || error "share path broken"

ls -la /Applications/Frama-c.app/Contents/Resources/lib/frama-c/plugins/ | grep metacsl || error "metacsl symlink missing"
ls -la /Applications/Frama-c.app/Contents/Resources/lib/ | grep frama-c-metacsl || error "lib symlink missing"

log "testing metacsl..."
PLUGIN_OUTPUT=$(frama-c -meta-h 2>&1) || true
echo "$PLUGIN_OUTPUT" | head -20
echo "$PLUGIN_OUTPUT" | grep -q "Plug-in name: MetAcsl" || error "metacsl failed to load"
log "metacsl ok"

log "testing eva..."
TEST_DIR="$WORK_DIR/eva-test"
mkdir -p "$TEST_DIR"
cp "$SCRIPT_DIR/eva-test/"*.c "$TEST_DIR/"
cd "$TEST_DIR"
EVA_OUTPUT=$(frama-c idct.c ieee_1180_1990.c -eva 2>&1) || true
echo "$EVA_OUTPUT" | tail -20
echo "$EVA_OUTPUT" | grep -q "ANALYSIS SUMMARY" || error "eva analysis failed"
log "eva ok"

log "testing uninstall..."
sudo /Applications/Metacsl.app/Contents/Resources/uninstall.sh
sudo /Applications/Frama-c.app/Contents/Resources/uninstall.sh
[[ ! -d /Applications/Frama-c.app ]] || error "Frama-c.app not removed"
[[ ! -d /Applications/Metacsl.app ]] || error "Metacsl.app not removed"
[[ ! -f /usr/local/bin/frama-c ]] || error "frama-c symlink not removed"

log "all tests passed"
