#!/bin/sh
# Xcode build phase "Official Build Components" (Issue238 — DISTRIBUTION-TERMS.md v1.2 §1(b)).
#
# FSNIPPET_OFFICIAL_BUILD=YES (passed only by `fsc-deploy-brew.sh publish`) bundles:
#   Contents/Resources/Official/ <- cli/resources/official/  (Finfra-proprietary, not Apache)
#   Contents/Resources/Legal/    <- LICENSE, NOTICE, TRADEMARK.md, DISTRIBUTION-TERMS.md
#                                   (terms shipped inside the package — DISTRIBUTION-TERMS §6)
# Any other build is a source build: remove whatever an earlier official build left in the
# same DerivedData, so the marker can never leak into a source build.
# The phase runs before code signing, so the signature seals the copied files.

set -eu

DEST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
OFFICIAL_SRC="${SRCROOT}/resources/official"
REPO_ROOT="${SRCROOT}/.."
LEGAL_FILES="LICENSE NOTICE TRADEMARK.md DISTRIBUTION-TERMS.md"

STAMP="$DEST/OfficialBuildState"

# Xcode skips CodeSign when its own inputs did not change, and it does not see files this
# script adds or removes — the old seal would then point at missing or unsealed files.
# The stamp is this phase's declared output; rewriting it only when the bundled state
# changes makes Xcode re-sign exactly then.
write_stamp() {
    if [ ! -f "$STAMP" ] || [ "$(cat "$STAMP")" != "$1" ]; then
        printf '%s\n' "$1" > "$STAMP"
    fi
}

mkdir -p "$DEST"
rm -rf "$DEST/Official" "$DEST/Legal"

if [ "${FSNIPPET_OFFICIAL_BUILD:-NO}" != "YES" ]; then
    write_stamp "source"
    echo "Official Build Components: source build — none bundled"
    exit 0
fi

# Check every input before copying anything, so a failure leaves no half-bundled state.
for f in "$OFFICIAL_SRC/official-build.txt" $(for l in $LEGAL_FILES; do echo "$REPO_ROOT/$l"; done); do
    if [ ! -f "$f" ]; then
        echo "error: $f missing — cannot make an Official Build"
        exit 1
    fi
done

mkdir -p "$DEST/Official" "$DEST/Legal"
cp -R "$OFFICIAL_SRC/." "$DEST/Official/"
for f in $LEGAL_FILES; do
    cp "$REPO_ROOT/$f" "$DEST/Legal/$f"
done

# Assigned on its own line so a failure is caught instead of writing a partial stamp.
DIGEST=$(cd "$DEST" && find Official Legal -type f -print0 | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256 | shasum -a 256 | cut -c1-16)
case "$DIGEST" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
    *) echo "error: could not hash the bundled Official Build Components ('$DIGEST')"; exit 1 ;;
esac
write_stamp "official $DIGEST"
echo "Official Build Components: bundled Official/ and Legal/ into $DEST"
