# Mac-pairing: geaccepteerd verzoek, afgebroken completion — 17 oktober 2026

Owner meldt pairingfailure met Swift.CancellationError1 op het setupscherm.
Bestaande bronwriter/HEAD4fa9115 en WIP behouden; geen tweede writer/Corewijziging.
Op macmini-m6 draait gewone40266. Een echte lokale containerlog van vandaag toont
pairPOST geaccepteerd om14:13:33 en onverwachte CancellationError om14:13:54.
Dit is een passende echte foutobservatie; het screenshot is nog niet aan deze
host bevestigd. MacBooknaam niet bereikbaar; targetvraag staat bij de owner open.

Het completionpad gebruikte dezelfde history-epochfence als privé Sessionreads.
Een onafhankelijke history/UI-suspension kon daardoor een geldige statusrespons
laten afwijzen met CancellationError. Die belandde in de zichtbare pairingmelding;
de afgeronde Taskreferentie bleef bovendien staan, zodat resume/retry niet opnieuw
kon starten. Alleen de melding verbergen zou de gestrande pairing niet herstellen.

40274:
- Completion gebruikt eigen accepted-token/installatie/device/config-/operationfence;
  history-epoch blijft verplicht voor gewone gepaarde Session/statusreads.
- Tijdelijke transportannulering herhaalt alleen de statusread met de bestaande
 2/3/5s-cadans. Geen herhaling van de effectvolle pairPOST, tokenreset of appsecret.
- Een echte cancellation/nieuwe operatie/tokenwisseling/URL-/installatiewijziging
  kan een late respons niet meer tot pairing-success maken. Actuele taakdefer
  ruimt haar eigen referentie op; oude taken mogen nieuwe pendingstaat niet wissen.
- Expliciete terminale credentialweigering stopt; pending-knop hervat de bestaande
  completioncontrole in plaats van een tweede pairPOST. Client controleert
  cancellation vóór het bewaren van een nieuw pairtoken.
- Onverwachte fouten blijven in privédiagnostiek; UI gebruikt bestaande vertaalde
  pairingtekst, geen Swift/Foundation-exceptie.

62gerichte pairing-/hersteltestsPASS29.493s, inclusief vier nieuwe tests:
conversation-epochwisseling, geannuleerde transportread→success, late token- en
operatievervanging, en echte401zonderretry. Dit zijn deterministische fixtures,
geen nieuwe liveMacpairing-PASS. Signed gewone nativeMac40274, strictdeep signature,
79manifestentries en bron/stagehashesPASS. Geen nieuwe volledige regressieclaim.

Installatie nog NIET uitgevoerd. Normale quit op de Macmini meldt appcancellation
(-128); PID13998/40266 blijft draaien. MacBooknaam niet resolveerbaar. Owner moet
getroffen Mac bevestigen en de betreffende app volledig afsluiten/toegankelijk
maken. Geen geforceerde beëindiging, credentialkopie, handmatige tokenverwijdering,
nieuwe usercode of afgeboekte liveacceptatie. Kandidaat/herstelkopieën bewaard.

De experimentele iOSlaunchscreen40273 is apart en niet geïnstalleerd; deze
Mac40274 bevat geen iOSlaunchscreenwijziging. Bestaande iPad40272 blijft behouden.
Privébewijs:pairing40274-original-*-filtered.log, targeted-tests.log, mac-build.log,
mac-receipt.json, source.json en install-blocker.json in bestaande private-map.

[Apple-lanereadback](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6235148314), exacte body bevestigd.
