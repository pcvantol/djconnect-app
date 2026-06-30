import Foundation

public enum DJConnectLocalization {
    public static let dutchLanguageCode = "nl"

    public static func localized(language: String, english: String, dutch: String) -> String {
        normalizedLanguageCode(language) == dutchLanguageCode ? dutch : english
    }

    public static func localized(locale: Locale = .current, english: String, dutch: String) -> String {
        localized(language: locale.language.languageCode?.identifier ?? "", english: english, dutch: dutch)
    }

    public static func preferredLanguageCode(_ preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let preferredLanguage = preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix(dutchLanguageCode) ? dutchLanguageCode : "en"
    }

    public static func normalizedLanguageCode(_ language: String) -> String {
        language
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init)?
            .lowercased() ?? ""
    }
}
