import Foundation

// MARK: - Google STT REST API
// 네팔어 등 Apple Speech 미지원 언어용 배치 인식

enum GoogleSTTRestClient {

    private static let endpoint = "https://speech.googleapis.com/v1/speech:recognize"

    static func recognize(
        audioData: Data,
        language: SupportedLanguage,
        sampleRate: Int,
        apiKey: String
    ) async throws -> String? {

        guard var components = URLComponents(string: endpoint) else {
            throw STTRestError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            throw STTRestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "config": [
                "encoding": "LINEAR16",
                "sampleRateHertz": sampleRate,
                "languageCode": language.googleSpeechCode,
                "enableAutomaticPunctuation": true,
            ],
            "audio": [
                "content": audioData.base64EncodedString()
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw STTRestError.serverError
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = json["results"] as? [[String: Any]],
            let alternatives = results.first?["alternatives"] as? [[String: Any]],
            let transcript = alternatives.first?["transcript"] as? String
        else { return nil }

        return transcript
    }
}

// MARK: - Errors

enum STTRestError: LocalizedError {
    case invalidURL
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidURL:    return "STT REST URL이 잘못됐습니다."
        case .serverError:   return "STT 서버 오류가 발생했습니다."
        }
    }
}
