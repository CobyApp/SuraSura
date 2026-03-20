import AVFoundation
import Foundation

// MARK: - Google Cloud Text-to-Speech Live
// REST API: https://texttospeech.googleapis.com/v1/text:synthesize
// 네팔어 포함 전 언어 지원, MP3 응답을 AVAudioPlayer로 재생

final class GoogleTTSClientLive: @unchecked Sendable {

    static let shared = GoogleTTSClientLive()

    private let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    // MARK: - Speak

    func speak(text: String, language: SupportedLanguage) async throws {
        stop()
        guard !text.isEmpty else { return }

        let audioData = try await synthesize(text: text, language: language)

        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)

        audioPlayer = try AVAudioPlayer(data: audioData)
        audioPlayer?.prepareToPlay()

        await withCheckedContinuation { continuation in
            audioPlayer?.play()
            // 재생 완료까지 polling (delegate 대신 간단하게 처리)
            Task {
                let duration = audioPlayer?.duration ?? 0
                if duration > 0 {
                    try? await Task.sleep(for: .seconds(duration + 0.2))
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Stop

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Google TTS REST API 호출

    private func synthesize(text: String, language: SupportedLanguage) async throws -> Data {
        guard var components = URLComponents(string: endpoint) else {
            throw TTSError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: APIKeys.googleCloud)]
        guard let url = components.url else { throw TTSError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": [
                "text": text
            ],
            "voice": [
                "languageCode": language.googleTTSCode,
                "ssmlGender": language.googleTTSGender,
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": 1.0,
                "pitch": 0.0,
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw TTSError.serverError
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let audioContent = json["audioContent"] as? String,
            let audioData = Data(base64Encoded: audioContent)
        else {
            throw TTSError.decodingError
        }

        return audioData
    }
}

// MARK: - Errors

enum TTSError: LocalizedError {
    case invalidURL
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:      return "TTS URL이 잘못됐습니다."
        case .serverError:     return "TTS 서버 오류가 발생했습니다."
        case .decodingError:   return "TTS 응답 디코딩에 실패했습니다."
        }
    }
}
