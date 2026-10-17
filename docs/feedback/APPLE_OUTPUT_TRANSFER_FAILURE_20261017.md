# iPhone output transfer failure — 2026-10-17

Owner reports server error/device not found, hangs and crashes while selecting
iPhone. Same Apple writer; ordinary installed baseline40250. Redacted actual
phone logs11:47–11:48 contain repeated set_output Spotify404 Device not found
and500 Server error, classified as backend_unavailable and applied globally.

## Apple fixes40252

- Send the exact stable output.id, never its possibly duplicated display name.
  Legacy string outputs already use name as their ID, preserving compatibility.
- Confirm the exact chosen ID. A same-name old phone cannot confirm a new phone;
  playback-device matching no longer falls back to names when stable IDs disagree.
- Deduplicate repeated stable IDs before SwiftUI ForEach, preferring a current
  live row over a cached duplicate. Empty IDs cannot become actionable rows.
- Failed target transfer/backend rejection preserves paired state, confirmed
  current output and independent backend availability. Localized action feedback
  uses existing five-language cached/output failure copy; auth/Profile/network
  failures retain ordinary authority recovery. Typed backend404 is not mistaken
  for a missing Home Assistant API route.
- A transfer write is not replayed on transport fallback. Duplicate same-target
  taps coalesce. An explicitly newer distinct choice may supersede it; late old
  confirmations cannot overwrite the newer generation. Failed confirmation read
  stops waiting rather than retrying every failed read.
- Watch companion transfer payload also uses output.id.

## Evidence and limits

First full737-test run failed5issues after overly strict serialization prevented
intentional newer choices and an old fixture still matched displayname A instead
of stableID a. Restored distinct-choice supersession, retained same-target
coalescing and updated that request fixture. Nine focused output/race tests PASS;
final complete **737tests/10suites PASS87.011s**. They cover explicit backend404/500/
HTTP200failure, preserved healthy controls/pairing, stableID payload, same-name
nonconfirmation, unique rowIDs, latest choice and no write replay.

Actual hosted iPhone40251 test after launching installed Spotify9.1.90 found one
unambiguous iPhone output, cached=false. One transfer attempt completed in3.893s:
pending=false, backendAvailable=true, paired=true, but chosenID was not confirmed
active. Test remains **FAILED** end-to-end. This proves Apple recovery behavior,
not a repaired Spotify/HA transfer or audible output. No blind repeat performed.

Core source finding forwarded to the existing writer: _select_spotify_device
falls back to active/first when an explicit configuredID is missing; set_output
then uses that fallbackID. Manual set_output also lacks the current_turn-only
restricted-target admission. These are concrete source risks; their causal role
in the exact actual attempt remains unproven. Core must fail closed for an
explicit missing/unavailable output and qualify the exact installed correction.
No second Core writer, direct Core edit or unqualified HA deployment.

Phone systemCrashLogs contain no DJConnect report at11:47–11:48. Latest is09:03,
build40213, EXC_BAD_ACCESS/SIGBUS in BSXPC connection-error handling; no app frame
in the triggered stack. Retained privately; no causal output-transfer or complete
crashfix claim. An unclean-shutdown diagnostic prompt is not itself a crash proof.

Ordinary signed40252 installation/readback and native build results follow below.

Final native iOS/macOS40252buildsPASS, strictdeepcodesignPASS; ordinaryapps contain
no .xctest. Ordinary40252installed on iPhone/iPad/Macmini, previous Mac40250 kept.
No successful real output-transfer/audio claim; existing Corewriter owns the
remaining targetselection/deploymentfix. Full source currentregression737PASS.

Lane readback: Apple#87/comment6232731160 and Core#1101/comment6232731328.
Ordinary40252apprelaunched on iPhone after restoring the no-testbundleproduct.


## Afzonderlijke UIrefreshcorrectie40253

Owner hoort playback al op MacBook maar ziet nog iPhone. Dit staat los van de
mislukte targettransfer. apply(playback) werkte de naam bij, maar niet activeflags
in availableOutputs. De refreshknop vroeg alleen devices op, niet huidige status.
Een vertraagd devicesantwoord kon bovendien een nieuwere playbackobservatie
terugdraaien. Currentplaybackreconciliatie zet nu exact de juiste row actief;
refresh leest devices+status zonder transfer en zonder globale refreshguard.
Een observatiecounter en bestaande selectie-generationfences beschermen late
inventaris; expliciete frisse targetconfirmaties behouden hun bestaande autoriteit.

Drie causale regressies toegevoegd (externe wissel/same-response stale flags,
refresh tijdens globale refresh zonder transfer, late inventory na nieuwere
playback).10gerichte tests PASS6.754s; volledige740tests/10suites PASS88.416s.
iOS/macOS40253builds en strictdeepcodesign PASS. Echte hosted signed iPhone40253
readonlytest PASS0.591s:9outputs,1active, selectedlabel/currentplaybackIDmatch.
Geen set_output, volume- of audiowijziging. Gewone40253app zonder testbundle
geïnstalleerd op iPhone/iPad/Macmini; voorgaande Mac40252 behouden. De eerste
Mackopie behield frameworkslinks niet en faalde strictcodesign; die eigen nieuwe
kopie is vervangen met behouden symlinks en opnieuw strictgeverifieerd. Er is geen
foutieve app gestart of oude recovery verwijderd.

Functionele UIrefreshcorrectie afgemeld. Core meldt lokale causale reparaties voor
missing/restrictedtargets en reject/uncertainfoutdispositie; die zijn nog niet als
exacte producerpin geïnstalleerd. Eerdere echte transfer blijft FAILED/open;
geen akoestisch of crashherstel afleiden uit deze uitleestest.


Label-only40254opvolging: exact contractconforme meervoudige uitvoerlabels in vijf
talen. Outputlogica gelijk aan gekwalificeerde40253. Gewone iOS/macOSbuilds en
strictsignaturesPASS; geïnstalleerd/readback op iPad/Macmini. iPhoneinstallatie
onderbroken, finaletoestelstatus unavailable; laatst bevestigde iPhoneversie40253. Lane
Apple87/comment6232847558 en Core1101/comment6232847699 leggen de afzonderlijke
UIafmelding en nog open daadwerkelijke transfer vast.
