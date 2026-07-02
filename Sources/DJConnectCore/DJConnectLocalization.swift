import Foundation

public enum DJConnectLocalization {
    public static let supportedLanguageCodes = ["en", "nl", "de", "fr", "es"]
    public static let englishLanguageCode = "en"
    public static let appLanguageOverrideDefaultsKey = "DJConnectAppLanguageOverride"
    public static let appGroupIdentifier = "group.dev.djconnect"

    public static func localized(key: String, arguments: CVarArg...) -> String {
        localizedFormat(
            key: key,
            language: defaultDisplayLanguageCode(),
            arguments: arguments
        )
    }

    public static func localized(key: String, language: String, arguments: CVarArg...) -> String {
        localizedFormat(key: key, language: language, arguments: arguments)
    }

    private static func localizedFormat(key: String, language: String, arguments: [CVarArg]) -> String {
        let code = supportedLanguageCode(language)
        let format = resourceValue(forKey: key, languageCode: code) ?? key
        guard !arguments.isEmpty else {
            return format
        }
        return String(format: format, locale: Locale(identifier: code), arguments: arguments)
    }

    public static func preferredLanguageCode(_ preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let preferredLanguage = preferredLanguages.first?.lowercased() ?? ""
        return supportedLanguageCode(preferredLanguage)
    }

    public static func supportedLanguageCode(_ language: String) -> String {
        let normalized = normalizedLanguageCode(language)
        return supportedLanguageCodes.contains(normalized) ? normalized : englishLanguageCode
    }

    public static func languageOverrideCode(_ value: String?) -> String {
        let normalized = normalizedLanguageCode(value ?? "")
        return supportedLanguageCodes.contains(normalized) ? normalized : ""
    }

    public static func resolvedLanguageCode(override overrideCode: String?, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let override = languageOverrideCode(overrideCode)
        return override.isEmpty ? preferredLanguageCode(preferredLanguages) : override
    }

    public static func defaultDisplayLanguageCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let sharedOverride = UserDefaults(suiteName: appGroupIdentifier)?
            .string(forKey: appLanguageOverrideDefaultsKey)
        return resolvedLanguageCode(override: sharedOverride, preferredLanguages: preferredLanguages)
    }

    public static func nativeLanguageName(for languageCode: String) -> String {
        switch supportedLanguageCode(languageCode) {
        case "nl":
            return "Nederlands"
        case "de":
            return "Deutsch"
        case "fr":
            return "Français"
        case "es":
            return "Español"
        default:
            return "English"
        }
    }

    public static func bcp47LocaleIdentifier(for language: String) -> String {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("-") || trimmed.contains("_") {
            let normalized = trimmed.replacingOccurrences(of: "_", with: "-")
            let parts = normalized.split(separator: "-", maxSplits: 1).map(String.init)
            if parts.count == 2, supportedLanguageCodes.contains(parts[0].lowercased()) {
                return "\(parts[0].lowercased())-\(parts[1].uppercased())"
            }
        }
        switch supportedLanguageCode(language) {
        case "nl":
            return "nl-NL"
        case "de":
            return "de-DE"
        case "fr":
            return "fr-FR"
        case "es":
            return "es-ES"
        default:
            return "en-US"
        }
    }

    public static func normalizedLanguageCode(_ language: String) -> String {
        language
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init)?
            .lowercased() ?? ""
    }

    private static func resourceValue(forKey key: String, languageCode: String) -> String? {
        localizedBundle(for: languageCode)?
            .localizedString(forKey: key, value: nil, table: "Localizable")
            .nilIfSame(as: key)
    }

    private static func localizedBundle(for languageCode: String) -> Bundle? {
        for bundle in localizationCandidateBundles {
            if let path = bundle.path(
                forResource: languageCode,
                ofType: "lproj",
                inDirectory: "Localization"
            ) {
                return Bundle(path: path)
            }
            if let path = bundle.path(forResource: languageCode, ofType: "lproj") {
                return Bundle(path: path)
            }
            if let path = bundle.path(forResource: languageCode, ofType: "lproj", inDirectory: "Resources/Localization") {
                return Bundle(path: path)
            }
        }
        return nil
    }

    private static var localizationCandidateBundles: [Bundle] {
        var bundles = [resourceBundle, Bundle.main]
        bundles.append(contentsOf: Bundle.allFrameworks.filter { bundle in
            bundle.bundleIdentifier?.contains("DJConnectCore") == true
                || bundle.bundleURL.lastPathComponent == "DJConnectCore.framework"
        })
        return bundles.reduce(into: []) { uniqueBundles, bundle in
            guard !uniqueBundles.contains(where: { $0.bundleURL == bundle.bundleURL }) else {
                return
            }
            uniqueBundles.append(bundle)
        }
    }

    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle(for: DJConnectLocalizationBundleToken.self)
        #endif
    }

}

private final class DJConnectLocalizationBundleToken {}

private extension String {
    func nilIfSame(as fallback: String) -> String? {
        self == fallback ? nil : self
    }
}
