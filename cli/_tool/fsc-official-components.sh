#!/bin/sh
# Xcode build phase "Official Build Components" (Issue238 — DISTRIBUTION-TERMS.md v1.2 §1(b)).
#
# Every build (Issue254):
#   Contents/Resources/AppIcon.icns <- iconutil cli/resources/official/AppIcon.iconset
#     The icon stays a Finfra brand asset outside the Apache license (it lives in
#     resources/official/, not the asset catalog — Issue242), but source builds ship it too
#     instead of falling back to the macOS default icon (user decision 2026-10-09).
# FSNIPPET_OFFICIAL_BUILD=YES (passed only by `fsc-deploy-brew.sh publish`) also bundles:
#   Contents/Resources/Official/ <- cli/resources/official/  (Finfra-proprietary, not Apache)
#                                   except AppIcon.iconset (already the app icon above)
#   Contents/Resources/Legal/    <- LICENSE, NOTICE, TRADEMARK.md, DISTRIBUTION-TERMS.md,
#                                   DISTRIBUTION-TERMS_ko.md
#                                   (terms shipped inside the package — DISTRIBUTION-TERMS §6;
#                                   the Korean text has equal force for Korean residents — §10, Issue241)
# Any other build is a source build: remove whatever an earlier official build left in the
# same DerivedData, so the marker and the terms can never leak into a source build.
# Info.plist names CFBundleIconFile=AppIcon in every build and the public asset catalog has
# no app icon, so AppIcon.icns is the one icon every build shows.
# The phase runs before code signing, so the signature seals the copied files.

set -eu

DEST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
OFFICIAL_SRC="${SRCROOT}/resources/official"
ICONSET="$OFFICIAL_SRC/AppIcon.iconset"
REPO_ROOT="${SRCROOT}/.."
LEGAL_FILES="LICENSE NOTICE TRADEMARK.md DISTRIBUTION-TERMS.md DISTRIBUTION-TERMS_ko.md"

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
# AppIcon.icns also covers the icon actool generated before the catalog was emptied (Issue242).
rm -rf "$DEST/Official" "$DEST/Legal" "$DEST/AppIcon.icns"

# An empty asset catalog compiles to nothing, and actool then leaves its old output in the
# intermediates: DerivedData from before Issue242 keeps emplacing an Assets.car that still
# carries the official icon. The public catalog has no app icon (OfficialBuildTests), so an
# Assets.car with one is stale by definition. The stamp suffix makes Xcode re-seal after it.
HEALED=""
if [ -f "$DEST/Assets.car" ]; then
    CAR_INFO=$(/usr/bin/assetutil --info "$DEST/Assets.car") || {
        echo "error: cannot inspect $DEST/Assets.car"
        exit 1
    }
    if printf '%s\n' "$CAR_INFO" | grep -Eq '"AssetType" : "Icon Image"|"Name" : "AppIcon"'; then
        rm -f "$DEST/Assets.car"
        HEALED=" (removed stale Assets.car)"
        echo "Official Build Components: removed a stale Assets.car carrying the official icon"
    fi
fi

if [ ! -d "$ICONSET" ]; then
    echo "error: $ICONSET missing — cannot build the app icon"
    exit 1
fi
iconutil -c icns "$ICONSET" -o "$DEST/AppIcon.icns"

if [ "${FSNIPPET_OFFICIAL_BUILD:-NO}" != "YES" ]; then
    # Assigned on its own line so a failure is caught instead of writing a partial stamp.
    ICON_DIGEST=$(shasum -a 256 "$DEST/AppIcon.icns" | cut -c1-16)
    case "$ICON_DIGEST" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
        *) echo "error: could not hash the app icon ('$ICON_DIGEST')"; exit 1 ;;
    esac
    write_stamp "source icon $ICON_DIGEST$HEALED"
    echo "Official Build Components: source build — app icon only (no Official/, no Legal/)"
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
for item in "$OFFICIAL_SRC"/*; do
    [ "$item" = "$ICONSET" ] && continue
    cp -R "$item" "$DEST/Official/"
done
for f in $LEGAL_FILES; do
    cp "$REPO_ROOT/$f" "$DEST/Legal/$f"
done

# Assigned on its own line so a failure is caught instead of writing a partial stamp.
DIGEST=$(cd "$DEST" && find Official Legal AppIcon.icns -type f -print0 | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256 | shasum -a 256 | cut -c1-16)
case "$DIGEST" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
    *) echo "error: could not hash the bundled Official Build Components ('$DIGEST')"; exit 1 ;;
esac
write_stamp "official $DIGEST$HEALED"
echo "Official Build Components: bundled Official/, Legal/ and AppIcon.icns into $DEST"
