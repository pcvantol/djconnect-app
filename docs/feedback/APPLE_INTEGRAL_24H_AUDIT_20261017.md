# Integrale Apple-audit afgelopen24uur

Historische10:32-readback. Actuele vervolgaudit en bijgewerkte acceptatiematrix: [APPLE_OPEN_WORK_20261017.md](APPLE_OPEN_WORK_20261017.md), inclusief40250artworkrepair/finale734tests en lanecomments. Onderstaande status niet als huidig installedreadback gebruiken.

Readback2026-10-17 circa10:32 Europe/Amsterdam. Venster vanaf2026-10-16 circa10:32.
Read-only broncontrole en eigen auditdocument; geen nieuwe productpickup, writer,
HA-wijziging, merge of publicatie. Gebruikersopdrachten behouden hun scope.

Bronnen:34 Apple#87-comments en37 Core#1101-comments in het venster; actuele
API94/0.4pin60c291a3 en bestaande API/Core-taskstatus; bestaande Apple werkcode,
feedbackrecords, testlogs en verse toestel/app-/HA-readbacks.

## Vier hoofdopdrachten

| Opdracht | Werkelijk geleverd | Nog te sluiten | Eigenaar/afhankelijkheid |
|---|---|---|---|
| Session Speech/Persona/Voice + generieke HA-TTS | Play/Stop/Replay in geldige bubbles, prepare3, expliciete profielactivatie, iPhone playerstart/stop/replay en eerdere-session on-demand nieuwe audio; provider-default/nullvoice-adoptie en tests | Nieuwe providerneutrale Core-code op HA-dev; echte Spotify/OpenAI-route opnieuw testen; outputtargetmatrix/lokale-en-HA replay, providerwissel/withdrawal, iPad/Mac/Watch en hoorbare acceptatie; review/protected afsluiting | Bestaande Apple-writer, bestaande Core-writer voor bron/deployment |
| Profile/Session Settings Consolidation | Zes velden, gedeelde editor Instellingen→Profiel→Jouw DJ, typed snapshots/revisies/operation receipts, gekoppelde snelbediening; testdekking, native editor en één echte opslaanactie | Voor alle zes automatische twee-device readback; Session-einde/nieuwe Session/defaults/HA-herstart; Profile-isolatie/conflict/reconnect en unavailable-keuzeacceptatie; volledige legacy-inventaris/opruiming incl. targets en migratiegrenzen; formele gezamenlijke afsluiting | Apple-adoptie; Core1329ad1-contract geleverd, installed end-to-end nog open |
| VibeCast owner-scanner/App Attest | Consumerreview en UX/copyvoorbereiding, geïsoleerde Mac/Chromium JWE, echte signed DJConnect-iPhoneattestaties/assertions, countercontinuïteit en SDK-foutbevinding; API0.4-policy-ACK | Full API verifier/receipt/extensiepolicy; contractfreeze; echte iPhone-JWE-interop; operationeel enrollment/herstel/rotatie; scanner-UI en HA-context/adresoverdracht; bestaande B-codeflow en fysieke ketentest; review/protected afsluiting | API heeft echte private fixtures opgepakt; Apple-runtime wacht terecht op contractvrijgave |
| Apple-native DJMoment TTS override | Eigenaaropdracht en executor-handoff geregistreerd | Nog geen nieuwe device-toggle, echte voice-picker/gender/pitch/snelheid, DJMoment grant-integratie of four-target kwalificatie; minimale Core-contractreconciliatie en uitvoerings-ACK ontbreken | SELECTED_QUEUED binnen bestaande Speech/Settings-ownership; geen tweede writer |

Bestaande AVSpeechSynthesizer-code betreft onder meer demo/oud Watchgedrag en
bewijst de nieuwe lokale DJMoment-override niet. De nieuwe taak niet als deels
geïmplementeerd of als afgerond tellen omdat deze API al in het project voorkomt.

## Dwarsdoorsnijdende open punten

- Verbinding/URL/WebSocket: Apple status-URL-sync en ATS-correctie aanwezig. Verse
  no-token LAN-preflight op HA-dev geeft nog426 transport_security_required;
  directe lokale ingress-kwalificatie ontbreekt. Werkelijke Wi-Fi→lokaalWS en
  mobiel→externHTTPS/ngrok plus resume/reconnect zijn nog niet als complete
  fysieke routewisselmatrix opgeleverd. iPad UI-automatisering werd geblokkeerd
  vóór producttest; gebruiker was afwezig. Geen verzoek om dezelfde goedkeuring.
