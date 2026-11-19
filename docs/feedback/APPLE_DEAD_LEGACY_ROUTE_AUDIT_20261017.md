# Apple dead- en legacyroutes — assessment 17 oktober 2026

Historisch assessment vóór de latere bronwijzigingen. De 28 concrete roots en
zes transitieve helpers zijn inmiddels verwijderd in40281–40282; zie de
[actuele retirement en kwalificatie](APPLE_LEGACY_RETIREMENT_20261017.md).
Gebruik voor de huidige sourcehashcheck de nieuwe retirementinventaris. De oude
JSON-pin blijft bewaard en hoort nu STALE te melden; de oorspronkelijke
assessmentbevindingen hieronder zijn niet herschreven als runtimebewijs.

Owning lane: [Apple #87](https://github.com/pcvantol/djconnect-app/issues/87).
Bron: sole writer `codex/apple-dj-presence-v1`, HEAD
`4fa911527eb02fed8bed71397ee4c95fff2b2daa` plus behouden WIP. Dit is een
bronassessment, geen afgeronde verwijdering, beschermde bronoplevering of runtimekwalificatie.

## Uitkomst en bewijsgrens

70 productie-Swiftbestanden onderzocht in Sources/Apps, met verwijzingen uit
Tests en Swift-qualificationtools apart geteld. De herhaalbare lexicale scan
levert 68 kandidaten met één productie-tokenvermelding. Daarvan zijn 25 private
declaraties en drie interne, ongebruikte SwiftUI-views concrete opruimkandidaten.
De overige kandidaten zijn onder meer publieke API's, testseams en door het OS
aangeroepen protocolmethoden. **68 kandidaten betekent niet 68 bewezen dode routes.**

Aanroepketens zijn hieronder handmatig gevolgd. Tokenaantallen tellen ook
commentaar en strings; dat kan ongebruikte code verbergen. De scan is geen
Swift-callgraph, controleert geen externe packageconsumers en detecteert niet
automatisch alle transitief onbereikbare code. Een SwiftLint-analyse met de
bestaande incrementele Mac40274-buildlog rapporteerde nul geanalyseerde bestanden;
dat is **geen semantische PASS**. Er is hiervoor geen nieuwe native build of
toesteltest uitgevoerd. Alle 70 productiebronhashes zijn ongewijzigd sinds het
begin van dit assessment. Geïnstalleerde versies en bestaande blockers blijven intact.

## Prioriteiten en aanroepketens

| ID / prioriteit | Bevinding en concrete bron | Besluit / benodigde verificatie |
|---|---|---|
| L01 / P1 | **Watch heeft nog een actieve eigen TTS-fallback.** `DJConnectWatchModel.swift:3365` verstuurt `.voice`; `:3387` roept `playVoiceResponse` aan, `:3940` → `playResponseAudio` → `speakResponseFallback` (`:4055`). Bij ontbrekende of niet-mp3/wav audio spreekt AVSpeechSynthesizer de antwoordtekst uit met de OS-taalstem. Deze keten controleert zelf geen settings3-uitvoer/gekozen profielstem. | **REPLACE**, niet als dode code verwijderen. Integreer de profielgebonden speech-/uitvoeradmissie; geen stilzwijgende andere stem na mislukte serveraudio. Test text-only, client/HA/beide, gekozen stem, ontbrekende audio, ongeldige/verlopen bron, background/stop. Bronrisico bevestigd; geen nieuwe fysieke reproductie of claim dat Core iedere combinatie toestaat. Native device-TTS-override blijft een afzonderlijk geselecteerde, nog niet opgeleverde functie. |
| L02 / P1 | **Watch blijft oude Ask DJ/Profile-routes gebruiken.** Watch follow-up `:2659` stuurt `.askDJMessage`; iPhone-proxy `DJConnectAppModel.swift:12944`–`:12955` gebruikt rechtstreeks `askDJHistory`, `clearAskDJHistory`, `sendAskDJMessage`. Watch `musicDNAKey` (`:968`) is het device-ID en `djStyle` (`:964`) een vaste waarde. De gewone Apple-flow (`:7646`–`:7682`) kiest wél de Profile-conversationketen zodra `profileScopeActive` geldt. | **MIGRATE** met Core: bewijs of oude routes de huidige Watch-bearer volledig naar het juiste Profile binden; daarna dezelfde toegestane profielroute/DTO's gebruiken. Geen bewezen datalek, wel aantoonbaar verschillende consumerketens. Test twee Profiles, Watch vs companion-identiteit, wisselen/revocation, historie/clear en expliciete text-only. Niet ineens de oude API wissen zolang Watch deze aanroept. |
| L03 / P2 | **Oude voice-inventaris/-selectie staat naast settings3 zonder productie-entrypoint.** `setActiveVoiceMenuOpen` (`AppModel:6146`) heeft geen caller; de vlag begint false en wordt alleen gelezen. `selectActiveVoice` (`:6175`) en `selectActiveVoiceGender` (`:6186`) worden niet vanuit productie-UI aangeroepen. `refreshActiveVoiceOptions` is alleen direct door tests aangeroepen en via de niet te openen vlag. Actuele UI is `ProfileDJSettingsEditor.swift:13`–`:150`. | **REMOVE/MIGRATE** als één cluster: oude scope/state, menuvlag, selectie, `/speech/voices`-refresh en bijbehorende tests beoordelen. Verwijder niet de Core-route zolang andere consumers/externe APIcompatibiliteit die nodig hebben. Behoud tests voor stale-inventaris/authorityfences op de actuele settings3-controller. |
| L04 / P2 | **Een tweede speech-runtime is alleen door tests gebruikt.** `DJConnectSpeechPlaybackRuntime.swift:8` wordt buiten zijn definitie alleen in `SpeechPlaybackRuntimeTests.swift` geïnstantieerd. De echte Apple-flow gebruikt `AppModel.playSharedDJSpeech` (`:6007`) met `responsePlaybackCoordinator` en gedeelde producerafhandeling. | **REPLACE of RETIRE** na vergelijking van de werkelijk gebruikte lifecycle/expiry/stopfences. Groene tests van deze losse runtime bewijzen de app-flow niet. Behoud het gedeelde `DJConnectAudioPlaybackCoordinator`: die wordt werkelijk gebruikt. Publieke package-API eerst op externe consumers beoordelen. |
| L05 / P2 | **Oude VibeCast-feed/poller is geen huidige productieroute.** `runVibeCastPolling` (`AppModel:7374`) en `refreshVibeCastFeed` (`:7392`) hebben uitsluitend testcallers; `vibeCastResponse/items/disabledReason` worden alleen in het model beschreven, zonder rendererconsument. De huidige sessiestart-/handoffroute in RootView gebruikt deze poller niet. | **PARK/RETIRE** als oud feedcluster, inclusief modelstaat en demo-auto-insightguards; contract/publice API eerst inventariseren. Geen polling opnieuw aansluiten om tests tot featurebewijs te maken. Behoud de werkelijke VibeCast Session-/handoffroute en haar open contract-/toestelgates. `DJConnectVibeCastItem` (`Models:3496`) is bovendien een ongebruikte top-level DTO naast het wel gebruikte `DJConnectVibeCastResponse.Item`. |
| L06 / P2 | **Resten van de verwijderde passive-surfacepop-out blijven als publieke modelacties staan.** `preparePassiveSurfaceControls` (`AppModel:9217`) en `setPassiveSurface` (`:9222`) hebben geen productiecaller, maar staan nog in `Tools/qualification/settings/SettingsQualification.swift:276/:320`. Actuele automatische voorbereiding gebruikt `scheduleAutomaticPassiveSessionSurfaces` (`:9227`). | **REMOVE/MIGRATE** de oude UI-wrappers en qualificationflow samen. `PassiveSessionSurfaceModel.setEnabled`/grant lifecycle niet verwijderen: automatische reconciliatie gebruikt die nog. Vernieuw de qualificationtool naar automatische OS-configuratie/Session/settings3-toelating. |
| L07 / P2 | **De oude WebSocket-sessionissuer is losgeraakt.** `webSocketSessionAuthProviders` (`AppModel:1176`) wordt alleen geïnitialiseerd en geleegd (`:794/:1194`); niets vult of leest de cache. `DJConnectWebSocketSessionAuthProvider` heeft alleen testconstructies. `Client.webSocketSession` (`:217`) wordt uitsluitend door deze provider aangeroepen. | **REMOVE** lege cache; **DEPRECATE/RETIRE** publieke issuer/provider/DTO's na contract- en externeconsumercheck. Architectuur vermeldt al dat de automatische issuerdependency verwijderd is. Dit is niet de verklaring voor de actuele iPad-LANweigering. |
| L08 / P2 | **Drie legacy transportstappen blijven bereikbaar bij expliciete injectie.** `makeClient` (`AppModel:12234`) geeft zowel Hybrid als fastpath door; `Client.sendCommand` (`:84`) probeert de oude fastpath vóór HTTP/Hybrid. `DJConnectFastPathPolicy.makeFastPath` (`Transport:36`) vereist expliciete HA-credentials. Gewone appconstructies geven die niet mee; session-historyfixtures wel. | **KEEP gated / later RETIRE**, niet als momenteel dode code behandelen. Maak in tests en docs expliciet welke transportketen wordt gemeten. Geen automatische `/websocket/session`-issuer terugbrengen. Test dat gewone appconstructie geen oude HA-credentialroute opent en dat onzekere writes niet opnieuw uitgevoerd worden. |
| L09 / P2 | **Meerdere instellingenprotocollen blijven actief.** Mood/Persona/Presence kiezen settings3 bij `activeSharedSettingsRequired || profileDJSettings.negotiated`; anders bestaan oude session-writequeues. De nieuwe negotiated branch valt bij een settings3-fout niet terug naar een oude write. | **KEEP bounded / MIGRATE** met een expliciete minimale producercontractversie en cutovermatrix. Geen brede delete omdat oud heet. Bewijs no-fallback op 403/409/cancellation, twee Profiles, oude producer en Watch. De volledige settingsretirement blijft OPEN. |
| L10 / P3 | **Pairing-endpointvelden worden opgeslagen en gesynchroniseerd, maar sturen requests niet.** `apiBase/voicePath/statusPath/eventPath` (`AppModel:753`–`:756`) worden geladen/opgeslagen/gereset; Watch bewaart dezelfde velden (`:342`–`:345`). Client bouwt requestpaden met `apiV1Path`. | **REMOVE consumercache of documenteer compatibilitymetadata** na contractcontrole; geen omschakeling naar serveraangeleverde willekeurige URL's. Dit betreft endpointpaden, niet `haLocalURL/haRemoteURL`: die zijn actief en moeten blijven. |
| L11 / P3 | **Resten van oudere UI-generaties.** De 28 afzonderlijke declaraties staan hieronder. `ActiveSessionVoiceToolbar.swift` bevat daarnaast alleen een commentaarregel maar staat nog in het gegenereerde Xcodeproject. `demo.session.notice` heeft na de verwijderde demobanner alleen taalresources; recoverystrings horen bij de ongebruikte recoveryview. | **REMOVE** ongebruikte roots in kleine bouwbare batches, daarna pas transitieve helpers/assets/vertalingen op referenties controleren. Project uit `project.yml` regenereren; niet alleen PBX entries knippen. Behoud de gebruikte `SessionVoiceAutoplayControl`, huidige glasskeuzes en gedeelde vinylrenderer. |

## Directe opruimkandidaten zonder productie- of testcaller

Dit zijn 28 declaratie-roots, geen omvangclaim over alle transitief dode code.
Alle 25 private roots hebben één productie-tokenvermelding en nul testvermeldingen.
De drie interne View-types zijn evenmin aangeroepen en zijn geen app-entrypoint of
OS-protocolcallback. Definitieve verwijdering vereist targetcompilatie.

| Bestand | Declaraties met huidige regelnummers |
|---|---|
| `Sources/DJConnectUI/DJConnectAppModel.swift` | `pairingWaitMessage:5588`, `speakDemoResponse:7118`, `messageForMusicDNARefreshFailure:7773`, `combinedResponseLinks:9627`, `appendAskDJStatusMessageIfNeeded:10853`, `isRetryableHomeAssistantConnectionError:12446`, `attemptWatchProxyPairingIfNeeded:12619`, `clearWatchProxyRegistration:12822`, `requestSpeechAccessIfAvailable:13931` |
| `Sources/DJConnectUI/DJConnectRootView.swift` | `localizedOutputName:89`, `localizedPairingStatus:134`, `PairingValueCard:2757`, `rangeText:5098`, `MusicDNATimelinePreview:7204`, `TrackVibeVisualizerView:7983`, `logLineNumber:17873`, `logLineNumberWidth:17881`, `SettingsRow:18569` |
| `Sources/DJConnectUI/DJConnectLaunchView.swift` | `DJConnectLaunchHeroVisual:283`, `DJConnectLaunchWaveform:453`, `DJConnectLaunchMixerLines:475` |
| `Sources/DJConnectUI/TrackInsightShareViews.swift` | `TrackInsightShareBackground:751` |
| `Apps/DJConnectWatch/DJConnectWatchModel.swift` | `watchProxySendFailureCode:1228`, `watchProxySendFailureMessage:1239`, `redactedDeviceID:3006` |
| `Sources/DJConnectUI/SessionVoiceAutoplayControl.swift` | Alleen `ActiveSessionAutoplayToolbar:25`; **niet** de gebruikte `SessionVoiceAutoplayControl:6` |
| `Sources/DJConnectUI/SessionVoiceGenderSelector.swift` | `SessionVoiceGenderSelector:5`; vervangen door de actuele gedeelde glassselector in de settingseditor |
| `Sources/DJConnectUI/SessionSpeechRecoveryNotice.swift` | `SessionSpeechRecoveryNotice:7`; ongekoppelde presentatievoorbereiding, geen bewijs van werkende recovery-UI |

`attemptWatchProxyPairingIfNeeded` is een ongebruikte wrapper; de actuele
`startPendingWatchProxyPairingIfPossible` en `pairWatchProxy` hebben wél callers.
`clearWatchProxyRegistration` is een ongebruikte destructieve helper; dit assessment
voert hem niet uit en wist geen pairing- of profielgegevens.

## Bewust behouden / geen foutieve dead-codebevinding

- **OS-callbacks en entrypoints** zoals `@main` widgetbundles, WCSession delegate-
  callbacks, `metadataOutput`, `mtkView`, UIKit/AppKit delegates, `fileWrapper`
  en `dismantleNSView` worden niet via normale Swift-aanroeptekst gestart.
- **Widget-kindaliases** `DJConnectNowPlayingWidget`, Queue, TrackInsight en AskDJ
  verwijzen bewust naar dezelfde Session-configuratie (`Widgets:141`–`:150`).
  Verwijderen kan reeds geplaatste widgets raken. Oude LiveActivity-attributen
  worden gebruikt om bestaande activiteiten af te sluiten (`Controller:33`).
- **Legacy push-tokenmigratie** leest de oude devicegebonden sleutel en verwijdert
  haar pas na adoptie. Dit is hardwaremigratie, geen dubbele Profile-instelling.
- **`SessionMomentLayout`** (`Widgets:286`) heeft alleen DEBUG-previewcallers.
  Actuele rijke pixels komen van `PassiveSessionContentView`. Verplaats het
  prototype later naar een previewbestand of verwijder het met zijn previews;
  presenteer het niet als opgeleverde widget- of truncatiebug in productie.
- **Publieke package-API's** met alleen tests of nul repo-callers zijn kandidaten
  voor deprecatie, geen automatisch veilig te verwijderen interne code.
  Voorbeelden: `sendAskDJ`, typed `exportMusicDNA`, `sanitizedJSONString`,
  `retainedReceipt`, `retryTokenStorageAccess`, `rotatePairingTokenAndWait`,
  `startLikedProxy` en de speech-runtime.

## Uitvoervolgorde en acceptatie

1. Verwijder ongebruikte private UI/helpers en lege voice-toolbar in kleine
   batches; compileer iOS/macOS/watchOS/widgets en controleer relevante previews.
2. Ruim oude voice- en passive UI-entrypoints samen met hun test-/qualification-
   aanroepers op. Verplaats betekenisvolle stale-response/authoritytests naar de
   echte settings3-/automatische consumerketen.
3. Kwalificeer eerst Watch Profile/TTS-routing met de bestaande Core-writer.
   Maak daarna één actuele speech-/Profileketen; geen lokale productafwijking.
4. Retire oude VibeCast-feed, issuer en overige publieke API's op een benoemde
   consumer-/contractgrens. Behoud actieve Session-/Hybridfunctionaliteit.
5. Pas daarna aliases/migratiereaders/vertalingen opruimen met updatebewijs voor
   bestaande installs. Geen pairingtoken, pushregistratie of persoonlijke historie
   resetten om de code eenvoudiger te maken.

Dit assessment sluit de inventarisatie af. Verwijderingen, Profile-/Watchmigratie,
cross-target regressies, beschermde oplevering en fysieke acceptatie blijven open.
Geen nieuwe LAN-, crash-, geheugen-, pushproductie- of toestel-PASS afgeleid.

## Herhaalbare statische controle

```sh
python3 Tools/qualification/assess_dead_legacy_routes.py --check docs/feedback/APPLE_DEAD_LEGACY_ROUTE_INVENTORY_20261017.json
python3 Tools/qualification/validate_apple_work_registers.py
```

De [JSON-inventaris](APPLE_DEAD_LEGACY_ROUTE_INVENTORY_20261017.json) bewaart
alle kandidaten, test-/qualificationvermeldingen en exacte productiebronhashes.
De check faalt bij brondrift; vernieuw dan de inventaris en handmatige beoordeling.
Zij is geen functionele test en geen bewijs dat iedere kandidaat verwijderd kan worden.

Teruggekoppeld en exacte body teruggelezen: [Apple87](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6235354853), [bestaande Core1101-afhankelijkheid](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6235356708).

Statische sourcehash-/inventarischeck, negatieve stale-manifestcontrole en owning register-/Markdownvalidatie PASS; geen functionele of native regressie geclaimd.

Latere bronwijziging: de DJ-stem-pop-outfix40276 verandert drie onderzochte productiebronnen. De gepinde JSON is bewijs voor het assessmentmoment vóór die fix; de sourcehashcheck geeft daarna terecht STALE. De historische inventaris is niet herschreven om latere codewijzigingen als hetzelfde snapshot te presenteren.
