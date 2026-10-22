# One Session home-screen quick action

The iOS/iPadOS application registers exactly one dynamic UIApplicationShortcutItem, dev.djconnect.action.dj-session, with the headphones symbol. Removed all static quick actions from project.yml and its generated Info.plist, so regeneration cannot restore the old menu. System-owned iOS menu items remain unchanged. Legacy deep links and action handling remain compatible, but are not advertised in the menu.

Title is localized in the app language: Start DJ session by default; Open DJ session only for a paired, authorized, non-demo active session outside recovery/unavailable state. Registration runs at app launch and updates on title and scene phase changes. Launch overwrites any old dynamic list. The system can retain the last registered title while the app is not running; opening the SpringBoard menu cannot fetch live server state. A fresh install has its action after first app launch.

Both titles navigate through the existing dj-session action to the Session page. An active session opens there; without one, the normal start screen retains its Profile choices, permission/connection guards and explicit Start button. The shortcut itself does not silently create a session or issue playback requests. Existing scene cold/warm entry routing is reused.

Validation: source diff and plist/localization/register checks only. No build, Swift test execution, simulator/device launch, installation or runtime acceptance under the explicit-build-only instruction. Pending next authorized build: verify single action after upgrade, cold/warm navigation, label after session start/end, recovery/unpair/demo and language changes. Last installed40447 unchanged; source in PR179, no merge.
