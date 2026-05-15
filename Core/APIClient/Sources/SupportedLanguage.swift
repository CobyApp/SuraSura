import Foundation

public enum SupportedLanguage: String, CaseIterable, Equatable, Sendable {
    case korean             = "ko"
    case english            = "en"
    case japanese           = "ja"
    case chineseSimplified  = "zh-CN"
    case chineseTraditional = "zh-TW"
    case spanish            = "es"
    case french             = "fr"
    case german             = "de"
    case italian            = "it"
    case portuguese         = "pt"
    case russian            = "ru"
    case arabic             = "ar"
    case dutch              = "nl"
    case turkish            = "tr"
    case vietnamese         = "vi"
    case indonesian         = "id"
    case thai               = "th"
    case polish             = "pl"
    case hindi              = "hi"
    case swedish            = "sv"

    // MARK: - Display

    public var displayName: String {
        switch self {
        case .korean:             return "한국어"
        case .english:            return "English"
        case .japanese:           return "日本語"
        case .chineseSimplified:  return "中文 (简体)"
        case .chineseTraditional: return "中文 (繁體)"
        case .spanish:            return "Español"
        case .french:             return "Français"
        case .german:             return "Deutsch"
        case .italian:            return "Italiano"
        case .portuguese:         return "Português"
        case .russian:            return "Русский"
        case .arabic:             return "العربية"
        case .dutch:              return "Nederlands"
        case .turkish:            return "Türkçe"
        case .vietnamese:         return "Tiếng Việt"
        case .indonesian:         return "Bahasa Indonesia"
        case .thai:               return "ภาษาไทย"
        case .polish:             return "Polski"
        case .hindi:              return "हिन्दी"
        case .swedish:            return "Svenska"
        }
    }

    // MARK: - BCP-47 (STT / Translation / TTS 공통)

    public var bcp47Code: String {
        switch self {
        case .korean:             return "ko-KR"
        case .english:            return "en-US"
        case .japanese:           return "ja-JP"
        case .chineseSimplified:  return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        case .spanish:            return "es-ES"
        case .french:             return "fr-FR"
        case .german:             return "de-DE"
        case .italian:            return "it-IT"
        case .portuguese:         return "pt-BR"
        case .russian:            return "ru-RU"
        case .arabic:             return "ar-SA"
        case .dutch:              return "nl-NL"
        case .turkish:            return "tr-TR"
        case .vietnamese:         return "vi-VN"
        case .indonesian:         return "id-ID"
        case .thai:               return "th-TH"
        case .polish:             return "pl-PL"
        case .hindi:              return "hi-IN"
        case .swedish:            return "sv-SE"
        }
    }

    /// STT용 Locale
    public var sttLocale: Locale {
        Locale(identifier: bcp47Code)
    }
}

extension SupportedLanguage {
    // MARK: - Flag Emoji

    public var flag: String {
        switch self {
        case .korean:             return "🇰🇷"
        case .english:            return "🇺🇸"
        case .japanese:           return "🇯🇵"
        case .chineseSimplified:  return "🇨🇳"
        case .chineseTraditional: return "🇹🇼"
        case .spanish:            return "🇪🇸"
        case .french:             return "🇫🇷"
        case .german:             return "🇩🇪"
        case .italian:            return "🇮🇹"
        case .portuguese:         return "🇧🇷"
        case .russian:            return "🇷🇺"
        case .arabic:             return "🇸🇦"
        case .dutch:              return "🇳🇱"
        case .turkish:            return "🇹🇷"
        case .vietnamese:         return "🇻🇳"
        case .indonesian:         return "🇮🇩"
        case .thai:               return "🇹🇭"
        case .polish:             return "🇵🇱"
        case .hindi:              return "🇮🇳"
        case .swedish:            return "🇸🇪"
        }
    }

    // MARK: - Short Name for UI

    public var shortName: String {
        switch self {
        case .korean:             return "한국어"
        case .english:            return "English"
        case .japanese:           return "日本語"
        case .chineseSimplified:  return "中文(简)"
        case .chineseTraditional: return "中文(繁)"
        case .spanish:            return "Español"
        case .french:             return "Français"
        case .german:             return "Deutsch"
        case .italian:            return "Italiano"
        case .portuguese:         return "Português"
        case .russian:            return "Русский"
        case .arabic:             return "العربية"
        case .dutch:              return "Nederlands"
        case .turkish:            return "Türkçe"
        case .vietnamese:         return "Việt"
        case .indonesian:         return "Indonesia"
        case .thai:               return "ไทย"
        case .polish:             return "Polski"
        case .hindi:              return "हिन्दी"
        case .swedish:            return "Svenska"
        }
    }
}

extension SupportedLanguage {
    // MARK: - Locale Identifier (for Locale API)

    public var localeIdentifier: String {
        switch self {
        case .korean:             return "ko"
        case .english:            return "en"
        case .japanese:           return "ja"
        case .chineseSimplified:  return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        case .spanish:            return "es"
        case .french:             return "fr"
        case .german:             return "de"
        case .italian:            return "it"
        case .portuguese:         return "pt"
        case .russian:            return "ru"
        case .arabic:             return "ar"
        case .dutch:              return "nl"
        case .turkish:            return "tr"
        case .vietnamese:         return "vi"
        case .indonesian:         return "id"
        case .thai:               return "th"
        case .polish:             return "pl"
        case .hindi:              return "hi"
        case .swedish:            return "sv"
        }
    }

    /// 현재 기기 언어 기준으로 언어 이름 반환 (하위 호환)
    public var localizedName: String {
        Locale.current.localizedString(forIdentifier: localeIdentifier) ?? displayName
    }

    /// 앱 언어 설정 기준으로 언어 이름 반환
    /// - Parameter appLanguage: store.appLanguage 값 (빈 문자열 = 기기 기본값)
    public func localizedName(in appLanguage: String) -> String {
        let locale: Locale
        if appLanguage.isEmpty {
            locale = Locale.current
        } else {
            let identifier = appLanguage.replacingOccurrences(of: "-", with: "_")
            locale = Locale(identifier: identifier)
        }
        return locale.localizedString(forIdentifier: localeIdentifier) ?? displayName
    }
}
