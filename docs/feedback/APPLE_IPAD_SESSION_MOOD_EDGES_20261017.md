# iPad: sessiemood tot de boven- en onderrand — 17 oktober 2026

Ownerfoto toont een groene actieve DJsessie met een vaste blauwe statusbalk en
paarse onderste strook. De moodcanvas bestond alleen binnen de sessietimeline.
De buitenste SwiftUIroot achter UIKit's native tabhost en de NavigationStack-
wrapper bleven de vaste merkcanvas tekenen. De interne ignoresSafeArea kon de
buitenste containerachtergrond niet vervangen.

De iPadroot gebruikt nu dezelfde bevestigde Sessionmood als de timeline, zolang
DJ-sessie geselecteerd is. Deze achtergrond bedekt de container-safeareas achter
statusbalk en onderste systeemrand. Ook de directe Sessionwrapper volgt dezelfde
mood. Buiten de DJ-sessietab en zonder actieve Session blijft de gewone
merkcanvas gelden. Geen hardcoded groen, draftmood, nieuwe Profilewaarde,
serverwrite, extra poller of wijziging van content-/toetsenbordsafeareas.

## Verificatie en aflevering

- Gewone signed nativeiOS/iPadOS40280 inclusiefWatch/widgets en macOS40280PASS;
  source/stagehashes76bestanden gelijk, strictdeep signatures en gewone
  copybytes/modes/symlinksPASS. Statisch launchresource bytegelijk aan40279;
  aparte Base-lokalisatieproef blijft buiten aflevering.1257localechecksPASS.
- Bestaande glass-/vinylrendergroep2tests/6gevallenPASS0.040s. Geen nieuwe
  permanente test voor deze kleine visuele wijziging.
- GewoneiPad40280 geïnstalleerd en vóór/na de schermopname onafhankelijk
  teruggelezen. Een externe screenshotprobe bedient alleen DJ-sessie/Meer en
  roteert het scherm; geen backendactie, moodkeuze of audio-/playbackcommando.
  Oorspronkelijke oriëntatie hersteld, terug naar DJ-sessie, eigen runner verwijderd.
- Screenshotprobe1PASS/0failures/0skips/15.959s: gewone actieve Session aanwezig,
  bevestigde accessibilitywaarde **Energie** in beide standen. Volledige
  XCUIScreenbeelden zijn daadwerkelijk bekeken: liggend1389×970pt en
  staand970×1389pt, groen achter statusbalk én tot onderste systeemrand;
  geen oude blauwe/paarse strips. Het derde beeld toont Meer met de gewone
  merkachtergrond: de sessiemood lekt niet naar die tab.
- Eerste compile van de losse probe gebruikte een onjuist oriëntatietypenaam;
  UIKit-UIDeviceOrientation hersteld, failurelog behouden. Dit was geen
  productiefout; gewone nativebuilds waren groen. Probe/beelden blijven privé.
- In dezelfde fysieke viewports zijn ook de echte vinylfallback binnen de
  album-artkaart en de ronde TTSknop rechtsonder bij een bijdrage zichtbaar.
  Dit sluit hun beperkte visuele iPadbewijsgrens; geen audioactie of echte
  downloadtest uitgevoerd. Huidige muziekstatus is Niets speelt af; Session is
  wel actief en Energy bevestigd. De probe startte of stopte geen muziek.

iPhone40267/Mac40266behouden volgens alleen-iPadkeuze; geen verse fysieke
acceptatie voor iPhone/Mac/Watch. Andere moods, Sessioneinde/terugkomst,
keyboard/splitview/externaldisplay en de volledige UI-matrix zijn niet opnieuw
gekwalificeerd. Geen algemene performance-, crash-, TTS- of bronreleaseclosure.

Bronwijziging: uitsluitend DJConnectRootView.swift binnen bestaande Apple-writer,
HEAD4fa9115 plus behouden WIP. Private kandidaten
`/private/tmp/djc-moodedges40280-ordinary-{ios,mac}.app`; bewijs `moodedges40280-*`
onder de bestaande qualificationmap. XCUIScreen captures vermijden de eerdere
app.screenshot-crop; de oude incomplete screenshotclaims worden niet opgewaardeerd.

[Apple87-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6236182122), exacte body teruggelezen.
