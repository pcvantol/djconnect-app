# Afspeelknop rechtsonder met gelijke randafstand — 17 oktober 2026

Ownerbevinding: de ronde TTSknop in een bijdrage staat te ver van de rechterrand.
De gedeelde AskDJMessageBubble gaf de volledige inhoud, inclusief speechfooter,
36pt extra trailingruimte voor het contextvraagicoon. De overige padding was
horizontaal14 en verticaal10: daardoor kwamen de randen niet overeen.

De reservering voor het contexticoon staat nu uitsluitend rond de inhoud.
De footer krijgt de volle beschikbare breedte. DJ-conversatiebubbles gebruiken
14pt horizontaal/verticaal; de 44ptknop eindigt daarmee rechtsonder met dezelfde
afstand tot beide randen. Userbubbles behouden hun bestaande verticale10pt.
De gedeelde speechrij gebruikt bottomalignment, zodat een meerregelige
statusmelding of uitvoermenu de knop niet meer verticaal centreert. Bestaande
Moment-/historykaartinsets blijven symmetrisch; dezelfde speechrij wordt overal
gebruikt. Geen absolute schermcoördinaten, tekstoverlap of vaste bubblehoogte.
De bestaande text-only/admissionguards, knopacties en TTSafhandeling zijn behouden.

## Verificatie en aflevering

- Bestaande glass-/vinylrendergroep:2tests/6gevallenPASS0.041s. Geen nieuwe
  permanente test voor deze kleine visuele wijziging, geen volledige TTSrunclaim.
- Afzonderlijke echte AskDJMessageBubble-layoutpreview op358/560pt, met/zonder
  contextvraagicoon:4rendersPASS. De footer wordt geïnjecteerd als gekleurde
  44ptcirkel; dit is layoutbewijs, geen echte TTSbediening. AppKitpixelmeting
  vindt viermaal15px rechts én onder (14ptlayout,1pxrasterrandtolerantie).
  Beide358ptbeelden bekeken. Reduce-glass/dekkende achtergrond geeft een
  deterministisch raster; geen positieve claim over native contextsymbolen
  of fysieke LiquidGlasspixels uit ImageRenderer.
- Losse preview had eerst het SwiftPM-resourcepad voor de datumtekst nodig;
  hersteld zonder productiebronwijziging. De eerste pixelmeting vergeleek
  buitenrand rechts met binnenrand onder; gelijkgetrokken randdetectie, geen
  ruimere tolerantie. Eerste failures behouden; uiteindelijk4gelijke metingen.
- Gewone signed iOS/iPadOS40279 inclusiefWatch/widgets en macOS40279 buildPASS;
  76source/stagehashes, strictdeep signatures, ordinarycopybytes/modes/symlinks
  en geenxctest/resourceforksPASS. Statisch launchresource bytegelijk aan40278;
  geen stilzwijgende Base-lokalisatieproef.1257lokalisatiesleutelsPASS.
- GewoneiPad40279 geïnstalleerd, onafhankelijk teruggelezen en appgeopend.
  iPhone40267/Mac40266behouden volgens bestaande alleen-iPadkeuze. Geen nieuwe
  fysieke screenshot-/audioacceptatie of beschermde bronoplevering geclaimd.

Bronwijziging: DJConnectRootView.swift en ProfileDJSettingsEditor.swift in de
bestaande solewriter/HEAD4fa9115 plus behouden WIP. Private kandidaten
`/private/tmp/djc-playcorner40279-ordinary-{ios,mac}.app`; bewijs `playcorner40279-*`
onder de bestaande qualificationmap. Brede UI/TTS/nativejointmatrix blijft open.

[Apple87-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6236060725), exacte body teruggelezen.

## Verse fysieke viewport40280

40280followup: echte gewoneiPadviewport in beide standen bekeken; vinyl staat binnen albumkaart en ronde TTSknop rechtsonder. Geen audioactie of echte downloade2e. Zie [mood-edgecontrole](APPLE_IPAD_SESSION_MOOD_EDGES_20261017.md).
