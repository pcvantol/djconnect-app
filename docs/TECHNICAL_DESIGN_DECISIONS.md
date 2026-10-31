# Technische designbeslissingen

## VibeCast product encryption preparation — 2026-10-20

The coordinated native integration reuses JOSESwift 3.0.0 at immutable source
c2664a902e75c0426a1d43132bd4babc6fd173d3, previously qualified separately with
API software interop. Both SwiftPM and Xcode pin the same revision. The product
uses only RSA-OAEP-256/A256GCM with the exact admitted browser JWK/thumbprint,
fixed protected header and closed destination payload. It never builds custom
OAEP/AES primitives or puts HA credentials/identity in the JWE. Native Legal
ships the upstream Apache 2.0 license. Software encryption/decryption tests are
separate from genuine App Attest, deployment and positive browser handoff.

## Brand V2 native adoption — 2026-10-20

Apple #138 consumes the immutable Core #1223 original headset assets after source
and separate Finalization. The app icon generator selects the frameless headset
through 40 output pixels and glass above that size. Runtime images preserve
producer alpha; native views do not add a second border. English wide layouts
use the primary wordmark; localized layouts use the compact wordmark with native
text, with native scalable fallbacks at narrow widths and large type. Producer
pins and Inter OFL provenance are recorded in `Tools/IconSource/BrandV2/README.md`.
This is presentation-only; Persona and backend contracts remain independent.

## Current Session controls and glass followup — 2026-10-12

Build40016 is local on `codex/apple-session-mood-toolbar`, based on reconciled main7900ec7. Toolbar mood/status popovers, bound End confirmation, top-right glyphs, native glass rendering and playback time labels are implemented across shared Apple UI. Full477-test run PASS; bounded native iPhone/iPad controls PASS. Physical scroll acceptance, final Mac screen proof, publication and40016 installation are pending; ordinary physical iPad/MacBook40015 remains installed. No Core/backend mutation or Store/HA release. See [current qualification](verification/SESSION_CONTROLS_GLASS_20261012.md). The previous sections below are historical delivery snapshots.


## Session header refinement — 2026-10-12

PR101 source-main03d02a40c4caa9b5d37c8767e49f87b88cf106a3 implements the owner-requested fixed music-left/DJ-right layout and compact full Spotify attribution. The shared native Layout measures unrestricted text heights while the existing pinned header may scroll. It changes no backend, authority, event, playback or conversation contract. Premerge CI and bounded native iPhone/iPad/Mac reviews PASS; source-main CI/coverage38210411713 and formal exact-SHA evidence38211003692 independently verified PASS; separate Finalization remains pending.473 reported general tests include8 gated skips. Product acceptance is PARTIAL; actual provider imagery/Spotify-runtime and XXXL/long-language are not inferred. Previous PR99/100 is completed, with separately approved ordinary40014 installed on iPad/MacBook;40015 is not installed. See [header evidence](verification/SESSION_HEADER_COLUMNS_20261012.md).


Laatst bijgewerkt: 2026-09-23

Dit document is in eerste instantie reverse-engineered uit de codebase. Het legt
vast welke ontwerpkeuzes, codepatronen, conventies en dependencies op dit moment
feitelijk in de app aanwezig zijn. Bij iedere release moet dit document opnieuw
worden gecontroleerd en aangepast wanneer architectuur, platformversies,
dependencies, tooling of conventies wijzigen.

## Gerichte Session/Demo-aanvulling — 2026-10-12

PR99/source-main0e0deed levert gedeelde native Session-presentatie voor iPhone,
iPad en Mac: actuele context vast, bijdragen nieuwst eerst, aparte spelerroute,
readonly archiefrijen met begin/eind/duur en guarded refresh, en een responsive
welkomsthero zolang geen Session actief is. Stemming blijft een backend-owned
revisiecontract; openen/navigeren veroorzaakt geen playback- of Sessionmutatie.

De expliciete lokale Demo-uitzondering gebruikt dezelfde typed decode/state/
render-modellen met voorbeeldsessies in geheugen. Geen Profile-authority of
gewone chat/widget-persistence; geen serververzoeken of microfoonopname/upload.
De voiceknop toont een herkenbaar vooraf geschreven voorbeeld. Decoratieve
vector-artwork heeft geen interactie/AX-inhoud; de titel schaalt met Dynamic Type.
Dit is een gerichte ontwerpaanvulling, geen nieuwe dependency-inventaris of
Store-release. Exacte bewijsgrenzen en nog voorwaardelijke Finalization:
[latest snapshot](history/prompts/2026-10-12-apple-session-ui-demo-welcome-finalization.md).

