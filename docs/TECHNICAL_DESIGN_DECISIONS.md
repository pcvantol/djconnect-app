# Technische designbeslissingen

Laatst bijgewerkt: 2026-06-14

Dit document is in eerste instantie reverse-engineered uit de codebase. Het legt
vast welke ontwerpkeuzes, codepatronen, conventies en dependencies op dit moment
feitelijk in de app aanwezig zijn. Bij iedere release moet dit document opnieuw
worden gecontroleerd en aangepast wanneer architectuur, platformversies,
dependencies, tooling of conventies wijzigen.

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
- Een standalone `LICENSE`-bestand.

## Architectuurkeuzes

### Gedeelde Swift Package-architectuur

De app is opgesplitst in twee gedeelde Swift targets:

- `DJConnectCore`: platformonafhankelijke contractmodellen, Keychain-opslag,
  API-contracten en basislogica.
- `DJConnectUI`: gedeelde SwiftUI UI, app-state, client-API hosting,
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

### Lokale Client API als bridge

iOS en macOS hosten een kleine lokale HTTP API voor pairing en statuscallbacks.
De app adverteert deze lokaal en Home Assistant gebruikt de URL om pairing af te
ronden. Runtime-verkeer van app naar Home Assistant blijft token-based en gebruikt
de lokale Home Assistant URL.

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

## Code-level design patterns

| Pattern | Waar zichtbaar | Waarom |
| --- | --- | --- |
| Layered modular architecture | `DJConnectCore`, `DJConnectUI`, `Apps/` | Scheidt contract/businesslogica, gedeelde UI en platform entrypoints. |
| MVVM / Observable app model | `DJConnectAppModel` als gedeelde UI-state owner | Centraliseert appstatus, backendinteracties en UI-reacties. |
| Declarative UI composition | SwiftUI views in `Sources/DJConnectUI` | Houdt iOS/macOS UI consistent en state-driven. |
| DTO / Codable contract models | Core/UI response- en requestmodellen | Maakt Home Assistant API-contracten expliciet en testbaar. |
| Gateway / API client | DJConnect command- en refresh-aanroepen via clientlaag | Isoleert HTTP, bearer-token headers, redactie en decodefouten. |
| Service adapters | Keychain, logging, local API, permissions, speech/audio, Bonjour | Houdt platform-API's buiten de viewlaag. |
| State machine UI | Pairing, unpaired, paired, stale, demo, connecting, unavailable | Maakt disabling, overlays, foutmeldingen en herstelpaden voorspelbaar. |
| Async/await concurrency | Netwerk, refresh, voice upload, file logging | Voorkomt blokkeren van de main thread en houdt UI responsief. |
| `@MainActor` UI isolation | Appmodel en UI-mutaties | Beschermt SwiftUI state tegen thread-races. |
| Conditional compilation | `#if os(iOS)`, `#if os(macOS)` | Eén gedeelde codebase met native platformgedrag. |
| Secure storage | Keychain wrappers in Core | Device-token staat niet in plain UserDefaults. |
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
- De public unsigned releaseflow publiceert app-release-notes ook als statische
  `.md` en `.json` bestanden naar `pcvantol/djconnect-website`, zodat de app
  `djconnect.dev/release-notes/{ios|macos}/vX.Y.Z.json` kan lezen zonder
  afhankelijk te zijn van anonieme GitHub API rate limits.

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

- `docs/postman/djconnect-local-device-api.postman_collection.json`
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
| DJConnect app code | iOS/macOS app, Core, UI en tooling | `MARKETING_VERSION` in `project.yml` | Proprietary; geen standalone `LICENSE` gevonden | <https://github.com/pcvantol/djconnect-app> |
| Swift | Programmeertaal en standaardbibliotheek | Swift tools 6.0, `SWIFT_VERSION` 6.0 | Apache License 2.0 met Runtime Library Exception | <https://github.com/swiftlang/swift> |
| Swift Package Manager | Module/build layout | Swift tools 6.0 | Apache License 2.0 | <https://www.swift.org/package-manager/> |
| Foundation | Data, URL, JSON, filesystem, dates | Apple SDK, iOS 26+/macOS 26+ | Apple SDK terms | <https://developer.apple.com/documentation/foundation> |
| SwiftUI | Gedeelde declaratieve UI | Apple SDK, iOS 26+/macOS 26+ | Apple SDK terms | <https://developer.apple.com/documentation/swiftui> |
| Combine | Publishers/subscriptions in appmodel/UI | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/combine> |
| UIKit | iOS platformbridges, haptics, pasteboard, app lifecycle | Apple SDK, iOS target | Apple SDK terms | <https://developer.apple.com/documentation/uikit> |
| AppKit | macOS platformbridges, windows, clipboard, app lifecycle | Apple SDK, macOS target | Apple SDK terms | <https://developer.apple.com/documentation/appkit> |
| AVFoundation | Audio playback/recording en speech/audio flows | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/avfoundation> |
| Speech | Speech recognition permission en wake phrase support | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/speech> |
| Network | Lokale HTTP listener en netwerkconstructies | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/network> |
| Security | Keychain tokenopslag | Apple SDK | Apple SDK terms | <https://developer.apple.com/documentation/security> |
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
| GitHub CLI (`gh`) | Release- en cleanup-scripts | Niet gepind in repo | MIT License | <https://github.com/cli/cli> |
| Apple notarytool | macOS notarization releaseflow | Xcode toolchain | Apple Developer tools terms | <https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution> |
| Postman collection | Handmatige lokale Client API-testdocumentatie | Collectionbestand in repo | Postman terms voor Postman-app/cloud; JSON zelf repo-documentatie | <https://www.postman.com/> |

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
- Werk de dependencytabel bij met versie/pin, licentie en source URL.
- Werk de design-patternsectie bij als nieuwe architectuur- of statepatronen
  worden toegevoegd.
- Werk de coding-style secties bij als SwiftLint, SwiftFormat of andere
  format/lint tooling wordt toegevoegd.
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
