#!/bin/bash
set -euo pipefail

# Re-sign an already checksum-verified unsigned iOS bundle for one approved
# internal iPhone + paired Watch target. Profiles and private keys stay local.

if test "$#" -ne 4; then
  echo "usage: $0 <DJConnect.app> <signing-identity> <iphone-udid> <watch-udid>" >&2
  exit 64
fi

app_bundle="$1"
signing_identity="$2"
iphone_udid="$3"
watch_udid="$4"

test -d "$app_bundle"
security find-identity -v -p codesigning | grep -F -- "$signing_identity" >/dev/null

profiles=(
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
  "$HOME/Library/MobileDevice/Provisioning Profiles"
)
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

profile_for_bundle() {
  local bundle_identifier="$1" profile decoded app_identifier exact_match="" wildcard_match="" devices
  for directory in "${profiles[@]}"; do
    test -d "$directory" || continue
    while IFS= read -r -d '' profile; do
      decoded="$scratch/$(basename "$profile").plist"
      security cms -D -i "$profile" > "$decoded" 2>/dev/null || continue
      app_identifier="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$decoded" 2>/dev/null || true)"
      devices="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$decoded" 2>/dev/null || true)"
      printf '%s' "$devices" | grep -F -- "$iphone_udid" >/dev/null || continue
      printf '%s' "$devices" | grep -F -- "$watch_udid" >/dev/null || continue
      case "$app_identifier" in
        *".$bundle_identifier")
          test -z "$exact_match" || { echo "multiple exact profiles for $bundle_identifier" >&2; exit 1; }
          exact_match="$profile"
          ;;
        *'.*')
          case "$bundle_identifier" in
            ${app_identifier#*.})
              test -z "$wildcard_match" || { echo "multiple wildcard profiles for $bundle_identifier" >&2; exit 1; }
              wildcard_match="$profile"
              ;;
          esac
          ;;
      esac
    done < <(find "$directory" -maxdepth 1 -type f \( -name '*.mobileprovision' -o -name '*.provisionprofile' \) -print0)
  done
  test -n "$exact_match" && { printf '%s\n' "$exact_match"; return; }
  test -n "$wildcard_match" && { printf '%s\n' "$wildcard_match"; return; }
  echo "no development profile for $bundle_identifier covering the approved iPhone and Watch" >&2
  exit 1
}

sign_bundle() {
  local bundle="$1" identifier profile decoded entitlements
  identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Info.plist")"
  profile="$(profile_for_bundle "$identifier")"
  decoded="$scratch/${identifier}.profile.plist"
  entitlements="$scratch/${identifier}.entitlements.plist"
  security cms -D -i "$profile" > "$decoded"
  plutil -extract Entitlements xml1 -o "$entitlements" "$decoded"
  cp "$profile" "$bundle/embedded.mobileprovision"
  /usr/bin/codesign --force --sign "$signing_identity" --entitlements "$entitlements" --timestamp=none --generate-entitlement-der "$bundle"
}

find "$app_bundle" -name '._*' -type f -delete
xattr -cr "$app_bundle"
find "$app_bundle" -type d -name '*.framework' -print0 | while IFS= read -r -d '' framework; do
  /usr/bin/codesign --force --sign "$signing_identity" --timestamp=none "$framework"
done
find "$app_bundle" -type f -name '*.dylib' -print0 | while IFS= read -r -d '' library; do
  /usr/bin/codesign --force --sign "$signing_identity" --timestamp=none "$library"
done
find "$app_bundle" \( -name '*.app' -o -name '*.appex' \) -type d -depth -print0 | while IFS= read -r -d '' bundle; do
  sign_bundle "$bundle"
done
/usr/bin/codesign --verify --deep --strict "$app_bundle"
