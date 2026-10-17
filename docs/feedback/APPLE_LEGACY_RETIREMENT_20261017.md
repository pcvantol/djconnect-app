# Apple: ongebruikte code verwijderd en open kwalificatie bijgewerkt

Owning lane: [Apple #87](https://github.com/pcvantol/djconnect-app/issues/87).
Bron: bestaande writer `codex/apple-dj-presence-v1`, HEAD `4fa9115` plus
behouden WIP. Dit document sluit de afgebakende verwijdering af; de volledige
settings-/Watch-/publieke-API-migratie en beschermde bronoplevering blijven open.

## Verwijderde code

De 28 concrete roots uit het eerdere assessment zijn verwijderd, samen met zes
helpers die daarna aantoonbaar geen caller meer hadden: in totaal 34 componenten.
Daarnaast zijn een commentaar-only toolbarbestand en de nooit gevulde
`webSocketSessionAuthProviders`-dictionary met haar twee clear-operaties verwijderd.
Geen pairingreset, voorkeurwijziging of backendwrite is hiervoor uitgevoerd.

| Bestand/groep | Verwijderde componenten |
|---|---|
| AppModel | `pairingWaitMessage`, `speakDemoResponse`, `messageForMusicDNARefreshFailure`, `combinedResponseLinks`, `appendAskDJStatusMessageIfNeeded`, `isRetryableHomeAssistantConnectionError`, `attemptWatchProxyPairingIfNeeded`, `clearWatchProxyRegistration`, `requestSpeechAccessIfAvailable`, transitief `pollWatchProxyPairing` |
| RootView | `localizedOutputName`, `localizedPairingStatus`, `PairingValueCard`, `rangeText`, `MusicDNATimelinePreview`, `TrackVibeVisualizerView`, `logLineNumber`, `logLineNumberWidth`, `SettingsRow`; transitief `TrackVibeCanvas` en `TrackVibePhaseSpectrum` met zijn extension |
| LaunchView | `DJConnectLaunchHeroVisual`, `DJConnectLaunchWaveform`, `DJConnectLaunchMixerLines`; transitief `DJConnectLaunchFeatureIcons`, `DJConnectLaunchRecord`, `DJConnectLaunchSignalRings` |
| WatchModel | `watchProxySendFailureCode`, `watchProxySendFailureMessage`, `redactedDeviceID` |
| Losse UI | `TrackInsightShareBackground`, `ActiveSessionAutoplayToolbar`, `SessionVoiceGenderSelector`, `SessionSpeechRecoveryNotice` |

De gebruikte `SessionVoiceAutoplayControl`, huidige glass-/vinylrenderer,
`startPendingWatchProxyPairingIfPossible`, `pairWatchProxy`, speech access en
actuele TTS/settings3/Watch-routes zijn behouden. Publieke package-API's,
OS-callbacks, widget-kindaliases en migratiereaders zijn niet automatisch gewist.
De oude publieke WS-issuer/provider is geen lege dictionary en blijft apart
contract-/consumerwerk.

De verse [retirementinventaris](APPLE_LEGACY_RETIREMENT_INVENTORY_20261017.json)
bevat 68 productie-Swiftbestanden en 41 conservatieve lexicale kandidaten.
Deze ronde begon op 71 bestanden/68 kandidaten. Geen resterende kandidaat
wordt op basis van alleen dat aantal als dode code aangemerkt. De oude
[assessmentinventaris](APPLE_DEAD_LEGACY_ROUTE_INVENTORY_20261017.json) blijft
een historische, inmiddels stale bronpin.

## Verificatie en installatie

- Volledige Swift-suite: **784 tests, 10 suites, PASS, 92.272s**, serieel.
  De eerste run op tussenbuild40281 vond een bestaande Watch-resourcecontrole
  die exact de oude YAML-volgorde eiste. Die controle zoekt nu het eigen target
  en verifieert nog steeds gedeelde resources én werkelijk gegenereerde PBX-
  resourcephases. Geen productresource of ownershipcheck verwijderd.
- Gewone signed iOS/iPadOS40282 inclusief Watch/widgets en macOS40282 PASS;
  bron/stage-identiteit voor 68 Swiftbestanden en vijf taalresources gecontroleerd.
  Gewone kopieën behouden bytes, modes en symlinks; strict/deep signatures PASS.
  Na de suite is uitsluitend een lege EOF-regel in de gebruikte autoplaycontrol
  genormaliseerd; beide native targets opnieuw groen en de definitieve kandidaten
  opnieuw bewaard. Geen functionele wijziging of tweede volledige-suiterun daaruit
  geclaimd. De CPU/geheugencollectie bindt aan de behouden40282-kandidaat vóór
  die opmaakcorrectie, niet aan de later opnieuw gelinkte bundlebytes.
- Gewone iPad40282 geïnstalleerd, geopend en onafhankelijk via appinventory
  teruggelezen. Tussenbuild40281 bevatte de eerste acht verwijderingen;
  40282 bevat de volledige ronde. iPhone40267/Mac40266 behouden volgens de
  alleen-iPadinstructie; Mac40282 alleen als kandidaat bewaard. Geen verse
  fysieke Watchacceptatie.
- Native staging behoudt het gewone systeemlaunchscreen; de afzonderlijke
  Base-lokalisatieproef is niet meegeleverd. Bronbestanden zijn vóór verwijdering
  privé bewaard. De eerste parseplanning miste inactieve platformtakken en
  verwijderde eerst alleen drie Watchhelpers; alle vervolgranges zijn vooraf
  gevalideerd. Alleen tijdelijke parsekopieën maakten conditionele takken
  zichtbaar; productievoorwaarden zijn niet aangepast. Alle echte targets
  zijn daarna succesvol gecompileerd.

Herhaalbare inventariscontrole:

```sh
python3 Tools/qualification/assess_dead_legacy_routes.py --check docs/feedback/APPLE_LEGACY_RETIREMENT_INVENTORY_20261017.json
python3 Tools/qualification/validate_apple_work_registers.py
python3 scripts/validate_localizations.py
```

Privé bewijs: `legacy40281-*`, `legacy40282-*` onder de bestaande qualificationmap,
inclusief voorbestanden, verwijderde spans, stagehashes, volledige tests, native
logs, gewone kandidaten en installatie-/versiereceipts. Geen nieuwe commit,
PR, merge of beschermde Finalization geclaimd.

## DJ-stem-menu: fysieke test blijft open

Een actieve gewone iPadsessie was nu beschikbaar. Op40280 faalden beide
menutests op native hit testing; expliciete landscape en een vers gestart
40281proces herhaalden dezelfde twee failures. De assertions zijn behouden;
dit zijn geen skips of positieve stabiliteitsresultaten. Het volledige fysieke
landscape-scherm is bekeken: de pop-out en uitgeklapte stemmenlijst staan
binnen het scherm. Een aanvankelijke offscreeninterpretatie op basis van de
gecropte appcapture is daarmee verworpen.

XCTest meldt ook een onbereikbare remote menu-accessibilityservice. Daarmee is
noch een productlayoutfout noch 12 seconden stabiele native menubediening tijdens
playback aangetoond. Geen voorkeur of playback gewijzigd; geen vierde identieke
hit-testpoging. De bronfix40276 en bijbehorende regressies blijven geldig, de
fysieke stabiliteitsacceptatie blijft PARTIAL. Probe gebruikt nu volledige
XCUIScreen-captures en bewaart/herstelt oriëntatie.

## Eerste gemeten CPU/geheugenreferentie

Instruments Activity Monitor kon de verbonden iPad niet in een recordingsessie
opnemen: timeout vóór opname; geen trace of meetclaim uit die poging.
Een afzonderlijke externe XCTest-probe op gewone40282 leverde wel daadwerkelijke
appmetingen: één warmup, drie opgenomen intervallen, actieve Session in foreground,
geen audio-/voorkeurcommando's. Collectiontest1PASS/0failures/0skips/23.457s.

| Metriek | Drie opgenomen waarden |
|---|---|
| Gemeten interval | 4.9222 / 4.9293 / 4.9240 s |
| CPU-tijd van de app | 0.1162 / 0.5572 / 0.1131 s |
| Piek fysiek geheugen | 58213.896 / 57099.784 / 56739.336 kB |
| Fysiek geheugen aan einde | 57099.784 / 56739.336 / 56542.728 kB |

Ruwe benoemde meetwaarden zonder toestelidentifiers staan in
[het gesaneerde meetbestand](APPLE_IDLE_PERFORMANCE_40282_20261017.json).
De tweede CPU-sample is hoger; de oorzaak is niet uit deze korte meting afgeleid.
Geen vergelijking met een oudere build, glaseffect uit/aan of oudere hardware;
geen p95-, energie-, heap/leak-, lange-sessie- of crashvrijclaim. Performance blijft
OPEN. De herbruikbare probe staat in
`Tools/qualification/settings/OrdinaryIdlePerformanceProbe.swift` en draait in
een afzonderlijk UI-testtarget tegen de al geïnstalleerde gewone app.

## Afhankelijkheden en veilige opruiming

Drie lokale branches en één worktree teruggelezen. De actieve writer en recoveryref
hebben geen bewezen merged/stale deletegrens; nul branches/worktrees verwijderd.
Geen actieve WIP, locks, herstelbron of gewone kandidaat gewist. Beide eigen tijdelijke
toestelrunners zijn na kwalificatie verwijderd; gewone40282 is opnieuw geopend
en onafhankelijk teruggelezen.

Verse lane-readback noemt Corepin `6a3adbc8e66ab380dfea1726ca34728097d0c684`
(bronPR1202/Finalization1203) voor VibeCast end-control retirement. Dat levert
geen nieuw preview-, lokale-stemoverride-, veilige-LAN- of verifiercontract.
Die bestaande afhankelijkheden blijven bij de benoemde producers. Ook twee-device
Profile-conflicten, echte Watchflow/audio, duurzame widget/LiveActivitypixels,
productie-APNs en beschermde Apple-bronoplevering zijn niet door deze opruimronde
afgemeld. Geen nieuwe Core-/HA-deploy of servercontractwijziging uitgevoerd.

[Apple87-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6237676625), [bestaande Core1101-afhankelijkheden](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6237677036); beide geplaatste bodies exact teruggelezen.