## Bronnen

- `Package.swift`: Swift package layout, Swift tools-versie, platform minima en
  package dependencies.
- `project.yml`: XcodeGen source of truth voor targets, bundle identifiers,
  deployment targets, Swift-versie, entitlements en Info.plist-instellingen.
- `Sources/`: gedeelde Core- en UI-implementatie.
- `Apps/`: dunne iOS- en macOS-app shells.
- `Tests/`: unit- en UI-testtargets.
- `Tools/` en `.github/workflows/`: release-, icon-, CI- en publicatie-tooling.
- `README.md`, `docs/ARCHITECTURE.md`, `docs/ARCHITECTURE_DECISIONS.md`,
  `docs/API_CONTRACT.md`, `docs/HANDOFF.md`, `docs/RELEASE.md` en
  `pcvantol/djconnect/SYNC_PROMPTS.md`: integratie- en releasecontracten.
- `pcvantol/djconnect/PRODUCT_ROADMAP.md`: canonical product roadmap.

Niet aangetroffen in de repo op 2026-06-14:

- `Package.resolved`, `Podfile`, `Cartfile`, `Package-lock`/`pnpm-lock` of
  vergelijkbare externe dependency lockfiles.
- `.swiftlint.yml` of `.swiftformat`.
- Een standalone `LICENSE`-bestand met de MIT License.

## Architectuurkeuzes

### Gedeelde Swift Package-architectuur

De app is opgesplitst in twee gedeelde Swift targets:

- `DJConnectCore`: platformonafhankelijke contractmodellen, app-tokenopslag,
  API-contracten en basislogica.
- `DJConnectUI`: gedeelde SwiftUI UI, app-state, Home Assistant transport,
  platformadaptatie, audio, speech, logging en featureflows.

De app targets `DJConnectIOS` en `DJConnectMac` zijn bewust dun. Ze initialiseren
vooral de native app lifecycle en hergebruiken de gedeelde Core/UI-modules. Deze
keuze beperkt divergentie tussen iOS, iPadOS en macOS en maakt contractwijzigingen
met Home Assistant op één plek onderhoudbaar.

### Home Assistant als backend authority

Home Assistant is de authority voor pairing, device-token lifecycle, Spotify
OAuth, playback commands, voice verwerking en status-sync. De app bewaart alleen
het door Home Assistant uitgegeven DJConnect device-token en geen Spotify tokens,
Home Assistant long-lived tokens of backend credentials.

Deze scheiding voorkomt dat Apple clients backendgeheimen hoeven te beheren en
houdt iOS/macOS gelijk aan andere DJConnect clients.

### Inbound-only Home Assistant pairing

iOS, macOS en watchOS hosten geen lokale HTTP API voor Home Assistant callbacks,
adverteren geen pairable Bonjour/mDNS-service en gebruiken geen lokale discovery
voor pairing. Pairing is uitsluitend client-geinitieerd: de Apple client post
naar `POST /api/djconnect/v1/pair` op de lokale Home Assistant URL die de setupflow
toont of via de QR/deep-link payload meegeeft.

iOS pairt primair via de Home Assistant QR/deep-link payload. macOS gebruikt
handmatige invoer van Home Assistant URL plus zescijferige code. watchOS pairt
via iPhone-proxy: de iPhone valideert de Watch QR/deep-link en geeft de gegevens
door aan de Watch; de Watch-identiteit blijft `client_type: "watchos"` met een
`djconnect-watchos-*` device ID, ook wanneer de iPhone de HTTP request proxiet.

Na succesvolle pairing bewaren de Apple clients alleen de DJConnect bearer token,
clientidentiteit, `ha_local_url`, optionele `ha_remote_url` en door Home
Assistant geadverteerde API paths/capabilities. Runtime-verkeer blijft
token-based en gebruikt de lokale Home Assistant URL eerst; iOS/macOS gebruiken
de optionele remote URL alleen als fallback na succesvolle lokale pairing.

Spotify source/default playlist overrides (`spotify_source` en
`liked_proxy_playlist_uri`) zijn geen clientinstellingen meer. De app toont deze
velden niet in setup, Settings of onboarding en blijft generieke playback-
commands naar Home Assistant sturen.

