import Foundation

extension Bundle {
    /// 언어 코드에 맞는 lproj 번들 반환 (빈 문자열 = 시스템 기본값)
    static func localizedModule(language: String) -> Bundle {
        let lang = language.isEmpty
            ? (Locale.preferredLanguages.first ?? "ko")
            : language

        let lprojName: String
        if      lang.hasPrefix("ko")      { lprojName = "ko" }
        else if lang.hasPrefix("ja")      { lprojName = "ja" }
        else if lang.hasPrefix("zh-Hans") { lprojName = "zh-Hans" }
        else if lang.hasPrefix("zh_Hans") { lprojName = "zh-Hans" }
        else if lang.hasPrefix("zh")      { lprojName = "zh-Hans" }
        else if lang.hasPrefix("en")      { lprojName = "en" }
        else                              { lprojName = "ko" }

        guard
            let path = Bundle.module.path(forResource: lprojName, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return .module }
        return bundle
    }
}
