import Foundation

extension Bundle {
    /// 언어 코드에 맞는 lproj 번들 반환 (빈 문자열 = 시스템 기본값)
    ///
    /// 지원 언어: ko, ja, zh-Hans, en
    /// 미지원 언어의 경우 en 로케일로 폴백합니다.
    static func localizedModule(language: String) -> Bundle {
        // 빈 문자열이면 기기 선호 언어 사용, 그것도 없으면 "en" 폴백
        let lang = language.isEmpty
            ? (Locale.preferredLanguages.first ?? "en")
            : language

        let lprojName: String
        if      lang.hasPrefix("ko")      { lprojName = "ko" }
        else if lang.hasPrefix("ja")      { lprojName = "ja" }
        else if lang.hasPrefix("zh-Hans") { lprojName = "zh-Hans" }
        else if lang.hasPrefix("zh_Hans") { lprojName = "zh-Hans" }
        else if lang.hasPrefix("zh")      { lprojName = "zh-Hans" }
        else if lang.hasPrefix("en")      { lprojName = "en" }
        else                              { lprojName = "en" }  // 미지원 → 영어 폴백

        guard
            let path = Bundle.module.path(forResource: lprojName, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return .module }
        return bundle
    }
}
