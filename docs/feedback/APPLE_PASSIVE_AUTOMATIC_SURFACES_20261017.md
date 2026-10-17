# Automatische Session-widgets en Live Activity — 17 oktober 2026

Actueel:gewoneiPad40272 geïnstalleerd/teruggelezen;26gerichte testsPASS2.533s en
signed iOS/macOSbuildsPASS. Automatische widgetmuziek/SDK-start gemeten; huidige
LiveActivityrichcache/pixels en duurzame achtergrondacceptatie blijven open.

Directe nieuwe ownerinstructie vervangt de eerder gekozen extra per-Session
pop-out: volledig automatisch bij een bevestigde actieve DJ-sessie. Geen nieuw
instellingenmenu of persoonlijke voorkeur in device-defaults. Widgetplaatsing
blijft een OS-keuze; Live Activity volgt de bestaande iOS-toestemming en respecteert
het wegvegen door de gebruiker. De extra pop-out en beide schakelaars vervallen.

Apple gebruikt de bestaande gepaarde surface-authorize/read-routes en blijft
onafhankelijke grants, Profile/installatiebinding, oorspronkelijke veld-/beeld-TTL,
bronrechten en no-store transport respecteren. Een widget wordt automatisch
voorbereid wanneer WidgetKit een geplaatste DJConnect-widget meldt. Live Activity
wordt in de foreground voorbereid wanneer iOS deze toestaat en een actuele Session
bevestigd is. Geen grant uit oude AppGroupbytes of foreground Momentrechten.
Onzekere authorize-uitkomsten worden niet blind herhaald. Bij OS-uitschakelen,
Sessioneinde of echte eigenaarwisseling wordt de presentatie ingetrokken.

Dit wijzigt de productregel voor het verkrijgen van toestemming; de wirevelden
blijven gelijk. Core blijft eigenaar van het producercontract/SYNC en de acceptatie
van deze nieuwe OS-/Sessiongestuurde regel. De huidige capability adverteert nog
explicit_consent_required en background_delivery=false. Apple meldt de concrete
wijziging in de bestaande Core-lane, zonder tweede Core-writer of bronmutatie daar.

Echte iPad40267-read: drie geconfigureerde widgets, groepscontainer toegankelijk,
Live Activities toegestaan, server-Session actief/settings actief/capability1,
maar geen neutrale/rich caches en geen Activity; wel oude requestmarker. Dit
bewijst geen widgetpixels, maar bevestigt een ontbrekende publicatie/lifecycleketen.
History-suspension is geen passieve bevoegdheidsintrekking: de eigen bestaande
korte cache mag bij achtergrondgang tot haar oorspronkelijke deadline blijven.
Een door de app beëindigde Activity mag later opnieuw beginnen; een door de
gebruiker weggeveegde Activity blijft voor dezelfde Session weg.

V1 geeft geen achtergrondlevering. Apple verlengt geen bron-TTL en maakt geen
achtergrondpoller of gedeelde ownerbearer. Verse data na achtergrondverval vereist
gekwalificeerde Core/ActivityKit-achtergrondlevering en gezamenlijke OS-acceptatie.
Dat blijft een concrete producerafhankelijkheid, geen fictieve native PASS.

## Vervolgmetingen en lifecycle

Gewone40268 vulde beide stores automatisch met actuele muziek;40269 bevatte
in beide caches zowel actuele bijdrage als muziek,0pixels. De OS-read zag
3widgets, geldige neutrale/rich caches en een actuele requestmarker. De Activity-
lijst was na diagnostische herinstallatie leeg; die meting bewijst dus geen
blijvende gewone Activity. De definitieve gewone app gebruikt aparte ontvangen
request/build- en bevestigde-dismissalmarkeringen, en registreert alleen SDK-
status/aantal zonder inhoud/IDs. Een statusobserver bewaart ontvangen dismissal;
een nieuwe build mag een verloren OS-instance herstellen, geen bekende dismissal.
De definitieve fysieke controle gebruikt bestaande appdiagnostiek zonder nieuwe
XCTest-herinstallatie. Er wordt geen screenshot- of lange-background-PASS afgeleid.

25gerichte regressiesPASS2.193s: automatische grantkeuze, één poging per context,
geen onzeker-write-replay, OS-intrekking tijdens late imageIO, originele TTL,
Profile-/Sessionisolatie, cachemigratie en Activitymarker over hervatten/upgrade.
Eerdere24PASS2.059s/23PASS2.170s en de twee echte readonlyOS-metingen blijven behouden.
Rootstartup en hervatten laden eerst settings3 en daarna de Session, ook zonder menuactie.