### Native SwiftUI-first UI

De UI is SwiftUI-first en wordt gedeeld tussen iOS/iPadOS/macOS met
platformspecifieke conditionele code waar dat nodig is. AppKit/UIKit worden alleen
gebruikt voor platformbridges zoals clipboard, open URL, app termination,
permissions, haptics en windowgedrag.

### Offline, demo en app-review modus

Demo mode is een expliciete lokale runtimevariant zonder destructieve backend
acties. Dit ondersteunt App Store review, lokale ontwikkeling en gebruikers die de
app willen bekijken voordat Home Assistant gekoppeld is.

### Release- en contractdiscipline

`pcvantol/djconnect/SYNC_PROMPTS.md` is de enige canonical cross-repo
contractbron. `pcvantol/djconnect/PRODUCT_ROADMAP.md` is de enige canonical
product roadmap. Deze repo houdt geen lokale kopie van `SYNC_PROMPTS.md` of
`PRODUCT_ROADMAP.md` bij. `docs/RELEASE.md` verplicht dat contractdocs, handoff,
README, TODO/issues en dit technische ontwerpdocument bij releases worden
bijgewerkt.

### Dual-Mac interne macOS-deployment

De Mac mini is de enige Apple build- en release-runner. Een goedgekeurd,
checksum-gebonden unsigned artefact wordt daar lokaal met de bestaande Apple
Development-identiteit ondertekend. Dezelfde ondertekende app wordt op de mini
en via SSH op de MacBook geïnstalleerd. Beide hosts controleren UUID,
bundelidentiteit, versie en handtekening; de MacBook controleert ook de hash
van het overgebrachte archief. De mini vertrouwt uitsluitend een vooraf
geverifieerde MacBook-hostsleutel. Elke host bewaart zijn vorige app onder een
run-specifieke herstelnaam. Er is geen runner of private signing key op de
MacBook nodig. De centrale manifestgoedkeuring blijft de release-authority;
zonder die goedkeuring vindt geen dual-host deployment plaats.

## Code-level design patterns

| Pattern | Waar zichtbaar | Waarom |
| --- | --- | --- |
| Layered modular architecture | `DJConnectCore`, `DJConnectUI`, `Apps/` | Scheidt contract/businesslogica, gedeelde UI en platform entrypoints. |
| MVVM / Observable app model | `DJConnectAppModel` als gedeelde UI-state owner | Centraliseert appstatus, backendinteracties en UI-reacties. |
| Declarative UI composition | SwiftUI views in `Sources/DJConnectUI` | Houdt iOS/macOS UI consistent en state-driven. |
| DTO / Codable contract models | Core/UI response- en requestmodellen | Maakt Home Assistant API-contracten expliciet en testbaar. |
| Gateway / API client | Pairing, command- en refresh-aanroepen via clientlaag | Isoleert HTTP, bearer-token headers, redactie en decodefouten. |
| Service adapters | App storage, logging, permissions, speech/audio, HA transport | Houdt platform-API's buiten de viewlaag. |
| State machine UI | Pairing, unpaired, paired, stale, demo, connecting, unavailable | Maakt disabling, overlays, foutmeldingen en herstelpaden voorspelbaar. |
| Async/await concurrency | Netwerk, refresh, voice upload, file logging | Voorkomt blokkeren van de main thread en houdt UI responsief. |
| `@MainActor` UI isolation | Appmodel en UI-mutaties | Beschermt SwiftUI state tegen thread-races. |
| Conditional compilation | `#if os(iOS)`, `#if os(macOS)` | Eén gedeelde codebase met native platformgedrag. |
| Token storage | App-private storage wrapper in Core | Device-token blijft lokaal en resetbaar zonder Keychain prompts. |
| Redacted diagnostics | Log export en rolling file logging | Debuggbaar zonder tokens of secrets te lekken. |
| Local fixture/demo data | Demo mode, games, UI-test flows | App Store review en testbaarheid zonder live Home Assistant. |

## Coding style conventions

### Swift

Bronnen:

- Swift tools-versie: `Package.swift` gebruikt `// swift-tools-version: 6.0`.
- Projectconfiguratie: `project.yml` gebruikt `SWIFT_VERSION: "6.0"`.
- Platform minima: `Package.swift` en `project.yml` targeten iOS 26.0 en macOS
  26.0.
