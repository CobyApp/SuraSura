import Foundation

/// ⚠️ 실제 키는 .xcconfig 또는 환경변수로 관리하세요. 절대 Git에 커밋하지 마세요!
enum APIKeys {
    static var googleCloud: String {
        guard let key = Bundle.main.infoDictionary?["GOOGLE_CLOUD_API_KEY"] as? String,
              !key.isEmpty else {
            assertionFailure("Google Cloud API Key가 설정되지 않았습니다. Info.plist를 확인하세요.")
            return ""
        }
        return key
    }
}
