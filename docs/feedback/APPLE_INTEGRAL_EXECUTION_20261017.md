# Integrale Apple-uitvoering — 17 oktober 2026

Directe owneropdracht: integraal het gevonden open werk oppakken en vervolgens
alle bestaande Applebron naar main consolideren. De bestaande writer/WIP is
behouden en opgenomen via PR111; onderstaande buildsecties zijn historische
bewijsleveringen. Actuele source- en Finalizationstatus staan in de eerste sectie;
volledige productacceptatie blijft afzonderlijk.
[Requirementregister](APPLE_REQUIREMENT_ACCEPTANCE_20261017.md) en
[open werk](APPLE_OPEN_WORK_20261017.md) zijn de actuele owning overzichten.

## Mainconsolidatie — 17 oktober 2026

[Bron-PR111](https://github.com/pcvantol/djconnect-app/pull/111) is beschermd
gemerged als `b47d17a3bd7aade005787206785578bee585096b`; kandidaat
`0688cf6529358ba72660cb5c0da28d296df84463` heeft exact dezelfde tree
`422cf1173bc48e660931b0a5beb5f4264a03b973`. Alle premergechecks en officiële
Owner Authorization PASS. Nieuwe portable784tests/10suites PASS89.368s; native
784tests/10suites PASS82.596s; unsigned iOS/macOS inclusief Watch/widgets PASS.
Drie CI-testcorrecties veranderen geen appgedrag en behouden alle assertions.

Beide oorspronkelijke checkouts staan schoon op dit main. Hun18/155WIPpaden
zijn behouden in stashes en onafhankelijk hashgecontroleerde herstelarchieven;
Gitbundles bewaren alle oorspronkelijke refs. Drie exact bewezen oude lokale
branches zijn verwijderd, nul worktrees. Remote heeft alleen main. Het
ongeïnstalleerde Base-launchscreenexperiment en twee dubbele Xcodeprojecten
blijven herstelbaar buiten de merge. Gewone iPad40282/iPhone40267/Mac40266
blijven ongewijzigd; geen nieuwe installatie, HA-deployment of distributie.

Main CI39061192756 inclusief native coverage PASS. Coverage- en runnerartefacten
zijn onafhankelijk gehasht; coverage noemt exact bron-mainb47d17a3. Formele
reconciliatie39061762379 FAILED vóór publicatie door een concrete centrale
producerfout: de ongepagineerde commitread levert300 van369bestanden. Alle
369bestanden komen bij volledige gepagineerde GitHub- en lokale Gitreadbacks
exact overeen. De bestaande Core-writer heeft de collectorcorrectie ontvangen;
geen status of bewijs wordt omzeild. Aparte documentaire Finalization blijft
pending totdat de juiste exact-main evidence is gelezen. De poging deze run te
stoppen was te laat; de duurzame builder had het niet-gekwalificeerde rapport
al terecht geweigerd. Er is geen ongeldig rapport gepubliceerd.

TDE-observeworkflow PASS, maar de analyse zelf FAIL/repositoryqualification
FAILED met3CRITICAL/174HIGHcomplexiteitsbevindingen. Deze blijven open voor
triage/refactor; geen baseline-regressie- of runtime/crashconclusie. Nieuwe
onafhankelijke volledige technische/UXreview op deze gehele kandidaat is niet
uitgevoerd. De23actieve functionele/acceptatiepunten blijven open; bounded
source-inclusie sluit geen LAN/WS, TTS, Profile, VibeCast, OS-surfaces, Watch,
productiepush, performance of fysieke acceptatie af.

Zie [bronconsolidatie](APPLE_MAIN_CONSOLIDATION_20261017.md) en
[exacte bronreadback](../verification/apple-main-consolidation/source-main-readback.json).

## Opruiming40282 — 34 ongebruikte componenten verwijderd

Alle 28 concrete roots uit het legacyassessment plus zes transitieve helpers zijn
verwijderd, naast een leeg toolbarbestand en nooit gevulde WS-cache. Actieve
TTS/settings3/Watch/pairing en publieke API/migraties blijven behouden. Volledige
784 Swift-tests in tien suites PASS (92.272s); signed iOS/macOS inclusief
Watch/widgets, source/stage, ordinary copy en signatures PASS. Gewone iPad40282
geïnstalleerd en onafhankelijk teruggelezen; iPhone40267/Mac40266 behouden,
Mac40282 alleen kandidaat. Eén worktree/drie branches zonder bewezen veilig
merged/stale kandidaat: nul deleties.

Eerste echte fysieke idlecollectie40282: drie samples, circa 57–58 MB piekgeheugen
en 0.113–0.557 CPU-seconden per circa 4.93s. Geen performancewinst-, p95-, soak-
of crashvrijclaim. DJ-stem-menutests blijven twee failures per run, ook bij
landscape en vers proces. Volledige capture toont pop-out binnen beeld; remote
AX/hit-testprobleem nog te onderscheiden van echte refreshdismissal. Geen
fysieke twaalfsecondenstabiliteitclaim. Zie [retirement en bewijsgrenzen](APPLE_LEGACY_RETIREMENT_20261017.md).

## iPadmoodranden40280 — gewone fysieke viewports bevestigd

De buitenste root achter UIKit en de Sessionwrapper volgen de bevestigde mood.
Statusbalk en onderste systeemrand kleuren door; Meer/geenactieveSession gebruiken
de gewone canvas. Nativebuild/signatures/source-stage/copyPASS; iPad40280install
vóór/na onafhankelijk teruggelezen. Externe screenshotprobe1PASS15.959s; volledige
EnergieSessionbeelden liggend/staand én Meer bekeken: groene randen, correcte
merkcanvas na tabwissel. Geen mood-/backend-/playbackactie; oriëntatie hersteld,
eigen runner verwijderd. De viewports bevestigen ook vinyl-in-kaart en TTSknop
rechtsonder; geen audio-/downloade2e.2bestaande renderchecks6gevallenPASS0.040s.
Zie [oorzaak en echte bewijsgrenzen](APPLE_IPAD_SESSION_MOOD_EDGES_20261017.md).

## Afspeelknop40279 — rechtsonder, gelijke rechter-/ondermarge

Contextvraagruimte reserveert alleen inhoud; de speechfooter gebruikt de volle
breedte. DJ-conversatiepadding14pt rechts/onder; gedeelde rij bottomaligned zodat
statusregels de knop niet omhoog duwen.4bubblelayout-renders met geïnjecteerde
44ptfooterPASS, twee bestaande rendertests/6gevallenPASS0.041s. Gewone signed
native iOS/macOSincl.Watch/widgets/source-stage/copy/signaturesPASS; iPad40279
geïnstalleerd/teruggelezen. Geen nieuwe fysieke audio-/screenshotacceptatie.
Zie [oorzaak/fix/bewijsgrens](APPLE_SPEECH_BUTTON_CORNER_20261017.md).

## Vinylkaart40278 — dezelfde album-artvorm met en zonder hoes

De glass-kaart zat alleen rond geladen pixels. Nu deelt de vinyl-/laad-/foutfallback
hetzelfde albumframe, met gelijke maat, inset8, afgeronde hoeken en rand. De
Glaseffectenpolicy blijft leidend; geen extra tintdownload zonder geladen hoes.
2bestaande rendertests/6gevallenPASS0.041s; handmatige vierkante renders op3maten
PASS en358ptPNGbekeken. Gewone signed iOS/macOSincl.Watch/widgets en bron/stage/
copy/signaturesPASS. GewoneiPad40278install/versiereadbackPASS; iPhone40267 en
Mac40266behouden. Geen nieuwe fysieke artworkpixelclaim of volledige UIclosure.
Zie [fix en bewijs](APPLE_VINYL_ALBUM_CARD_20261017.md).

## Glaseffecten40277 — gewone iPadinstall en toggle/persistentie bevestigd

Eén apparaatgebonden schakelaar onder Instellingen → App vervangt app-eigen
glass/materials door dekkende vlakken, direct en zonder herstart. De keuze is
lokaal; systeem Verminder transparantie blijft leidend.1257localechecksPASS,
2render-/vinyltests met6gevallenPASS0.058s; gewone signed iOS/macOS inclusief
Watch/widgets en source/stage/copy/signaturesPASS. GewoneiPad40277install en
onafhankelijke versieteruglezingPASS. Externe UItestPASS33.872s controleert
omschakelen, gewoneherstart, persistentie en herstel oorspronkelijke waarde;
eigen runner opgeruimd. Private screenshots tonen dekkende kaarten, maar zijn
rechts afgesneden: geen complete layoutacceptatie. iPhone40267/Mac40266behouden.
Geen gemeten oudere-deviceperformancewinst; algemene profiling blijftopen.
Zie [ontwerp en bewijsgrenzen](APPLE_GLASS_EFFECTS_PREFERENCE_20261017.md).

## DJ-stem-pop-out40276 — gewone iPadinstall bevestigd, menuacceptatie open

[Flikkerfix](APPLE_VOICE_POPOVER_STABILITY_20261017.md): editor luistert alleen naar betekenisvolle settingspresentatie, geen algemene playbackticks of klok/receipt-only updates. FreshnessGET blokkeert geen expliciete keuze; late snapshot/401 wordt gefenced, tweede write wacht op actuele mutatiereadback.25gerichte testsPASS0.201s en36gerelateerde settings/Watch/autoplaytestsPASS0.253s. Gewone signed iOS/macOS inclusiefWatch/widgets en source/stage/ordinarycopy/signaturesPASS. Eerste actorcompilefout en parallelle transferbudgetfailures behouden, hersteld/serieel groen. Geen nieuwe fysieke UIclaim: iPad disconnected, owner omUSB/ontgrendeling gevraagd; iPhone unavailable en alleen-iPadupdate behouden. Mac niet geforceerd gesloten. Base-launchscreenproef blijft afzonderlijk; kandidaat behoudt geïnstalleerde40272systeemlaunchlayout.

Owner sloot iPad aan: gewone40276install en onafhankelijke versieteruglezingPASS. Eerste UIAutomation-starttimeout behouden; na ownerbevestiging draait XCTest. Beide menutestsSKIP: werkelijk StartDJ-sessiescherm/noactiveSessionmenu, private diagnostische screenshot bekeken. Geen Session/voorkeur/playback gewijzigd. Tijdelijke runner opgeruimd; iPhone/Mac behouden. Echte open-menustabiliteit blijft open.

## Dead- en legacyroutes — verse bronassessment

[Assessment](APPLE_DEAD_LEGACY_ROUTE_AUDIT_20261017.md) onderzoekt70Swiftproductiebestanden.68lexicale kandidaten zijn onderscheiden van28concrete ongebruikte declaratie-roots, SDKcallbacks, publieke API, previewprototypes en noodzakelijke migratiealiases.11bevindingclusters leggen actieve Watch-TTS/Profileverschillen, test-only SpeechRuntime/VibeCast-feed, oude voice/passiveentrypoints, losse WSissuer en endpointmetadata vast met uitvoervolgorde. Reproduceerbare JSONinventaris met exacte70bronhashes; productiecode ongewijzigd. Geen runtime-/native-/LANclaim, geen verwijdering of parentretirementclosure. SwiftLint met bestaande incrementele log analyseerde0bestanden: geen semantische PASS.

## Verse iPad-LAN-read — actueel internadres, server weigert lokale route

Verse17oktread: gewoneiPad40272 bewaart internhttp://192.168.1.134:8123 en externvictory-curvy-refold.ngrok-free.dev. Zelfde installatie als draaiendeHA-dev; huidigeconfiguration.yaml bevat hetzelfde interneadres. HA-dev177/177integratieblobhashes gelijk aan Coremain0adaef7d5acd9cbe84b97d2f684c6f2e705dc27c. Credentialvrije lokale transport/context geeft426/transport_security_required; direct-local-ingressqualificationbestand ontbreekt. InterneURLsync is in deze observatie correct; veilige lokale ingress/pairedWS blijft open, geen herstel door cosmetische moduswijziging of nieuwepairing.

Bestaande Core-/operatorlane moet een werkelijk gekwalificeerde LAN-ingang leveren (vertrouwde lokaleTLS of bewezen direct-local-ingress volgens huidige policy), gevolgd door echteiPad-/WiFi-/resume-/WS/fallbackacceptatie. Geen fabricage van qualificationrecord, lease/TLSdowngrade of client-tokenreset. Native route blijft extern zolang lokaal niet toegelaten wordt.

[Exacte bewijsgrens](APPLE_WIFI_LOCAL_ROUTE_20261017.md). Geen nieuwe nativebuild
of liveLAN/WS-PASS. Macpairing40274installblocker en launchscreenownerkeuze blijven
onafhankelijk behouden.

## Mac-pairingfollowup40274 — bron/build klaar, installatie geblokkeerd

62gerichte testsPASS29.493s en signed gewone nativeMac/signatures/sourcehashesPASS.
Completion volgt acceptedtoken/installatie/config/operation, onafhankelijk van
history-epoch. Alleen statusreads worden na tijdelijke cancellation herhaald;
geen tweede pairPOST. Oude taken/tokenwissel mogen niet afronden of nieuwe
pendingstaat wissen. UI lekt geen Swift-exceptie meer. Echte lokale log toont
acceptedpair→CancellationError; screenshot-host en herstelde livepairing nog open.
Macmini40266 weigert normalequit(-128) en blijft draaien;40274 niet geïnstalleerd.
MacBooknaam niet bereikbaar; owner gevraagd welke Mac en volledig afsluiten nodig.
Zie [pairingfout/acceptatiegrens](APPLE_MAC_PAIRING_CANCELLATION_20261017.md).

## Automatische surfaces40268–40272 — 17 oktober 2026

De extra pop-out/twee toggles zijn weg. Bevestigde actieve Session/settings3 en
OS-widgetplaatsing/Live Activity-toestemming sturen automatisch onafhankelijke
grants. Historysuspension, settings-first startup, exacte Activityinstancefence
en onafhankelijke neutrale/veldexpiry zijn hersteld; geen onzeker-write-replay,
nieuwe poller of bronleaseverlenging.

26gerichte testsPASS2.533s; signed gewone iOS/macOS40272 inclusiefWatch/widgets,
strictdeep signatures en bron/stagehashesPASS. GewoneiPad40272 geïnstalleerd en
teruggelezen; SDK active/count1, twee gewone reads zonder daarna app-einde,
actuele neutralcache/widgetmuziek. De huidige LiveActivityrichcache ontbreekt,
0art/pixels; eerdere40269/40271 hadden beide richstores met muziek/bijdrage.
Geen fysieke OS-pixel- of duurzame background-PASS. Vier tijdelijke SDK-
authorizationfouten tijdens startup vóór de geaccepteerde start zijn behouden.

Owner kiest nu alleeniPad: iPhone40267 behouden, Mac40266draait/ordinary40272gereed,
Watchalleenmeegebouwd. Owning Corebeleid/SYNC/verse rijke bron/achtergrondlevering
blijft afhankelijkheid: v1 explicit_consent_required=true, background_delivery=false,
max120s. Consumerimplementatie bounded afgemeld; parentpassive blijftPARTIAL.
Zie [ontwerp/bewijs](APPLE_PASSIVE_AUTOMATIC_SURFACES_20261017.md) en
[integrale uitvoering](APPLE_INTEGRAL_EXECUTION_20261017.md).

De gewone40270log legde SDK-start→direct app-einde bloot. De Session-read kwam
vóór settings3; latere bindingadoptie trok de presentatie in. App.end kan dismissed
opleveren; de exacte instancefence voorkomt een onterechte gebruikersmarker of
blokkade van een vervanging.40272 herstelt daarnaast de neutrale Session tot haar
oorspronkelijke observedAt+120s wanneer kortere richvelden verlopen. Regressie
controleert vervallen bijdrage/actuele muziek en uiteindelijke neutralexpiry.

Historisch:40267readonly3widgets/groep/toestemming/actieveSession maar lege
stores/Activity;40268 automatische muziek;40269/40271 beide richstores met
bijdrage/muziek. Eerdere25/24/23gerichte runs en twee readonlyXCTestmetingen
blijven bewaard. Geen nieuwe volledige762suiteclaim: die hoort bij40258.
0Widgetcrashrapporten is metadata, geen algemene crash-/geheugenkwalificatie.
De oorspronkelijke40270Swift6compilefout is bewaard; preconcurrencySDKinterop
is begrensd tot ActivityKit/MainActor-bookkeeping met seriële lifecycle.

Privé:passive40272-source.json, targeted/nativebuildlogs/ordinaryreceipts,
iPadinstall/apps/shared-read/runtime plus gesaneerde eerste en laatste read.

## UI-followup40267 — demo-tekstregel verwijderd

De volledige demo-/luistergeschiedenisregel is uit alle drie UI-locaties
verwijderd: actieve Sessionheader, readonly sessiegeschiedenis en idle startscherm.
De rij en bijbehorende padding vervallen; geen lege placeholder. Dit werkt
gedeeld op iPhone/iPad/Mac en voor alle talen. Bestaande demo-UI-testassertie
is aangepast naar afwezigheid van session-demo-notice; niet opnieuw fysiek
uitgevoerd. 1255 lokalisatiesleutels en gewone signed iOS/macOS40267-builds,
strict signatures en diffcheck PASS. Geen nieuwe volledige regressieclaim.

Gewone40267 op iPhone/iPad geïnstalleerd en teruggelezen. Op macmini-m6
blijft40266 draaien: normale afsluiting gaf -128/cancelled. Eigenaar gevraagd
om volledig af te sluiten; proces bleef aanwezig bij de laatste read. Gewone
40267 staat gecontroleerd klaar; geen geforceerde beëindiging/vervanging.

Privé: demo-notice40267-source.json, nativebuildlogs/receipts en
ordinary-install/readbacks. Overige acceptatie blijft afzonderlijk open.

[Apple87 demo-tekst-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6234389101), exacte body teruggelezen.

## UI-followup40266 — gedeelde demo-vinylplaat

De demo heeft bewust geen hoes-URL. De oude Mac40258 op het screenshot liet
daarom het hele Sessionhoesvlak weg; de fallback uit40263 stond nog niet op
de Mac. Demo gebruikt nu expliciet de bestaande vinylplaat bij Speelt Nu,
Session en Track Insight. De renderer is uit RootView gehaald naar één SwiftUI-
bronbestand, gedeeld met watchOS. De Watch-demo gebruikt dezelfde plaat voor
de speler-miniatuur, grote hoespreview en Track Insight. Geen netwerkhoes of
nieuwe artasset; de live contract-/grantafhandeling blijft behouden.

De renderer reserveert zelf een vierkant bij een breedtevoorstel zonder hoogte.
Rotatie volgt de afspeelstatus en stopt bij een inactieve scene of Reduce Motion.
De nieuwe renderregressie PASS op54/190/270/358pt:4gevallen,0.025s. Een eerste
testcompile probeerde de alleen-lezen ReduceMotion-environmentwaarde te zetten;
gecorrigeerd naar gepauzeerde playback voor een deterministische layoutrender.
Die failurelog is behouden. De270ptrender is visueel bekeken en toont de
bestaande vinylplaat met vaste toonarm. Native gewone signed iOS/macOS40266,
inclusief de ingesloten Watchapp, en strictdeep-signatures PASS.

Mac kon nu normaal worden afgesloten. De gecontroleerde installer bewaart40258
als herstelkopie en plaatste gewone40266; signature en exact byte/mode/symlink-
manifest teruggelezen, gewone app heropend. De computer-use tool crashte bij
twee pogingen vóór UI-uitlezing; geen fysieke Macpixels of animatie-E2E geclaimd.
Gewone40266 ook op iPhone/iPad geïnstalleerd en teruggelezen.
Watchhardware is niet opnieuw gekwalificeerd. De volledige762regressies blijven
40258bewijs; dit is geen protectedsource/Finalization of parentclosure.

Privé: vinyl40266-source.json, targeted-tests[-initial-compile-failure].log,
nativebuildlogs/receipts, render-54/190/270/358.png en ordinary-install/readbacks.

[Apple87 demo-vinyl-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6234317159), exacte body teruggelezen.

## UI-followup40265 — actieve Bluetoothnaam en iPhone-installatie

De werkelijke iOS-Bluetoothroutenaam vervangt uitsluitend het weergavelabel van
de matching actieve lokale telefoon/tablet in Speelt Nu, de sessieheader en de
uitvoerlijst. Eén model-observer verwerkt routewijzigingen en hervatten. De
backendnaam en het command-ID blijven intact; geen Profile-opslag, routecommando,
audioactivatie of verliesvrij-claim. Een andere/cached uitvoer, onduidelijke
routenaam of bekende conflicterende lokale apparaten krijgen geen geleende naam.

7 gerichte tests PASS (0.484s), met aansluiten/ontkoppelen/nieuwe koptelefoon,
zes negatieve uitvoergevallen en onduidelijke routes. Gewone signed native
iOS/macOS-builds 40265 en strict deep signatures PASS. De aangesloten iPhone
kon opnieuw worden geïnstalleerd; gewone 40265 op iPhone en iPad teruggelezen.
Mac mini blijft 40258 na het eerder geannuleerde appafsluiten; gewone 40265 gereed.

De eerste alleen-lezen hardwarecontrole zag een AVR zonder Bluetoothroute en
werd overgeslagen. Tijdens de door gebruiker uitgevoerde omschakeling volgden
twee SKIPs (iPhone zonder Bluetooth, daarna Bluetooth met tijdelijk ontbrekende
playbackidentiteit). De uiteindelijke controle met actieve AirPods PASS (1.144s):
één genoemde Bluetoothroute, huidige Smartphone matching lokale naam, één
actieve inventarisrij en beide labels gelijk aan de echte routenaam. De
kwalificatie heeft een begrensd read-only convergentievenster; de geslaagde
meting had geen extra read nodig. Geen namen, apparaat-ID's of credentials in
het rapport; geen transfer/volumecommando of fysieke screenshotclaim.

Na XCTest zijn het gewone project en het oorspronkelijke signed appproduct
hersteld; byte-/mode-/symlinkmanifest gelijk, geen xctest-bundle. Gewone app op
iPhone opnieuw geïnstalleerd en op beide apparaten teruggelezen. Alle eerdere
UI-fixes, inclusief hoes en opslagtoast, zitten daarmee ook op de iPhone;
echte Endtoast en visuele acceptatie blijven afzonderlijk open.

Privé: bluetooth40265-source.json, targeted-tests/buildlogs/receipts,
iphone-route[-positive/-settled/-bounded].log/xcresult, ordinary-restore.json
en ordinary-install/readbacks. De volledige 762 tests blijven 40258-bewijs.

[Apple87 Bluetooth-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6234211899), exacte body teruggelezen.

## UI-followup40264 — adreslabel

Actief is verwijderd uit het verbindingsadreslabel: Home Assistant-adres.
Dezelfde aanpassing in alle5talen;1255keys/localisatievalidator en werkelijke
meegebouwde localevalues in iOS/macOSproductenPASS. Gewone signed nativebuilds,
strictdeep-signatures en iPadinstall/readback40264PASS. Mac mini40258/40264gereed;
iPhone unavailable. Geen nieuwe runtime-/volledige testclaim.
Privé: address40264-source.json, buildlogs/receipts en iPadinstall/readback.
[Apple87 UI-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6234015482), exacte body teruggelezen.

## UI-followup40263 — iPhonehoes, vinylfallback en opslagtoast

De Sessionhoes volgt op iPhone de volledige contentbreedte, zonder270pt-cap;
de bestaande iPad/Mackolombreedte blijft behouden. Gedeelde CachedArtworkImage
en SpeeltNu-AlbumArtworkPlaceholder vervangen AsyncImage/muzieknootje en tonen
vinyl bij geenURL, laden, decode-/netwerkfout. Dezelfde cache/inflight/retry,
originele aspectratio en glassinset; animatie pauzeert bij playback/scene/reduceMotion.
Geen geleende cover voor credentialed bijdrageart of gewijzigde backendrechten.

Na één bevestigde End volgt een pure begrensde archiveGET. Alleen matching
readonly ENDED met geldige serverbegin/eindtijd levert de gelokaliseerde toast:
Sessie '<datum + duur>' opgeslagen onder Eerdere sessies. Geen afgeleide eindtijd
of End-replay. Contextwisseling vóór/na de read trekt de toast in; de bevestigde
afsluiting zelf blijft geldig en de laadstatus wacht niet op die optionele read.
Demo gebruikt hetzelfde bevestigde archiefmodel. Negatieve testgevallen bewijzen
geen succesmelding bij mislukte End, ontbrekend archief of gewijzigde context.

8gerichte testsPASS0.796s, inclusief5taalgevallen en4End/archive/contextuitkomsten;
1255lokalisatiesleutels in5talenPASS. Gewone signed native iOS/macOS40263-builds
en strictdeep-signaturesPASS; iPadinstall/readback40263PASS. Mac mini blijft40258
na eerder geannuleerd appafsluiten, gewone40263 gereed; iPhone unavailable.
Gebruiker gevraagd om USB/ontgrendeling; fysieke iPhonebreedte en echte Endtoast
zijn niet geclaimd.762volledige regressies blijven het40258bewijs.
Privé: hero-toast40263-source.json, targeted-tests.log, native buildlogs/receipts
en iPadinstall/readback;40262tussenkwalificatie behouden.
[Apple87 UI-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6233979895), exacte body teruggelezen.

## UI-followup40261 — bronlabels zonder opnametype

Het lokale brontypelabel Opname/Eerdere opname is verwijderd uit bronlinks in
MomentCard en historybijdragen. Alle providers, inclusief MusicBrainz en Spotify,
tonen alleen de providernaam; oorspronkelijke URLs en attributie blijven behouden.
Dit werkt in alle5talen zonder nieuwe strings. Gewone signed iOS/macOS-builds
en strictdeep-signaturesPASS; iPadinstall/readback40261PASS. Mac mini blijft40258
na eerder geannuleerd appafsluiten; gewone40261 staat gecontroleerd klaar.
iPhone unavailable. Geen verse fysieke screenshot- of volledige testclaim.
Privé: sourcelabel40261-source.json, native buildlogs/receipts en iPadreadback.
[Apple87 UI-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6233846482), exacte body teruggelezen.

## UI-followup40260 — compacte verbindingsnavigatie

De aparte Detailsregel is verwijderd. Eén gedeelde statusregel heeft rechts
het witte info-icoon; het volledige44pt-minimumhitvlak sluit de popover en opent
Over via de bestaande navigatieroute. Dit geldt voor iOS/macOS/demo en alle
verbindingsstaten, ook intern verbonden. Hulp-/foutinformatie blijft onder de regel.
Bestaande About-toegankelijkheidshint gecontroleerd in alle5talen.
Gewone signed native iOS/macOS-builds en strictdeep-signaturesPASS;
iPadinstall/readback40260PASS. Mac mini blijft40258 na eerder geannuleerd
appafsluiten; gewone40260 staat gecontroleerd klaar. iPhone unavailable.
Geen nieuwe fysieke tik/screenshotacceptatie of volledige regressierun.
Privé: connection40260-source.json, native buildlogs/receipts en iPadreadback.
[Apple87 UI-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6233814244), exacte body teruggelezen.

## UI-followup40259 — afgeronde Sessionalbumhoezen

De afbeelding zelf krijgt continuous hoekradius24, passend binnen de bestaande
glassradius32 met8puntenpadding. Aspectratio blijft behouden. Dit geldt voor
de gedeelde renderer in DJMoments en bijdragen uit de sessiegeschiedenis.
Gewone signed iOS/macOS40259-builds en strictdeep-signaturecontrolePASS;
iPadinstall/readback40259PASS. Mac mini blijft40258: appafsluiten werd geannuleerd
(-128), dus geen vervanging van de draaiende app; gecontroleerde gewone40259 staat
herstelbaar klaar. iPhone unavailable. Geen nieuwe fysieke screenshotclaim of
nieuwe volledige testmatrix: de762regressies hieronder horen bij40258.
Privé: artwork40259-{ios,mac}-build.log, -receipt.json en iPad-install/readback.json.
[Apple87 UI-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6233774232), exacte body teruggelezen.

## Geleverde wijzigingen

- **Settings-startup40258:** een echte signed iPad40256 had een inactief leeg
  settingsmodel terwijl de eigen settings3-GET HTTP200/volledig geldig was. Apple
  wachtte onterecht op AskDJ/history-owner. Settings3 levert nu zelf de bevestigde
  backendbinding. De taskfence volgt gekoppelde installatie en bevestigde Profile-
  wissels, zonder afhankelijkheid van historyladen/suspension of URLverversing.
  Onzekere PATCH blijft zonder replay reconcilieerbaar; andere serverbinding of
  echte Profile/paired-contextABA kan oude callbacks/operaties niet terugzetten.
  Expliciete bevoegdheidsintrekking wist zichtbare waarden. Bindingwisseling stopt
  oude spraak ook als de zes veldwaarden gelijk blijven.
- **Watch40256→40258:** eigen foreground-Session-hoofdview, huidige native-admitted
  volledige bijdrage en flowcards, originele source/displaydeadlines en attributie.
  Eigen Watchbearer via typed iPhoneproxy gebruikt bestaande owner-Session/settings3-
  routes; geen iPhonegrant/privatecache/verborgen history of toekomstige planlabels.
  Dezelfde Corecontroller bestuurt zes gedeelde keuzes; gewone lokale moodautoriteit
  is verwijderd. Interactive HAantwoorden gaan niet meer naar applicationcontext/
  transferUserInfo; maximaal8open requests,20stijdslimiet en cancellation/late-reply-
  afhandeling. Watchroute overschrijft geen iPhoneconnectiestatus.
- **Passive Session v1:** adoptie van frozen Core2cb87cb7. Expliciete per-Session
  widget/locked-Activitykeuze, RAM-only grants, onafhankelijke huidige AppGroupcache,
  bounded no-store pixels, echte richwidget/ActivityKitcaller en ownerhint-coalescing.
  Geen authorize bij launch/restart/pairing, geen eigen tekstsamenvatting, geen
  geleende cover, geen richWatchreplica. Originele velddeadlines en uptimefence
  voorkomen sliding TTL/clockrollback; resume herbevestigt dezelfde grant vóór
  rijke presentatie. OSsnapshotretentie wordt in de opt-in uitgelegd.
- **Afbeeldingsroute en renderwerk:** publieke HAimage_proxy volgt bevestigde
  intern/externe transportkeuze, ook als de mode-reporting na playback arriveert.
  Provider-URLs en credentialed Sessiongrants worden niet omgeschreven. Per-image
  1Hzwerk vervangen door echte expiryupdates; Watchcards krijgen dezelfde gerichte
  deadlineplanning. Geen gemeten p95/energie-/lekverbetering uit deze code afleiden.
- **Installatie/documentatie:** Maccopy behield eerder uitvoerbits niet. Alleen na
  bytegelijkheid de8afwijkende modes hersteld; nieuwe gewone-installatiehelper
  verifieert bytes/modes/frameworksymlinks/signature, weigert actieve/onzekere
  bestemming en bewaart herstel.2filesystemtests en registerprojectievalidator
  toegevoegd aan CI. JSON/Markdown/counts/bewijsgrenzen worden nu gelijk gehouden.

## Actuele kwalificatie

| Grens | Resultaat |
|---|---|
| Volledige762Swiftregressies/10suites | PASS91.023s, --jobs2 --no-parallel |
| Gerichte settings |21testsPASS0.191s, onafhankelijke startup/Profilefence/receiptintrekking |
| Nieuwe Watch/proxy/routeregressies |8PASS0.099s; expliciete-nullcodering blijft roundtripgeldig |
| Lokalisatie/brand |1254keys in5talenPASS; exacte taglinePASS |
| HTTPfixturesecurity / installer / register |PASS;2PythonfilesystemtestsPASS; JSON/MarkdownguardPASS |
| Signed gewone iOS/Watch/widgets en macOS40258 |BUILD PASS; strictdeep signatures, geen.xctest, mode/byte/symlinkgelijkheid |
| Geïnstalleerd |iPad/Macmini40258; vorige gewone Macs behouden; iPhone laatst40253/unavailable |
| Echte iPadsettings40258 |PASS0.274s; normale modelread,6effectivevelden/revisie120; aparte Profilefingerprint aanwezig |
| Echte iPadintern/extern40256 |Beide paired statusreads accepted; geen Wi-Fiwisseling of pairedWSbewijs |
| Echte iPadSessionartwork40256 |3/3readypixels;1dj_moment upstream unavailable/insufficient_identity |
| Echte passive40258 |PASS1.428s tijdelijke authorize/current-musicread/serverdisable; geen OSpublicatie.1artslot/0pixels |
| Latere2passivebeeldproeven |FAILED:ready zonder huidige cache; imagecallback niet uitgevoerd. Geen onjuiste cover/TTLverlenging toegevoegd |
| Mac-hosted settings/runtime |NOT_RUN:launch bleef hangen vóór teststart, eigen proces onderbroken; geen PASS/SKIP |
| Watch |Tunnel timeout; iPhoneunavailable. Nativeembedbuild is geen toestel/UI/audioacceptatie |

Eerdere native40255build na cacheverplaatsing faalde op oude VFS-paden; clean
herbouw met feitelijk DerivedDatapad slaagde. Gerichte testfixtures/macro moesten
worden hersteld; alle failures blijven privé bewaard. De echte40256settingsfailure
is niet weggefilterd: die leidde tot de bewezen40258rootfix. Een tussenliggende
regressie ving ook de onterechte contextreset bij het vastzetten van de HA-URL.

De gebruiker zette lokale-netwerktoegang aan. De eerdere -1009 Local network
prohibited is daarmee niet de huidige LANstatus. Verse publieke HAdevcapabilities
bieden settings3/passive1 en vereisen authenticated TLS voor hybridtransport;
interne URL is HTTP. Directe lokale status werkt, lokale pairedWS blijft aan
operationele ingress/TLS en fysieke overgangsacceptatie gebonden.

## Resterende afhankelijkheden en grenzen

Corezelfdewriter: definitieve geïnstalleerde output-transferfix/hoorbare hertest,
insufficient_identity-bron, stempreviewimplementatie/fixtures, native local_on_device
rechten en provider/target/replay/autoplaymatrix. Previewdocument is nog directed
design, geen producerimplementatie. Verse Corecheckpoint309dd90:UNPUBLISHED,
NOT_INSTALLED; geïnstalleerd177/177matchingmaincc9b49fe. Geen Coremutaties hier.

APIzelfdewriter:94/head250be2f,0.4-draft/NOT_FROZEN/NO_RUNTIME_GO; AppAttestbewijs en
nauwe leaf-AKIpolicyGO zijn geen volledige Worker/verifier/scanneracceptatie.
Geen scanner tegen draft; copiedQRkeuze niet heropend. Productiepush vereist eigen
distributieartifact/APNsconfig/locked/backgroundbewijs; development is geen prod.

Open Appleacceptatie: echte richwidgets/lockedActivity/Island/verse eligiblepixels,
Watchinstall/UI/audio/reconnect, twee-device alle6velden/CAS/Profileisolatie/
Session-einde/nieuweSession/HArestart, fysiekeBluetooth/UX/DynamicType/rotatie,
gemeten cold/resume/scroll/CPU/RSS/heap/soak en frameworkcrashrepro. ISS-004 brede
AppModelsplitsing blijft open. Geen generieke Applecrashfix of lekvrijclaim.

## Herstel en opslag

Alleen eigen inactieve herbouwbare caches byte/mode/symlinkgelijk verplaatst naar
EP_DATA, oorspronkelijke paden behouden; bron/evidence/toesteldata bewaard.
8319+6117+5700entries gecontroleerd. Na clean herbouw11GiBintern vrij; laatste verse df nu8.1GiBintern en8.7GiB
op EP_DATA. Dit zijn actuele vrije-ruimtesnapshots, geen fysieke-reclaimclaim. Geen actieve checkouts verwijderd. De eerdere2exact
bewezen gemergede lokale40021branches hebben recoverybundles;0worktrees verwijderd.
Geen nieuwe branch-/worktreecleanup zonder exact mergebewijs.

Alle tijdelijke XCTestapps worden na metingen teruggezet naar de gewone signed
40258. Het iOS-buildproduct is exact uit de gewone bewaarde app hersteld; normaal
project.yml opnieuw gegenereerd. Logs/xcresults/sourcehashmanifest blijven privé
in /private/tmp/djc-settings-consolidation-private; geen tokens/rawProfileIDs,
private tekst of beeldbytes in deze documentatie/lanecomments.

Lanebericht en exacte tekstreadback: [Apple87](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6233701663), [Core1101](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6233702160). Beide geplaatste bodies met SHA256 tegen de lokale rapporttekst geverifieerd.

[Apple-afmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6234945105) en [Core-afhankelijkheden](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6234951231), beide exacte bodyreadback bevestigd.
