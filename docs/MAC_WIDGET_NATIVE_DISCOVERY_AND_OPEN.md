# Native Mac widget discovery, opening and single Session widget

Owner screenshot shows a widget click opening iPhone Mirroring and reporting region unavailability. This placed widget follows the iPhone path. Two independent native Mac packaging failures were verified: pluginkit reports no dev.djconnect.mac.track-insight-widget, and the MacBook pkd log explicitly rejects the installed extension with "plug-ins must be sandboxed". The installed Mac app also lacks CFBundleURLTypes, so its declared djconnect://dj-session widget URL has no Mac registration.

Fix: a separate Mac widget entitlement file adds com.apple.security.app-sandbox=true and retains the existing DJConnect App Group. iOS signing is unchanged. The Mac app/project specification registers its existing djconnect URL scheme; the already-existing onOpenURL/handleAppNavigationDeepLink route opens the Session screen. No backend request/action semantics, personal data or sharing boundary is changed.

The new artifact validator checks the actual signed extension sandbox, platform, extension point, parent identifier, shared group/team and app URL scheme. The installed40442 artifact fails exactly the sandbox and URL scheme checks; other five checks pass. Rebuilt40444 passes all seven. Native pluginkit discovery and actual URL opening must be verified after installation; a successful build alone is not runtime acceptance.

The owner then explicitly requested only DJ-sessie in the gallery. Removed the four historical widget wrappers/registrations; only DJConnectSessionWidget is gallery-visible in small/medium/large. The separate iOS ActivityKit companion remains for Live Activity/Dynamic Island. Previously placed retired/iPhone widgets need replacement with the current native Session widget; no private desktop database rewrite, account-region change or global iPhone-widget setting change.

Mac preview40443 had previously been staged but both apps returned normal-quit user-cancel -128; it was not installed on the Macs. Their installed baseline was40442. The new combined Mac preview is40444 and includes the prior headphones-menu change.
