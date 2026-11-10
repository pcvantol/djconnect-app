#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?Missing public release token}"
: "${RELEASE_VERSION:?Missing release version}"
: "${RELEASE_BUILD_NUMBER:?Missing build number}"
: "${CANDIDATE_SHA:?Missing source commit}"
: "${SIGNED_RELEASE_DIR:?Missing verified release package}"

# The ID stays stable when the release repository changes owner.
repo="$(gh api repositories/1265963920 --jq 'select(.id == 1265963920 and .visibility == "public") | .full_name')"
case "$repo" in
  pcvantol/djconnect-app-releases|djconnect-music-dj/djconnect-app-releases) ;;
  *) echo "Unexpected macOS release repository: $repo" >&2; exit 1 ;;
esac

tag="macos/v$RELEASE_VERSION"
zip="DJConnect-macOS-$RELEASE_VERSION.zip"
cd "$SIGNED_RELEASE_DIR/artifacts"
shasum -a 256 -c "$zip.sha256"

release="$(gh release view "$tag" --repo "$repo" --json assets,body,isDraft,name)"
jq -e '.isDraft == false' <<< "$release" >/dev/null
pending=()
for asset in "$zip.sha256" "$zip"; do
  local_digest="$(shasum -a 256 "$asset" | awk '{print $1}')"
  remote="$(jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .digest // "unknown"' <<< "$release")"
  if [[ -z "$remote" ]]; then
    pending+=("$asset")
  elif [[ "$remote" != "sha256:$local_digest" ]]; then
    echo "An asset named $asset already exists with a different or unknown digest." >&2
    exit 1
  fi
done
if [[ ${#pending[@]} -gt 0 ]]; then
  gh release upload "$tag" "${pending[@]}" --repo "$repo"
fi

release="$(gh release view "$tag" --repo "$repo" --json assets,body,name)"
for asset in "$zip" "$zip.sha256"; do
  local_digest="$(shasum -a 256 "$asset" | awk '{print $1}')"
  jq -e --arg name "$asset" --arg digest "sha256:$local_digest" \
    '.assets | any(.name == $name and .digest == $digest)' <<< "$release" >/dev/null
done
curl --fail --silent --show-error --location --retry 3 \
  "https://github.com/$repo/releases/download/$tag/$zip" \
  --output "$SIGNED_RELEASE_DIR/public-download.zip"
cmp "$zip" "$SIGNED_RELEASE_DIR/public-download.zip"

marker="<!-- djconnect-signed-macos-$RELEASE_BUILD_NUMBER -->"
if ! jq -e --arg marker "$marker" '(.body // "" | split("\n")) | index($marker) != null' <<< "$release" >/dev/null; then
  notes="$SIGNED_RELEASE_DIR/release-notes.md"
  {
    printf '%s\n\n' "$marker"
    printf '[Download DJConnect macOS %s](https://github.com/%s/releases/download/%s/%s)\n\n' "$RELEASE_VERSION" "$repo" "$tag" "$zip"
    printf 'Developer ID signed and notarized. Build %s from source `%s`.\n\n' "$RELEASE_BUILD_NUMBER" "$CANDIDATE_SHA"
    printf 'SHA-256: `%s`\n\n' "$(awk '{print $1}' "$zip.sha256")"
    printf 'Unsigned build details are retained below.\n\n'
    jq -r .body <<< "$release"
  } > "$notes"
  gh release edit "$tag" --repo "$repo" --title "DJConnect macOS $RELEASE_VERSION" --notes-file "$notes"
fi