- Taalconventies zijn gebaseerd op de officiële Swift API Design Guidelines:
  <https://www.swift.org/documentation/api-design-guidelines/>

Toegepaste conventies:

- Types, structs, classes, enums en protocols gebruiken `PascalCase`.
- Functies, properties, bindings en enum cases gebruiken `lowerCamelCase`.
- UI is opgebouwd uit kleine SwiftUI `View`-types en modifiers.
- Contracten gebruiken `Codable`/`Decodable` met optionele velden waar de Home
  Assistant API `null` mag teruggeven.
- Platformverschillen worden via `#if os(iOS)` en `#if os(macOS)` lokaal
  gehouden.
- Asynchrone flows gebruiken Swift concurrency (`async`/`await`, `Task`) in
  plaats van callbackketens, behalve waar Apple API's callbackgebaseerd zijn.
- Secrets worden niet gelogd; logging hoort geredigeerd te zijn.

Niet aangetroffen:

- Geen SwiftLint-configuratie.
- Geen SwiftFormat-configuratie.

Daarom zijn de Swift-conventies op dit moment compiler-, Xcode- en
code-review-gedreven in plaats van door een linter afgedwongen.

### YAML

Bronnen:

- `project.yml`: XcodeGen projectdefinitie.
- `.github/workflows/*.yml`: GitHub Actions CI- en unsigned releaseflows.

Conventies:

- Projectinstellingen worden in `project.yml` gedeclareerd en niet handmatig als
  primaire bron in het Xcode project onderhouden.
- Workflowstappen zijn expliciet benoemd en scheiden CI van public unsigned
  releasepublicatie.
- De firmware-CodeQL-workflow houdt `init`, `autobuild` en `analyze` samen op
  CodeQL Action `4.39.0`, telkens gepind op dezelfde immutable commit.
- De TDE-observatieworkflow maakt in `RUNNER_TEMP` een geïsoleerde Python 3.11-
  venv met `-S`, zodat de TDE-runtime niet blokkeert op of schrijft naar de
  gedeelde PlatformIO-Pythonomgeving van de self-hosted Apple-runner.
- De TestFlight beta workflow is `workflow_dispatch`-only, gebruikt de
  beschermde GitHub Environment `testflight-beta`, vereist expliciete
  `version`/`tag`/`UPLOAD_TESTFLIGHT` invoer, en mag geen automatische
  push/tag-trigger krijgen.
- De public unsigned releaseflow publiceert app-release-notes ook als statische
  `.md` en `.json` bestanden naar `pcvantol/djconnect-website`, zodat de app
  `djconnect.dev/release-notes/{ios|macos}/{en|nl|de|fr|es}/vX.Y.Z.json` kan lezen op
  basis van de gekozen app-taal, met de oude platform-only URL als fallback en
  zonder afhankelijk te zijn van anonieme GitHub API rate limits.

### Shell

Bronnen:

- `release.sh`
- `cleanup_old_releases.sh`
- `Tools/release/*.sh`

Conventies:

- Release- en cleanup-scripts gebruiken shell scripting als automation layer rond
  `xcodebuild`, `gh`, notarization en artifactpublicatie.
- `release.sh` voert na een geslaagde release standaard
  `cleanup_old_releases.sh --keep 1 --keep-workflow-runs 1 --execute` uit,
  zodat oude source releases/tags en oude GitHub Actions runs niet blijven
  stapelen.
- Scripts moeten idempotent zijn waar praktisch en duidelijke environment
  variables gebruiken voor signing/notarization.

### JSON en plist

Bronnen:

- `Tools/release/ExportOptions-macOS.plist`
- gegenereerde Info.plist-fragmenten uit `project.yml`

Conventies:

- JSON wordt gebruikt voor externe API- en toolingcontracten.
- Plist-configuratie blijft beperkt tot Apple build/export metadata en
  Info.plist-permissies.

### Markdown

Bronnen:

- `README.md`
- `CHANGELOG.md`
- `pcvantol/djconnect/SYNC_PROMPTS.md`
- `docs/*.md`

Conventies:

- Product- en handoffdocumentatie is primair Nederlandstalig.
- Cross-repo contracten horen in `pcvantol/djconnect/SYNC_PROMPTS.md`.
- Release-informatie hoort per release behouden te blijven en niet tot één
  samengestelde sectie te worden samengevoegd.

