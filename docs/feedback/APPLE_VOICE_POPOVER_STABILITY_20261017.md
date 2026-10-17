# DJ-stem-pop-out: stabiele native keuzemenu's — 17 oktober 2026

Ownerbevinding: het scherm flikkert terwijl Stemvoorkeur of Afspeelvoorkeur is
uitgeklapt. Bestaande Apple-writer, HEAD4fa9115 plus behouden WIP; kandidaat40276.

## Oorzaak

`ProfileDJSettingsEditor` observeerde het gehele `DJConnectAppModel`, naast de
settingscontroller. Afspeelvoortgang verandert elke seconde; de bestaande
foregroundpoller leest ook settings3. Daardoor werd dezelfde editor steeds
opnieuw geïnvalideerd. De controller publiceerde iedere verse response, ook als
uitsluitend de producerklok `as_of` veranderde. Bovendien maakte `!reading` in
`canEdit` een open keuzemenu tijdelijk disabled tijdens een gewone achtergrond-GET.

Er is geen eigen periodieke refreshtaak aan deze pop-out toegevoegd. De `.task`
voor de eerste read bij openen blijft één lifecycleactie. Bestaande automatische
achtergrondlezingen blijven nuttig voor keuzes die op een ander apparaat wijzigen.

## Correctie

- De editor observeert een kleine RAM-presentatieprojectie met uitsluitend de
  zichtbare settings, beschikbaarheid, eigenaar en actiestatus. Wijzigingen binnen
  één controllertransactie worden samengenomen. Klok-/receiptmetadata alleen
  veroorzaken geen nieuwe menuweergave. De echte controller houdt wél elke verse
  producerresponse voor CAS, tijd en authoritychecks.
- Beide presentatieplaatsen gebruiken dezelfde Equatable-editorgrens. Een
  playbacktick of andere algemene app-publicatie bouwt de editor niet opnieuw op;
  taalwisseling en betekenisvolle settings-/authoritywijzigingen werken door.
- Een gewone freshness-read blokkeert een expliciete keuze niet meer. Een keuze
  trekt de completionbevoegdheid van een oudere GET in, zodat een laat snapshot
  of oude 401 de nieuwe keuze niet terugdraait of de actuele eigenaar intrekt.
  Geen write-replay of extra automatische instellingenwijziging.
- Na een echte mutatie blijft een tweede write geblokkeerd totdat de verplichte
  actuele readback slaagt. Pending/onzekere operaties, profielwisseling, text-only,
  providerwithdrawal en bestaande serverrevisies blijven leidend.

Productiepatch: `ProfileDJSettingsModel.swift`, `ProfileDJSettingsEditor.swift` en
de twee editor-aanroepplaatsen in `SessionTimelineScreen.swift`. Gerichte tests
staan in `ProfileDJSettingsContractTests.swift`. Geen backendcontract of
profielpersistentie gewijzigd; geen nieuwe teksten of lokalisatiesleutels.

## Verificatie en aflevering

- 25 gerichte settings-/menutests PASS0.201s, daarna 36 gerelateerde
  settings/Watch/autoplaytests PASS0.253s. Nieuwe regressies:20klokupdates zonder
  editorpublicatie; text-only/providerwithdrawal/authorityverlies wél zichtbaar;
  keuze tijdens GET met laat antwoord én late401; tweede write wacht op actuele
  readback; editoridentiteit blijft gelijk bij playbacktick en verandert bij taal.
- De eerste compilefout (snapshotinitializer had expliciete MainActorisolatie
  nodig) is hersteld en de failurelog bewaard. De eerste parallelle testgroep
  botste in twee bestaande HTTP-speechtests op de globale limiet van2transfers.
  De gehele betrokken groep is vervolgens expliciet serieel groen uitgevoerd.
  Geen productie-transferlimiet versoepeld en geen failure verborgen.
- Gewone signed iOS/iPadOS40276 inclusief Watch/widgets en macOS40276 buildPASS;
  beide strict/deep handtekeningen, geen testbundels/resourceforkbestanden,
  exacte bron/stagehashes en kopiebytes/modes/symlinks PASS.
- Bewaarde gewone kandidaten: `/private/tmp/djc-voicepopover40276-ordinary-ios.app`
  (138manifestentries) en `...-mac.app` (79). Nog niet geïnstalleerd bij deze read.
- De iOS-kandidaat behoudt de statische systeem-launchscreenlayout van de
  geïnstalleerde40272. De aparte Base-lokalisatieproef40273 blijft in de writer
  bewaard en wordt niet stilzwijgend mee geïnstalleerd vóór de open ownerkeuze.
- Verse CoreDevice-read: iPad disconnected, iPhone unavailable. Owner gevraagd
  iPad viaUSB te verbinden/ontgrendeld te laten. iPhone blijft volgens de eerdere
  ownerkeuze buiten deze update. Mac40266 wordt niet geforceerd afgesloten.

Dit is implementatie-/test-/buildbewijs. De visuele proef met een echt open
native menu tijdens playback en installatie op iPad blijven open. Geen nieuwe
fysieke UI-, LAN-, pushproductie-, crash- of algemene performance-PASS.

Privébewijs: `voicepopover40276-*` onder de bestaande qualificationmap, inclusief
eerste failures, gerichte/gerelateerde runs, native logs, ordinaryreceipts,
pre-change-/stagehashes en CoreDevice-readback.

[Apple87-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6235521298), exacte body teruggelezen.

## Actuele aflevering na owneraansluiting

De owner heeft de iPad aangesloten. Gewone40276install is geslaagd; onafhankelijke appinventaris leest daadwerkelijk `dev.djconnect.ios`/40276 terug (voorheen40272). Gewone app geopend. De externe read-only UIprobe bedient uitsluitend de native menus zonder een waarde te kiezen; zij koppelt geen testbundle in DJConnect en reset geen voorkeuren. De fysieke uitkomst wordt afzonderlijk vastgelegd zodra de probe eindigt.


## Fysieke uitkomst na bevestiging UI-automatisering

De eerste externe runner liep vóór de eerste test vast met de expliciete melding
`Timed out while enabling automation mode`; failure/resultaat behouden. Na de
ownerbevestiging start XCTest normaal. Beide menucontroles zijn **SKIP**, omdat
geen actief Sessionmenu aanwezig is. Een afzonderlijke private schermafbeelding
is bekeken en bevestigt het gewone StartDJ-sessiescherm. De screenshotdiagnose is
geen positieve menu- of stabiliteitstest. Er is geen Session aangemaakt, geen
optie gekozen en geen playback gewijzigd om een groen resultaat af te dwingen.
De tijdelijke eigen UI-runner is opgeruimd; gewone40276 blijft geïnstalleerd.

Actueel: source/36regressies/nativebuild/gewoneiPadinstall afgerond. Echte beide
open menus tijdens een actieve Session blijven afzonderlijk open. iPhone/Mac
zijn niet vervangen. Core heeft intussen het eigen updatevenster vrijgegeven;
producerpin6a3adbc8 behoudt settings3/speechcontracten. Geen nieuw Apple-LANbewijs.

[Aflevering Apple87](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6235668766), exacte body teruggelezen.