[Concrete Core-overdracht](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6234481650), exacte body teruggelezen.

## Gewone40270: daadwerkelijke opstartfout en herstel40271

De echte applog toonde ActivityKit state=active/count=1, direct gevolgd door
ended by app in dezelfde seconde. De eerste Session-read liep vóór settings3;
de latere bindingadoptie trok de net gemaakte presentatie weer in. Bovendien
kan ActivityKit bij een app-einde een dismissed-event geven. De oude observer
kon dit onterecht als gebruikerskeuze bewaren.40271 laadt settings3 eerst en
fencet elke request/end/dismissal aan de exacte Activity-instance. Een laat
event van een oude instance kan geen vervangende Activity blokkeren. De extra
regressie controleert beide late events en echte dismissal van de huidige instance.

Native iOS/macOS40271 en25gerichte testsPASS; geen nieuwe volledige regressie-
of hardwarepixelclaim. De eerste native40270 compile faalde op Swift6-isolatie
van de nog niet Sendable-geannoteerde SDK-reference; expliciete preconcurrency-
interop is begrensd tot ActivityKit, met MainActor-bookkeeping en seriële lifecycle.
De gerepareerde40270 en40271nativebuilds slagen; de oorspronkelijke foutlog blijft.

## Definitieve automatische iPad-followup40272

Een richveld heeft een eerdere deadline dan de neutrale Sessionobservatie.
Voorheen kon die korte deadline de hele Activity laten stoppen.40272 verwijdert
verlopen velden vóór de compacte Activityprojectie en herstelt de neutrale
Sessionstatus uitsluitend tot de oorspronkelijke observedAt+120s. Geen nieuwe
observatie of bronlease uit cache/expiry afgeleid; regressie controleert verval
van bijdrage tegenover nog actuele muziek en uiteindelijke neutralexpiry.

26gerichte testsPASS2.533s; signed gewone iOS/macOS40272 inclusiefWatch/widgets,
deepstrict signatures en bron/stagehashesPASS. Native40270's oorspronkelijke
concurrencyfout, oudere regressies en echte metingen blijven bewaard.762fulltests
zijn ouder40258-bewijs, niet opnieuw40272 uitgevoerd.

Gewone40272 op iPad geïnstalleerd en versie teruggelezen. ActivityKit gaf eerst
vier tijdelijke authorizationfouten(domain/code7) tijdens opstart en accepteerde
daarna active/count1. De eerste gewone runtime-read toont geen direct app-einde.
Actuele neutrale cache en widgetmuziek aanwezig; live_activityrichcache bij deze
read afwezig,0art/pixels. Eerdere40269/40271reads bevatten beide richstores met
muziek én bijdrage. Geen afleiding van OS-pixels of blijvende achtergrondwerking.
De owner kiest alleeniPad; iPhone40267 blijft behouden, Mac40266draait en gewone
40272 staat gereed. Watch40272 alleen meegebouwd, geen nieuwe hardwareacceptatie.

Core bevestigt in zijn actuele integrale readback dat passivev1 nog
explicit_consent_required=true/max120s/background_delivery=false bevat.
[Core-integrale status](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6234854788).
De concrete automatische beleidsoverdracht blijft dezelfde; geen tweede writer,
geen backgroundpoller/leaseverlenging. Definitieve owning JSON/Markdownregisters
onderscheiden bounded consumerafmelding en open parentacceptatie. Privébewijs:
passive40272-source.json, targeted/nativebuildlogs/ordinaryreceipts, iPadinstall/
apps/shared-read/runtime en gesaneerde samenvatting.

De tweede gewone40272-read, enkele minuten later zonder XCTest-herinstallatie,
bevestigt dezelfde SDK-startlog zonder daarna app-einde, actuele neutralcache en
actuele widgetmuziek. LiveActivityrichcache blijft afwezig. Dit verklaart waarom
we rijke Lock/Islandinhoud nog niet afmelden. Alleen SDK-acceptatie en automatische
widgetpublicatie zijn gemeten; de externe OS-weergave is nog niet visueel bevestigd.

[Apple-afmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6234945105) en [Core-afhankelijkheden](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6234951231), exacte teruglezing bevestigd.
