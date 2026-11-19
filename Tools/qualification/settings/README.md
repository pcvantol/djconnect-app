# Hosted settings and artwork qualification

Use the existing isolated XcodeGen settings-qualification overlay, actual signed
app identity and ordinary in-process credential store. Never export preferences,
bearer tokens, private URLs, text, pixels or raw Profile/Session identifiers.
This is a diagnostic target, never an ordinary app dependency or release bundle.

`testReadCurrentSharedSettings` reads the six authoritative fields and revision
fingerprints without changing settings. `testQualifyCurrentArtworkDelivery` reads
capabilities/owner context, up to20entries in one current/recent timeline and
prepares at most4existing media entries through the existing contract. It does
not create a Session, send a turn or a playback command. Run it only in an
explicitly authorized artwork qualification. It reports separate producer state,
grant admission, local ownership fence, pixel result and sanitized error category.
Unavailable media remains unavailable; no borrowed cover or source inference.

`testCurrentOutputUIFollowsActualPlayback` reads only `devices` and `status` through
the ordinary paired owner. It checks the active row and selected label against
the actual playback device, exports only counts/booleans, and never sends
`set_output`, starts music or moves the current audio.

A skipped unpaired context is NOT runtime acceptance. A passing diagnostic test
means the measurement finished, not that every reported image loaded. Inspect
`ARTWORK_QUALIFICATION`: actual40249had3readygrants/HTTP400;40250same probe had3/3
pixels loaded. One real dj_moment remained insufficient_identity. Visual viewport
loading requires a separate native UI check. Restore/reinstall the ordinary signed
app after hosted tests and verify no .xctest remains in that product.

The executed isolated overlay is retained at
/private/tmp/djc-settings3-native-source/settings-qualification.yml; ordinary
project generation uses project.yml. Private evidence stays under
/private/tmp/djc-settings-consolidation-private. Never put test captures in CI
artifacts or lane comments without an independent redaction check.


`testQualifyCurrentPassiveSurfaceRead` is a separate explicit diagnostic consent
for widget purpose in the current active Session. It reads bounded passive v1
content/artwork, revokes the diagnostic grant before assertions, and exports
counts/booleans only. The in-process model has background publication disabled:
no AppGroup, widget or ActivityKit update, Session start, provider preparation,
playback transfer or audio. It requires at least one genuinely qualified rich
field; neutral-only or skipped results are not positive native acceptance. It
does not exercise production pushes or locked-screen OS retention.


`testQualifyActualPairedRoutes` vergelijkt statusreads via de echte gekoppelde
interne/externe oorsprong. Alleen categorie, succes en duur worden gemeld; geen
URL/token/identiteit of uitvoerwijziging. De 40256-iPadproef bevestigde beide
routes en drie geldige artworkafbeeldingen. De gebruiker bevestigde dat lokaal
netwerk intussen was aangezet; de eerdere -1009 is geen blijvende weigering.

De 40256-settingscontrole is bewust FAILED gebleven: normaal model idle/niet
actief/geen history-owner, terwijl een afzonderlijke eigen settings3-GET HTTP200
met geldig schema opleverde. Dat onthulde de onjuiste startupafhankelijkheid van
conversationhistory. 40257 laadt settings op de eigen gekoppelde API-bevoegdheid;
een historyfingerprint is alleen afzonderlijk diagnosebewijs, geen productgate.
De extra foutdiagnose logt alleen schema-/contextbooleans en veilige veldpaden.
Mac-hosted teststart bleef hangen en is onderbroken; dit is geen PASS of SKIP.


`VoiceMenuStabilityProbe.swift` is an external UI-test runner against the already
installed ordinary `dev.djconnect.ios` app. It activates that app without launch
arguments, opens DJ-stem and holds each native picker open for12seconds. It samples
menu presence/hittability and unchanged editor height, captures private before/after
screenshots, then dismisses through the screen margin. It never selects a setting,
resets preferences, installs a diagnostic app dependency or transfers playback.
No active Session/provider/voice field means SKIP, never positive acceptance.

The isolated XcodeGen UI-test target has no dependency on DJConnectIOS. The executed
40276 runner is `/private/tmp/djc-voicepopover40276-ui-probe`, scheme VoiceMenuProbe,
with the real iPad destination. A physical-device test requires UI Automation to be
enabled. Keep runner results/screenshots private and verify the ordinary installed
bundle/version after the probe; an XCTest startup hang is not a passed menu test.