- HA-dev: geïnstalleerde session_speech.py verschilt op dit auditmoment nog van
  de huidige Core-WIP. Beide manifesten kunnen dezelfde versiestring hebben;
  dat vervangt geen bronpin-/installedreadback. Providerfix is niet geïnstalleerd.
- Passive Session Projection: definitieve Core-handoff2cb87cb7 is in dit venster
  ontvangen. Native/cache/lock/background/Watch/joint-acceptatie is daardoor niet
  gesloten. Het is een afzonderlijke consumerafhankelijkheid, geen automatisch
  gestarte vijfde Apple-writeropdracht.
- Kleinere UI-herstellingen/artwork/scroll/title/widget/media/outputkeuzes zijn
  verspreid getest en geïnstalleerd. Tint van de actieve album-artbubble mist nog
  echte actieve-session visuele acceptatie; native Bluetoothicoon is bron-/build-
  en predicategetest, fysieke routeacceptatie niet. Niet alle gebruikersscreenshots
  zijn afgedekt door één finale apparaatrun.
- Tagline heeft één vijf-taalbron, eigen commit en native render-/buildbewijs;
  dat sluit geen settings-, speech- of scanneropdracht af.

## Installed en source-delivery bij dit readback

- iPhone40231: gewone app teruggezet na diagnostiek, geen AppAttest-testbundle;
  verse CoreDevice-readback. iPad40226: verse readback. Mac mini40225: bundle-readback.
  De meest recente verschillende buildnummers weerspiegelen aanvullende iPhone-
  diagnostiek/herstel; ze bewijzen geen universele feature-/hardwareacceptatie.
- MacBook: geen actuele installatie/readback bewezen in deze audit.
- Apple sole writer codex/apple-dj-presence-v1, HEAD4fa9115. Daarna omvangrijke
  gewijzigde en nieuwe bron-/test-/feedbackbestanden in de werkboom; huidige
  implementatie is nog niet als één gereviewde/protected bronoplevering gesloten.
  Eerder bestaande vreemde projectkopieën en iPad-note blijven behouden.
-715 regressies waren eerder groen; daarop volgden kleinere gerichte wijzigingen
  en39output-/volumeregressies. Geen volledige finale suite over de complete
  huidige werkboom na alle laatste wijzigingen claimen. SDK-inputproef blijft
  eerlijk FAILED_ASSUMPTION (31-byteinput geaccepteerd); geen productscanner die
  daarop vertrouwt bestaat. Deze bevinding is naar API overgedragen.

## Benodigde afrondingsvolgorde

1. Maak Speech en Settings tot twee expliciete acceptatielijsten in dezelfde
   bestaande Apple-writer. Eerst de echte Core/HA-dev provider- en LAN-overdracht,
   dan de geïnstalleerde cross-device-/speech-/defaultmatrix en legacy-retirement.
2. Sluit dit af met één consistente finale bron/build/testreadback en normale
   onafhankelijke review/protected delivery. UI-fixbuilds apart van taakafsluiting.
3. Houd scanner als actieve producerafhankelijkheid bij de bestaande API-writer;
   doe de overblijvende native en fysieke scanneracceptatie na echte contractfreeze.
4. Geef Apple-native TTS een expliciete pickup binnen de al geselecteerde Speech/
   Settings-uitvoering na geldige opvolgingsadmission. Geen stilzwijgende start of
   afsluiting afleiden uit de opdrachtregistratie.

Er zijn dus vier open hoofdsporen met verschillende volwassenheid. We hebben
werkende deelopleveringen en toestelbuilds geleverd, maar geen vier integraal
geaccepteerde productopleveringen. De communicatie heeft die grens onvoldoende
zichtbaar gehouden; met name Speech/Settings bleven open terwijl AppAttest-onderzoek
en losse UI-fixes steeds nieuwe voortgangsberichten kregen.

Laneankers:
- Settings: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6214918011
- Definitief settings3/speech3: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6223987404
- Scanner: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6222786446
- Lokale Apple-TTS: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6231201049
- Uitvoeringshandoff: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6231305768
- Native AppAttest: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6231637013
- API-pickup: https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-6231685161
