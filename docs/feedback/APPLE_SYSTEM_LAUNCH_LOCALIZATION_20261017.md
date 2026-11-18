# Eerste statische iPadOS-opstartscherm — 17 oktober 2026

Owner meldt Engelse tagline vóór de echte gelokaliseerde app-launchview en vraagt
om selectie van een van vijf statische taalvarianten. Bestaande40272 bundelt een
root-level LaunchScreen.storyboardc naast losse vertaalde strings. Xcode projecteert
die als twee verschillende resources; de oude taglinevalidator controleerde alleen
bronwaarden en miste deze verpakking.

Kandidaat40273 verplaatst de bestaande storyboard naar Base.lproj. XcodeGen maakt
nu één variantgroep met Base plus vijf companionstrings; echte ibtool-invocatie
bevestigt de vijf companionbestanden. De uitgebreide validator faalt op het oude
40272-bundlepad en slaagt op de nieuwe nativeapp met alle vijf werkelijke teksten.
1255sleutels en signed gewone nativeiOS40273 inclusiefWatch/widgets/signaturePASS.
De eerste bundlecheck las ibtool-strings onterecht met plistlib; hersteld met Apple's
plutil-parser voor zowel strings-encoding als binaryplist. Geen Swiftgedrag gewijzigd.

Dit is alleen verpakking, geen bewezen taalkeuze door SpringBoard. Apple's actuele
[Launching-richtlijn](https://developer.apple.com/design/human-interface-guidelines/launching)
waarschuwt expliciet tegen tekst op dit systeemscherm omdat die niet wordt gelokaliseerd.
Er is geen geïnstalleerde simulatorruntime op deze host. Geen simulator of apparaat-
PASS geclaimd en geen runtime gedownload. Kandidaat niet geïnstalleerd. GewoneiPad40272,
iPhone40267, Mac40266 en alle bestaande WIP blijven behouden.

Ownerkeuze gevraagd: taalneutraal logo/DJConnect in eerste systeemframe, met tagline
in vijf talen zodra de app zelf draait; of de vijf gekoppelde varianten als experiment
behouden en werkelijk toetsen. Afhankelijke installatie blijft in afwachting van de
antwoordkeuze. Geen willekeurige app-/OS-taalwijziging of handmatige snapshotcleanup.

Privé:launch40273-ios-build.log, old-bundle-regression.log, ios-receipt.json en
source.json in bestaande qualification-map; exacte gewone kandidaat apart bewaard.