## Frameworks, libraries en third-party dependencies

Deze lijst is gebaseerd op imports, projectconfiguratie en toolingbestanden in de
repo. Apple SDK-frameworks vallen onder de Apple Developer Program License
Agreement en de bijbehorende SDK-voorwaarden. Waar de repo geen exacte toolversie
vastlegt, staat "niet gepind".

| Component | Gebruik | Versie / pin in repo | Licentie / voorwaarden | Source |
| --- | --- | --- | --- | --- |
| DJConnect app code | iOS/macOS/watchOS app, Core, UI en tooling | `MARKETING_VERSION` in `project.yml` | MIT License | <https://github.com/pcvantol/djconnect-app> |
| Swift | Programmeertaal en standaardbibliotheek | Swift tools 6.0, `SWIFT_VERSION` 6.0 | Apache License 2.0 met Runtime Library Exception | <https://github.com/swiftlang/swift> |
| Swift Package Manager | Module/build layout | Swift tools 6.0 | Apache License 2.0 | <https://www.swift.org/package-manager/> |
| Foundation | Data, URL, JSON, filesystem, dates | Apple SDK, iOS 26+/macOS 26+ | Apple SDK terms | <https://developer.apple.com/documentation/foundation> |
| SwiftUI | Gedeelde declaratieve UI | Apple SDK, iOS 26+/macOS 26+ | Apple SDK terms | <https://developer.apple.com/documentation/swiftui> |
| Combine | Publishers/subscriptions in appmodel/UI | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/combine> |
| UIKit | iOS platformbridges, haptics, pasteboard, app lifecycle | Apple SDK, iOS target | Apple SDK terms | <https://developer.apple.com/documentation/uikit> |
| AppKit | macOS platformbridges, windows, clipboard, app lifecycle | Apple SDK, macOS target | Apple SDK terms | <https://developer.apple.com/documentation/appkit> |
| MetalKit | GPU-rendering voor de Track Insight visualizer op iOS en macOS | Apple SDK, iOS/macOS targets | Apple SDK terms | <https://developer.apple.com/documentation/metalkit> |
| AVFoundation | Audio playback/recording en speech/audio flows | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/avfoundation> |
| Speech | Speech recognition permission en wake phrase support | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/speech> |
| Network | Lokale HTTP listener en netwerkconstructies | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/network> |
| Storage | App-private tokenopslag | Apple Foundation | Apple SDK terms | <https://developer.apple.com/documentation/foundation/userdefaults> |
| OSLog | Platform logging | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/os/logging> |
| Darwin | Platform/system calls en conditional utilities | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/darwin> |
| CoreGraphics | Icon/tool image processing | Apple SDK, tooling only | Apple SDK terms | <https://developer.apple.com/documentation/coregraphics> |
| ImageIO | Icon/tool image IO | Apple SDK, tooling only | Apple SDK terms | <https://developer.apple.com/documentation/imageio> |
| UniformTypeIdentifiers | Icon/tool file type handling | Apple SDK, tooling only | Apple SDK terms | <https://developer.apple.com/documentation/uniformtypeidentifiers> |
| XCTest | Unit/UI test framework | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/xctest> |
| Swift Testing | Nieuwe Swift test imports waar gebruikt | Apple SDK / Swift toolchain | Apple/Swift toolchain terms | <https://developer.apple.com/xcode/swift-testing/> |
| Xcode / xcodebuild | Project build, archive, test, signing | Niet gepind in repo | Apple Developer tools terms | <https://developer.apple.com/xcode/> |
| XcodeGen | Genereert Xcode project uit `project.yml` | Niet gepind in repo | MIT License | <https://github.com/yonaskolb/XcodeGen> |
| GitHub Actions | CI en unsigned public release artifacts | Workflowversies niet centraal gepind | GitHub Terms of Service | <https://github.com/features/actions> |
| GitHub CodeQL Action | C/C++ security analysis voor tracked firmware source | `4.39.0` (`6f2ac81f5cd81fe351a197ba0b00d91d03cd2aee`) | Upstream license en notices | <https://github.com/github/codeql-action> |
| GitHub CLI (`gh`) | Release- en cleanup-scripts | Niet gepind in repo | MIT License | <https://github.com/cli/cli> |
| Apple notarytool | macOS notarization releaseflow | Xcode toolchain | Apple Developer tools terms | <https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution> |

