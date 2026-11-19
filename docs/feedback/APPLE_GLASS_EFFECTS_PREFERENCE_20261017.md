# App-instelling Glaseffecten — 17 oktober 2026

Directe owneropdracht: één schakelaar onder Instellingen → App om glass uit te
zetten voor oudere apparaten. Bestaande Apple-writer/HEAD4fa9115 plus behouden
WIP; gewone kandidaat40277. Geen backend- of Profilecontract gewijzigd.

## Gedrag en eigenaarschap

- Glaseffecten staat standaard aan en werkt direct zonder herstart. De keuze
  blijft uitsluitend op dit apparaat in de gewone appvoorkeuren bewaard; geen
  Profileveld, synchronisatie naar andere apparaten of achtergrondrequest.
- Eén gedeelde policy vervangt app-eigen Liquid Glass en SwiftUI Material door
  een eenvoudig dekkend vlak. Dit omvat sessiekaarten, artframes, actieknoppen,
  invoervelden, overlays en pop-outs. Kleuren, inhoud en bediening blijven werken.
  GlassEffectContainer wordt bij uitgeschakelde effecten niet opgebouwd.
- De UIKit-tabhost krijgt de policy expliciet over zijn UIHostingControllergrens;
  zijn eigen tabbarappearance wisselt alleen wanneer de policy verandert, niet
  bij elke playbacktick. iPhone/iPad/Mac gebruiken dezelfde setting; Watch krijgt
  dezelfde lokale schakelaar onder App en deelt de policybron.
- De systeeminstelling Verminder transparantie blijft leidend. De app kan geen
  globale uitschakeling van Apple-beheerde menumaterialen/chrome afdwingen.
  Artwork, gewone kleurverlopen en onafhankelijke vinylanimatie blijven bestaan;
  minder beweging is een afzonderlijke systeemkeuze.
- Twee teksten zijn volledig vertaald in nl/en/de/fr/es. Accessibility-ID:
  `settings-glass-effects`. Geen nieuwe technische gebruikersmelding.

## Verificatie en aflevering

- Lokalisatievalidator PASS1257keys/5talen.
- Echte ImageRenderer-regressies vergelijken de centrale pixels van Material-
  en sessiekaarten boven wit en zwart. Uitgeschakelde glass is identiek/dekkend;
  geen alternatief blurmateriaal. Samen met de bestaande vinyl-layoutregressie:
  2tests/6parametergevallen PASS0.058s.
- Eerste testcompile probeerde Apple's read-only toegankelijkheidswaarde te
  injecteren; compilefout hersteld, failurelog behouden. De test wijzigt of
  simuleert geen systeemvoorkeur; fysieke toegankelijkheidsmatrix niet geclaimd.
- Gewone signed iOS/iPadOS40277 inclusief Watch/widgets en macOS40277 buildPASS.
  Source/stagehashes van76Swift-/lokalisatiebestanden gelijk; ordinarybundles,
  strict/deep signatures, geenxctest/resourceforks en exacte kopiebytes/modes/
  symlinks PASS. Bewaarde kandidaten `/private/tmp/djc-glass40277-ordinary-ios.app`
  en `...-mac.app`. Het geïnstalleerde statische40272launchresourcebeleid blijft
  behouden; de aparte Base-lokalisatieproef wordt niet stilzwijgend afgeleverd.
- GewoneiPad40277 geïnstalleerd; onafhankelijke CoreDevice-inventaris leest exact
  `dev.djconnect.ios`/40277 terug. Externe UItest tegen de gewone app PASS1test,
  0failures/0skips/33.872s: instelling bereikbaar, toggle wijzigt direct, waarde
  blijft na gewone appherstart behouden, oorspronkelijke waarde teruggezet.
  Eigen tijdelijke runner verwijderd; gewone app/voorkeuren blijven behouden.
- Private screenshots voor/na zijn bekeken en tonen de dekkende kaartfallback.
  De iPad-screenshot is aan de rechterzijde afgesneden; dat is geen complete
  visuele layoutacceptatie. De toggle zelf is door XCTest hittable bediend en
  zijn waarde exact gecontroleerd. De bredere UI-layoutmatrix blijft open.
- iPhone blijft op40267 en draaiendeMac op40266 volgens bestaande deliverykeuze;
  geen nieuwe fysieke iPhone/Mac/Watchacceptatie. Geen beschermde bronrelease.

Privébewijs: `glass40277-*` onder de bestaande qualificationmap. De twee
renderregressies lopen mee met de bestaande automatische Swift-teststap. De
externe toestelprobe staat reproduceerbaar onder Tools/qualification/settings.

## Performancegrens

Minder backdropblur en compositing kan GPU-/renderwerk verminderen. Dit is een
technische verwachting op basis van de gebruikte effecten, geen gemeten FPS-,
energie-, geheugen- of oudere-apparatenclaim. Algemene performance/crashprofiling
blijft afzonderlijk open. Apple beschrijft Material als blur/blending en beveelt
GlassEffectContainer aan voor efficiënte glass-rendering:
[Material](https://developer.apple.com/documentation/swiftui/material),
[Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).

[Apple87-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6235866275), exacte body teruggelezen.
