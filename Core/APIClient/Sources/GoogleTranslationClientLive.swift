import Foundation

enum GoogleTranslationClientLive {

    private static let baseURL = "https://translation.googleapis.com/language/translate/v2"

    static func translate(
        text: String,
        targetLanguage: SupportedLanguage,
        apiKey: String
    ) async throws -> String {

        guard var components = URLComponents(string: baseURL) else {
            throw TranslationError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "q": text,
            "target": targetLanguage.googleTranslationCode,
            "format": "text"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TranslationError.serverError
        }

        let decoded = try JSONDecoder().decode(GoogleTranslationResponse.self, from: data)

        guard let translated = decoded.data.translations.first?.translatedText else {
            throw TranslationError.emptyResponse
        }

        return translated
    }
}

// MARK: - Response Models

private struct GoogleTranslationResponse: Decodable {
    let data: TranslationData

    struct TranslationData: Decodable {
        let translations: [Translation]
    }

    struct Translation: Decodable {
        let translatedText: String
    }
}

// MARK: - Errors

enum TranslationError: LocalizedError {
    case invalidURL
    case serverError
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:     return "잘못된 URL입니다."
        case .serverError:    return "서버 오류가 발생했습니다."
        case .emptyResponse:  return "번역 결과가 없습니다."
        }
    }
}