Er zijn op basis van `Package.swift` geen externe runtime Swift packages
gedeclareerd (`dependencies: []` en `packages: {}` in `project.yml`).

## Release-onderhoud

Bij iedere release moet deze checklist worden uitgevoerd:

- Controleer of `Package.swift` of `project.yml` platformversies, Swift-versie,
  bundle identifiers, entitlements of dependencies wijzigen.
- Controleer imports in `Sources/`, `Apps/`, `Tests/` en `Tools/` op nieuwe
  Apple frameworks of third-party libraries.
- Controleer `.github/workflows/`, `Tools/` en release scripts op nieuwe
  toolingdependencies.
- Controleer dat publicatieflows die signed builds, TestFlight uploads,
  notarization of publieke artifacts maken handmatig of expliciet gated blijven
  en hun vereiste GitHub Environment/secrets documenteren zonder secretwaarden.
- Werk de dependencytabel bij met versie/pin, licentie en source URL.
- Werk de design-patternsectie bij als nieuwe architectuur- of statepatronen
  worden toegevoegd.
- Werk de coding-style secties bij als SwiftLint, SwiftFormat of andere
  format/lint tooling wordt toegevoegd.
- Werk `CHAT_BOOTSTRAP.md` bij met de actuele release-, workflow- en
  repository-status.
- Controleer AI-assisted development/security hygiene: geen secrets,
  private data, private URLs, raw diagnostics, screenshots met gevoelige inhoud
  of proprietary third-party materiaal in prompts, logs, issues, fixtures,
  release notes of commits.
- Bij cross-repo contractwijzigingen moet
  `pcvantol/djconnect/SYNC_PROMPTS.md` worden bijgewerkt.
- Bij product roadmap-wijzigingen moet
  `pcvantol/djconnect/PRODUCT_ROADMAP.md` worden bijgewerkt.
- Als de wijziging vanuit deze repo komt, maak dan een follow-up
  wijziging/commit in `pcvantol/djconnect`.
- Houd geen lokale kopie van `SYNC_PROMPTS.md` of `PRODUCT_ROADMAP.md` in deze
  repo.
- Oude losse promptbestanden blijven verboden.
- Controleer dat `docs/HANDOFF.md`, `docs/RELEASE.md`,
  `docs/ARCHITECTURE_DECISIONS.md` en `CHANGELOG.md` dezelfde release- en
  contractlijn beschrijven.


## 2026-10-31: Parallel client validation and independent discovery reads

Independent simulated client runtimes receive task-scoped transport pools and
App Attest sequencing, without changing the shared production default or the
limits inside one runtime. Child tasks retain the same runtime. Fixture cases
are bounded at eight; the AppKit key window is an exclusive test resource.
Service-boundary gates replace guessed response timing in affected race tests.
The dispatch regression observes the actual synchronous resume boundary rather
than relying on Foundation publishing `URLSessionTask.state` immediately; the
original final-state and wire assertions remain.

CI keeps dependency/tool mutation before validation. Independent checks, Swift
packages and unsigned platform builds use bounded worker groups with distinct
logs/build roots; a failed child cannot be hidden by another child's success.
Post-merge native coverage waits for normal CI and uses its own output root.

A proposed Discovery read parallelization was rejected in source review: both
reads share a real WebSocket negotiation/result reader which does not yet have
single-flight or exchange exclusion. Its mock-only overlap proof was insufficient.
The shipping app method is restored exactly to the protected baseline. Fixing and
causally testing the real shared adapter is a separate next increment; no new
product protocol concurrency is adopted here. Settings, commands, consent, key
generation and operation receipts retain their existing ordered dependencies.
Backend-owned intelligence, contracts and push admission are unchanged.

### Foreground settings read custody (2026-10-31)

Parallel qualification exposed an AppModel lifecycle race independently of the
Core settings reducer. Replace the wrapper Boolean with an owner/context-scoped
request UUID, invalidate it on suspension/pairing/owner change, and release it
only if still owned by that request. Validate responses before reducer admission
and follow-up; validation itself must never rebind withdrawn authority. A current
authority failure reconciles native surface retirement without positive work.
Held real URLProtocol requests cover old/new ordering, coalescing, owner ABA and
401 withdrawal. Durable settings and permission remain backend-owned.
