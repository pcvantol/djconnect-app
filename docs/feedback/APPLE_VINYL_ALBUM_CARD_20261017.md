# Vinyl in dezelfde album-artkaart — 17 oktober 2026

Owner vraagt dezelfde vormgeving met en zonder beschikbare hoes. De gedeelde
`CachedArtworkImage` gaf alleen succesvol geladen pixels de album-glassmodifier.
De placeholder, demo, laadfase en mislukte download sloegen de hele kaart over.

De kaart staat nu rond de gezamenlijke inhoud: gelijke maximale maat, donkere
ondergrond, inset8, continue binnenhoeken en bestaande glass-rand. Dit geldt voor
Speelt Nu en de actuele sessiemuziek op iPhone/iPad/Mac. De vinylanimatie blijft
bestaan. De lokale glaseffectschakelaar/systeemvoorkeur blijft dezelfde gedeelde
kaartpolicy sturen. Overige afbeeldingen zonder albumframe krijgen geen extra
rand. Alleen bij werkelijk geladen huidige pixels wordt de bijbehorende
coverkleur opgevraagd; geen extra retry/tintdownload voor ontbrekende hoes.
Geen backendcontract, Profilekeuze of laad-/playbacklogica gewijzigd.

Verificatie: bestaande artwork-/glass-rendergroep2tests/6gevallenPASS0.041s.
Afzonderlijke handmatige ImageRenderer-proef van de echte CachedArtworkImage
zonder URL op190/270/358pt bevestigt vierkante framegeometrie;358ptPNG bekeken:
vinyl binnen afgeronde kaart/inset/rand. Deze renderproef gebruikt de dekkende
fallback om een voorspelbaar raster te krijgen; geen fysieke LiquidGlasspixelclaim.
Geen nieuwe permanente test voor deze kleine visuele wijziging.

Gewone signed nativeiOS/iPadOS40278 inclusiefWatch/widgets en macOS40278PASS;
76source/stagehashes gelijk, strictdeep signatures en gewone bundels/kopiebytes/
modes/symlinksPASS. Het gecompileerde statische launchresource is bytegelijk aan
gewone40277; de aparte Base-lokalisatieproef blijft buiten deze aflevering.
GewoneiPad40278 geïnstalleerd en onafhankelijk teruggelezen. Geen nieuwe fysieke
screenshotacceptatie van deze artworkkaart. iPhone40267/Mac40266behouden volgens
bestaande alleen-iPadkeuze. Geen beschermde bronrelease of algemene UIclosure.

Private kandidaten: `/private/tmp/djc-vinylcard40278-ordinary-ios.app` en
`...-mac.app`; bewijs `vinylcard40278-*` onder de bestaande qualificationmap.
Productiewijziging beperkt tot de gedeelde CachedArtworkImage-layout en de
bijbehorende placeholdercommentaartekst, binnen dezelfde bestaande Apple-writer.

[Apple87-terugmelding](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6235934840), exacte body teruggelezen.

## Verse fysieke viewport40280

40280followup: echte gewoneiPadviewport in beide standen bekeken; vinyl staat binnen albumkaart en ronde TTSknop rechtsonder. Geen audioactie of echte downloade2e. Zie [mood-edgecontrole](APPLE_IPAD_SESSION_MOOD_EDGES_20261017.md).
