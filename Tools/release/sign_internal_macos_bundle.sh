#!/bin/bash
set -euo pipefail

test "$#" -eq 2
app_bundle="$1"
signing_identity="$2"
: "${MAC_APP_PROFILE:?Missing runner-local macOS app provisioning profile path}"
: "${MAC_WIDGET_PROFILE:?Missing runner-local macOS widget provisioning profile path}"
: "${MAC_MINI_PROVISIONING_UDID:?Missing Mac mini provisioning UDID}"
: "${MACBOOK_PROVISIONING_UDID:?Missing MacBook provisioning UDID}"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

sign_bundle() {
  local bundle="$1" profile="$2" requested="$3" expected_id="$4" identifier
  identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Contents/Info.plist")"
  test "$identifier" = "$expected_id"
  security cms -D -i "$profile" > "$scratch/profile.plist"
  /usr/bin/python3 Tools/release/macos_development_entitlements.py "$scratch/profile.plist" \
    "$requested" "$scratch/entitlements.plist" "$identifier" "$signing_identity" \
    "$MAC_MINI_PROVISIONING_UDID" "$MACBOOK_PROVISIONING_UDID"
  cp "$profile" "$bundle/Contents/embedded.provisionprofile"
  /usr/bin/codesign --force --sign "$signing_identity" --timestamp=none \
    --entitlements "$scratch/entitlements.plist" --generate-entitlement-der "$bundle"
  /usr/bin/codesign -d --entitlements - --xml "$bundle" > "$scratch/signed.plist"
  test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.aps-environment' "$scratch/signed.plist")" = development
}

find "$app_bundle" -depth -type d -name '*.framework' -print0 | while IFS= read -r -d '' framework; do
  /usr/bin/codesign --force --sign "$signing_identity" --timestamp=none "$framework"
done
sign_bundle "$app_bundle/Contents/PlugIns/TrackInsightWidget.appex" "$MAC_WIDGET_PROFILE" \
  Apps/DJConnectTrackInsightWidgets/DJConnectTrackInsightWidgetsMac.entitlements dev.djconnect.mac.track-insight-widget
sign_bundle "$app_bundle" "$MAC_APP_PROFILE" Apps/DJConnectMac/DJConnectMac.entitlements dev.djconnect.mac
/usr/bin/codesign --verify --deep --strict "$app_bundle"
