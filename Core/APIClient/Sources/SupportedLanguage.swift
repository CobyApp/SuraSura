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
    case nepali             = "ne"

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
        case .nepali:             return "नेपाली"
        }
    }

    // MARK: - Apple Speech STT (nil = 미지원 → Google REST fallback)

    public var appleSpeechLocale: Locale? {
        switch self {
        case .korean:             return Locale(identifier: "ko-KR")
        case .english:            return Locale(identifier: "en-US")
        case .japanese:           return Locale(identifier: "ja-JP")
        case .chineseSimplified:  return Locale(identifier: "zh-Hans")
        case .chineseTraditional: return Locale(identifier: "zh-Hant")
        case .spanish:            return Locale(identifier: "es-ES")
        case .french:             return Locale(identifier: "fr-FR")
        case .german:             return Locale(identifier: "de-DE")
        case .italian:            return Locale(identifier: "it-IT")
        case .portuguese:         return Locale(identifier: "pt-BR")
        case .russian:            return Locale(identifier: "ru-RU")
        case .arabic:             return Locale(identifier: "ar-SA")
        case .dutch:              return Locale(identifier: "nl-NL")
        case .turkish:            return Locale(identifier: "tr-TR")
        case .vietnamese:         return Locale(identifier: "vi-VN")
        case .indonesian:         return Locale(identifier: "id-ID")
        case .thai:               return Locale(identifier: "th-TH")
        case .polish:             return Locale(identifier: "pl-PL")
        case .swedish:            return Locale(identifier: "sv-SE")
        case .hindi:              return nil  // 불안정 → Google REST
        case .nepali:             return nil  // 미지원 → Google REST
        }
    }

    // MARK: - Google STT / Translation

    public var googleSpeechCode: String      { rawValue }
    public var googleTranslationCode: String { rawValue }

    // MARK: - Google TTS

    public var googleTTSCode: String {
        switch self {
        case .korean:             return "ko-KR"
        case .english:            return "en-US"
        case .japanese:           return "ja-JP"
        case .chineseSimplified:  return "cmn-CN"
        case .chineseTraditional: return "cmn-TW"
        case .spanish:            return "es-ES"
        case .french:             return "fr-FR"
        case .german:             return "de-DE"
        case .italian:            return "it-IT"
        case .portuguese:         return "pt-BR"
        case .russian:            return "ru-RU"
        case .arabic:             return "ar-XA"
        case .dutch:              return "nl-NL"
        case .turkish:            return "tr-TR"
        case .vietnamese:         return "vi-VN"
        case .indonesian:         return "id-ID"
        case .thai:               return "th-TH"
        case .polish:             return "pl-PL"
        case .hindi:              return "hi-IN"
        case .swedish:            return "sv-SE"
        case .nepali:             return "ne-NP"  // ✅ Google TTS 지원!
        }
    }

    public var googleTTSGender: String {
        switch self {
        case .korean, .japanese, .french, .italian,
             .vietnamese, .thai, .indonesian, .nepali:
            return "FEMALE"
        default:
            return "NEUTRAL"
        }
    }
}
