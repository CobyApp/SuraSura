# 온디바이스 전환 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SuraSura 앱에서 모든 Google Cloud API 의존성을 제거하고, STT/번역/TTS를 모두 iOS 온디바이스 프레임워크로 전환한다.

**Architecture:** Apple `SFSpeechRecognizer`(on-device) + Apple `Translation` framework(`TranslationSession`) + `AVSpeechSynthesizer`. TCA `@DependencyClient` 패턴은 유지하고 `liveValue`를 통째로 교체. Apple Translation은 SwiftUI `.translationTask` modifier가 유일한 진입점이므로, View가 보유한 `TranslationSession`을 `@MainActor` 싱글톤 `TranslationBridge`를 통해 Reducer 쪽 dependency에 위임한다.

**Tech Stack:** Swift 5.9 / iOS 18.0 / SwiftUI / TCA(swift-composable-architecture) / Tuist / Apple Speech / Apple Translation / AVFAudio.

**관련 문서:** [디자인 문서](../specs/2026-05-15-on-device-migration-design.md)

---

## 파일 구조 (변경 전후)

```
Core/APIClient/Sources/
  ├─ SupportedLanguage.swift      [수정]
  ├─ TTSClient.swift              [수정 — liveValue만 교체]
  ├─ SpeechClient.swift           [신규]
  ├─ SpeechClientLive.swift       [신규]
  ├─ TranslationClient.swift      [신규]
  ├─ TranslationBridge.swift      [신규]
  ├─ AppleTTSClientLive.swift     [신규]
  ├─ APIKeys.swift                [삭제]
  ├─ GoogleSpeechClient.swift     [삭제]
  ├─ GoogleSpeechClientLive.swift [삭제]
  ├─ GoogleSTTRestClient.swift    [삭제]
  ├─ GoogleTranslationClient.swift     [삭제]
  ├─ GoogleTranslationClientLive.swift [삭제]
  └─ GoogleTTSClientLive.swift    [삭제]

Features/
  ├─ SpeechRecognition/Sources/SpeechRecognitionFeature.swift   [수정]
  ├─ Translation/Sources/TranslationFeature.swift                [수정]
  └─ Home/Sources/HomeFeature.swift                              [수정]
  └─ Home/Sources/HomeView.swift                                 [수정]

루트:
  ├─ Project.swift                [수정]
  └─ Secrets.xcconfig             [삭제 — 로컬, gitignored]
```

---

## 빌드/검증 명령어 (공통)

전 task에서 반복적으로 사용:

```bash
# 프로젝트 재생성
tuist generate --no-open

# iOS 시뮬레이터용 빌드
xcodebuild \
  -workspace SuraSura.xcworkspace \
  -scheme SuraSura \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build 2>&1 | tail -30
```

성공 시 `** BUILD SUCCEEDED **` 출력.

---

### Task 1: Project.swift — deployment target과 Secrets 참조 제거

**Files:**
- Modify: `Project.swift:7` (deploymentTarget)
- Modify: `Project.swift:23-42` (appSettings)
- Modify: `Project.swift:70-78` (infoPlist GOOGLE_CLOUD_API_KEY)

- [ ] **Step 1: deployment target을 iOS 18.0으로 변경**

`Project.swift` 7번 라인을 다음과 같이 수정.

```swift
let deploymentTarget = DeploymentTargets.iOS("18.0")
```

- [ ] **Step 2: appSettings()에서 xcconfig 참조 제거**

`Project.swift`의 `appSettings()` 함수 전체를 다음으로 교체.

```swift
func appSettings() -> Settings {
    .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "DEVELOPMENT_TEAM": .string(developmentTeamId),
            "DEFINES_MODULE": "NO",
        ],
        configurations: [
            .debug(name: "Debug", settings: [
                "CODE_SIGN_STYLE": "Automatic",
                "CODE_SIGN_IDENTITY": "Apple Development",
            ]),
            .release(name: "Release", settings: [
                "CODE_SIGN_STYLE": "Manual",
                "CODE_SIGN_IDENTITY": "Apple Distribution",
                "PROVISIONING_PROFILE_SPECIFIER": "SuraSura AppStore",
            ]),
        ]
    )
}
```

- [ ] **Step 3: infoPlist에서 GOOGLE_CLOUD_API_KEY 항목 제거**

`Project.swift`의 SuraSura 앱 타겟 `infoPlist` 블록을 다음으로 교체.

```swift
infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "すらすら",
    "CFBundleShortVersionString": "1.0.0",
    "CFBundleVersion": "1",
    "NSMicrophoneUsageDescription": "실시간 통역을 위해 마이크가 필요합니다.",
    "NSSpeechRecognitionUsageDescription": "실시간 음성 인식을 위해 권한이 필요합니다.",
    "UILaunchScreen": [:],
]),
```

- [ ] **Step 4: 로컬 Secrets.xcconfig 삭제 (있을 경우)**

```bash
rm -f Secrets.xcconfig
```

(로컬에만 있는 파일. gitignored 이므로 git status에 영향 없음.)

- [ ] **Step 5: tuist generate로 빌드 가능성 확인**

```bash
tuist generate --no-open
```

성공해야 함. 이 단계에서는 아직 Google* 파일이 남아 있어 빌드는 실패할 수 있으나, 프로젝트 생성 자체는 성공해야 한다.

- [ ] **Step 6: Commit**

```bash
git add Project.swift
git commit -m "build: iOS 18.0 deployment target로 변경, Secrets/Google API Key 참조 제거"
```

---

### Task 2: SupportedLanguage에 BCP-47 / sttLocale 프로퍼티 추가

기존 Google 프로퍼티/`nepali`/Optional 처리는 **유지**한다(Task 7에서 정리). 이 task는 **추가만**.

**Files:**
- Modify: `Core/APIClient/Sources/SupportedLanguage.swift`

- [ ] **Step 1: bcp47Code와 sttLocale 프로퍼티 추가**

`SupportedLanguage.swift` 맨 아래에 다음 extension을 추가.

```swift
extension SupportedLanguage {
    /// Apple BCP-47 코드 — STT / Translation / TTS 공통
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
        case .nepali:             return "ne-NP"
        }
    }

    /// STT용 Locale — bcp47Code로 생성
    public var sttLocale: Locale {
        Locale(identifier: bcp47Code)
    }
}
```

- [ ] **Step 2: 빌드 검증**

```bash
tuist generate --no-open
xcodebuild -workspace SuraSura.xcworkspace -scheme SuraSura \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -10
```

기대: `** BUILD SUCCEEDED **`. 기존 코드를 건드리지 않았으므로 통과해야 함.

- [ ] **Step 3: Commit**

```bash
git add Core/APIClient/Sources/SupportedLanguage.swift
git commit -m "feat(APIClient): SupportedLanguage에 bcp47Code, sttLocale 프로퍼티 추가"
```

---

### Task 3: SpeechClient (인터페이스 + Apple 전용 Live)

**Files:**
- Create: `Core/APIClient/Sources/SpeechClient.swift`
- Create: `Core/APIClient/Sources/SpeechClientLive.swift`

- [ ] **Step 1: SpeechClient.swift 생성**

```swift
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Client Interface

@DependencyClient
public struct SpeechClient: Sendable {
    /// 실시간 스트리밍 STT 시작 - AsyncStream으로 인식 텍스트 방출
    public var startStreaming: @Sendable (_ language: SupportedLanguage) throws -> AsyncStream<String> = { _ in
        AsyncStream { _ in }
    }
    /// 스트리밍 중지
    public var stopStreaming: @Sendable () async -> Void = {}
}

// MARK: - Dependency Registration

extension SpeechClient: DependencyKey {
    public static var liveValue: SpeechClient {
        let live = SpeechClientLive.shared
        return SpeechClient(
            startStreaming: { language in
                try live.startStreaming(language)
            },
            stopStreaming: {
                await live.stopStreaming()
            }
        )
    }

    public static var previewValue: SpeechClient {
        SpeechClient(
            startStreaming: { _ in
                AsyncStream { continuation in
                    continuation.yield("안녕하세요 (미리보기)")
                    continuation.finish()
                }
            },
            stopStreaming: {}
        )
    }
}

extension DependencyValues {
    public var speechClient: SpeechClient {
        get { self[SpeechClient.self] }
        set { self[SpeechClient.self] = newValue }
    }
}
```

- [ ] **Step 2: SpeechClientLive.swift 생성**

```swift
import Foundation
import AVFoundation
import Speech

// Apple Speech Framework (on-device only)
// @unchecked Sendable: AVAudioEngine, SFSpeechRecognitionTask 등 non-Sendable 보유

final class SpeechClientLive: @unchecked Sendable {

    static let shared = SpeechClientLive()

    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private init() {}

    func startStreaming(_ language: SupportedLanguage) throws -> AsyncStream<String> {
        let locale = language.sttLocale

        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.supportsOnDeviceRecognition,
              recognizer.isAvailable else {
            return AsyncStream { $0.finish() }
        }

        return AsyncStream { continuation in
            Task {
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                request.requiresOnDeviceRecognition = true
                self.recognitionRequest = request

                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)

                    let inputNode = self.audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)

                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                        request.append(buffer)
                    }
                    try self.audioEngine.start()
                } catch {
                    continuation.finish()
                    return
                }

                self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let result = result {
                        continuation.yield(result.bestTranscription.formattedString)
                    }
                    if error != nil || result?.isFinal == true {
                        continuation.finish()
                    }
                }
            }
        }
    }

    func stopStreaming() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
```

- [ ] **Step 3: 빌드 검증**

```bash
tuist generate --no-open
xcodebuild -workspace SuraSura.xcworkspace -scheme SuraSura \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -10
```

기대: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Core/APIClient/Sources/SpeechClient.swift Core/APIClient/Sources/SpeechClientLive.swift
git commit -m "feat(APIClient): on-device SpeechClient (Apple SFSpeechRecognizer) 추가"
```

---

### Task 4: TranslationBridge + TranslationClient

**Files:**
- Create: `Core/APIClient/Sources/TranslationBridge.swift`
- Create: `Core/APIClient/Sources/TranslationClient.swift`

- [ ] **Step 1: TranslationBridge.swift 생성**

```swift
import Foundation
import Translation

/// SwiftUI `.translationTask` modifier가 제공하는 `TranslationSession`을
/// Reducer의 dependency에서 호출 가능하도록 연결해주는 브리지.
@MainActor
public final class TranslationBridge {
    public static let shared = TranslationBridge()
    private init() {}

    private var session: TranslationSession?
    private var registeredSource: SupportedLanguage?
    private var registeredTarget: SupportedLanguage?

    public func register(
        session: TranslationSession,
        source: SupportedLanguage,
        target: SupportedLanguage
    ) {
        self.session = session
        self.registeredSource = source
        self.registeredTarget = target
    }

    public func translate(
        text: String,
        source: SupportedLanguage,
        target: SupportedLanguage
    ) async throws -> String {
        // session이 준비될 때까지 최대 1초 대기 (.translationTask 비동기 주입 대비)
        let deadline = Date().addingTimeInterval(1.0)
        while session == nil || registeredSource != source || registeredTarget != target {
            if Date() >= deadline {
                throw TranslationError.sessionNotReady
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let session = session else {
            throw TranslationError.sessionNotReady
        }
        let response = try await session.translate(text)
        return response.targetText
    }
}

public enum TranslationError: LocalizedError {
    case sessionNotReady
    case translationFailed

    public var errorDescription: String? {
        switch self {
        case .sessionNotReady:    return "번역 세션이 준비되지 않았습니다."
        case .translationFailed:  return "번역에 실패했습니다."
        }
    }
}
```

- [ ] **Step 2: TranslationClient.swift 생성**

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct TranslationClient: Sendable {
    /// 텍스트 번역 요청 (source/target 모두 명시)
    public var translate: @Sendable (
        _ text: String,
        _ target: SupportedLanguage,
        _ source: SupportedLanguage
    ) async throws -> String = { _, _, _ in "" }
}

extension TranslationClient: DependencyKey {
    public static var liveValue: TranslationClient {
        TranslationClient(
            translate: { text, target, source in
                try await TranslationBridge.shared.translate(
                    text: text, source: source, target: target
                )
            }
        )
    }

    public static var previewValue: TranslationClient {
        TranslationClient(
            translate: { text, _, _ in "[\(text) 번역 미리보기]" }
        )
    }
}

extension DependencyValues {
    public var translationClient: TranslationClient {
        get { self[TranslationClient.self] }
        set { self[TranslationClient.self] = newValue }
    }
}
```

- [ ] **Step 3: 빌드 검증**

```bash
tuist generate --no-open
xcodebuild -workspace SuraSura.xcworkspace -scheme SuraSura \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -10
```

기대: `** BUILD SUCCEEDED **`. (`Translation` framework는 iOS 17.4+에서 시스템 제공이므로 별도 link 불필요.)

- [ ] **Step 4: Commit**

```bash
git add Core/APIClient/Sources/TranslationBridge.swift Core/APIClient/Sources/TranslationClient.swift
git commit -m "feat(APIClient): on-device TranslationClient + TranslationBridge 추가"
```

---

### Task 5: AppleTTSClientLive + TTSClient.liveValue 교체

**Files:**
- Create: `Core/APIClient/Sources/AppleTTSClientLive.swift`
- Modify: `Core/APIClient/Sources/TTSClient.swift:15-23` (liveValue 본문)

- [ ] **Step 1: AppleTTSClientLive.swift 생성**

```swift
import Foundation
import AVFoundation

/// AVSpeechSynthesizer 기반 on-device TTS.
final class AppleTTSClientLive: NSObject, @unchecked Sendable {

    static let shared = AppleTTSClientLive()

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, language: SupportedLanguage) async {
        stop()
        guard !text.isEmpty else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.bcp47Code)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.continuation = cont
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        continuation?.resume()
        continuation = nil
    }
}

extension AppleTTSClientLive: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        continuation?.resume()
        continuation = nil
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // stop()에서 이미 resume됨
    }
}
```

- [ ] **Step 2: TTSClient.swift의 liveValue를 AppleTTSClientLive로 교체**

`TTSClient.swift` 15-23 라인의 `liveValue` 블록을 다음으로 교체.

```swift
    public static var liveValue: TTSClient {
        let live = AppleTTSClientLive.shared
        return TTSClient(
            speak: { text, language in
                await live.speak(text: text, language: language)
            },
            stop: { live.stop() }
        )
    }
```

(인터페이스 `speak`는 여전히 `throws`이지만 실제로는 throw하지 않으므로 호출부 호환.)

- [ ] **Step 3: 빌드 검증**

```bash
tuist generate --no-open
xcodebuild -workspace SuraSura.xcworkspace -scheme SuraSura \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -10
```

기대: `** BUILD SUCCEEDED **`. (`GoogleTTSClientLive`는 더 이상 참조되지 않지만 파일은 남아 있어 무해.)

- [ ] **Step 4: Commit**

```bash
git add Core/APIClient/Sources/AppleTTSClientLive.swift Core/APIClient/Sources/TTSClient.swift
git commit -m "feat(APIClient): TTSClient liveValue를 AVSpeechSynthesizer 기반으로 교체"
```

---

### Task 6: Reducer & View — 새 dependency / source 전달 / .translationTask

**Files:**
- Modify: `Features/SpeechRecognition/Sources/SpeechRecognitionFeature.swift:27`
- Modify: `Features/Translation/Sources/TranslationFeature.swift:20-49`
- Modify: `Features/Home/Sources/HomeFeature.swift:233`
- Modify: `Features/Home/Sources/HomeView.swift` (translationTask 부착)

- [ ] **Step 1: SpeechRecognitionReducer의 dependency를 speechClient로 변경**

`SpeechRecognitionFeature.swift` 27번 라인:

```swift
    @Dependency(\.speechClient) var speechClient
```

(이름이 같으므로 다른 코드 변경 불필요.)

- [ ] **Step 2: TranslationReducer의 translate 시그니처를 source 받도록 확장**

`TranslationFeature.swift`의 Action enum 첫 항목과 핸들러를 수정.

`Action` enum의 `translateRequested(String)`을 다음으로 교체:

```swift
        case translateRequested(String, SupportedLanguage)  // text, source
```

`@Dependency(\.googleTranslationClient)`을 다음으로 교체:

```swift
    @Dependency(\.translationClient) var translationClient
```

`.translateRequested(let text)` case 전체를 다음으로 교체:

```swift
            case .translateRequested(let text, let source):
                guard !text.isEmpty else { return .none }
                state.isTranslating = true
                let targetLang = state.targetLanguage
                return .run { send in
                    do {
                        let result = try await translationClient.translate(text, targetLang, source)
                        await send(.translationCompleted(result))
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }
```

- [ ] **Step 3: HomeReducer의 recognizedTextUpdated 핸들러가 source를 함께 보내도록 수정**

`HomeFeature.swift` 232-233 라인 (`.speechRecognition(.recognizedTextUpdated(let text))` case)을 다음으로 교체:

```swift
            case .speechRecognition(.recognizedTextUpdated(let text)):
                let source = state.speechRecognition.sourceLanguage
                return .send(.translation(.translateRequested(text, source)))
```

- [ ] **Step 4: HomeView에 .translationTask modifier 부착**

`HomeView.swift`에 `import Translation` 추가(파일 상단의 import 블록에):

```swift
import SwiftUI
import ComposableArchitecture
import APIClient
import DesignSystem
import Translation
```

`HomeView`의 body의 가장 바깥 `ZStack` 끝(`.fullScreenCover` 두 개 다음)에 다음 modifier들을 추가. 위치는 마지막 `.fullScreenCover` 닫힘 직후, `}` 직전.

```swift
        .translationTask(translationConfiguration) { session in
            await TranslationBridge.shared.register(
                session: session,
                source: translationSource,
                target: translationTarget
            )
        }
```

같은 파일의 `HomeView` 안에 헬퍼 computed properties를 추가(예: `body` 정의 위, `appBundle` getter 근처):

```swift
    private var translationSource: SupportedLanguage {
        store.activeMic == .top ? store.topLanguage : store.bottomLanguage
    }

    private var translationTarget: SupportedLanguage {
        store.activeMic == .top ? store.bottomLanguage : store.topLanguage
    }

    private var translationConfiguration: TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: translationSource.bcp47Code),
            target: Locale.Language(identifier: translationTarget.bcp47Code)
        )
    }
```

- [ ] **Step 5: 빌드 검증**

```bash
tuist generate --no-open
xcodebuild -workspace SuraSura.xcworkspace -scheme SuraSura \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -10
```

기대: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Features/SpeechRecognition/Sources/SpeechRecognitionFeature.swift \
        Features/Translation/Sources/TranslationFeature.swift \
        Features/Home/Sources/HomeFeature.swift \
        Features/Home/Sources/HomeView.swift
git commit -m "feat: SpeechRecognition/Translation/Home을 on-device 클라이언트로 전환

- speechClient/translationClient dependency 키 사용
- translateRequested가 source language를 함께 받도록 시그니처 확장
- HomeView에 .translationTask modifier 부착 (Apple Translation 세션 등록)"
```

---

### Task 7: Google* 파일 + APIKeys 삭제, SupportedLanguage 최종 정리

**Files:**
- Delete: `Core/APIClient/Sources/GoogleSpeechClient.swift`
- Delete: `Core/APIClient/Sources/GoogleSpeechClientLive.swift`
- Delete: `Core/APIClient/Sources/GoogleSTTRestClient.swift`
- Delete: `Core/APIClient/Sources/GoogleTranslationClient.swift`
- Delete: `Core/APIClient/Sources/GoogleTranslationClientLive.swift`
- Delete: `Core/APIClient/Sources/GoogleTTSClientLive.swift`
- Delete: `Core/APIClient/Sources/APIKeys.swift`
- Modify: `Core/APIClient/Sources/SupportedLanguage.swift` (네팔어 제거, Google 프로퍼티 제거, appleSpeechLocale 제거)

- [ ] **Step 1: Google* 파일과 APIKeys.swift 삭제**

```bash
rm Core/APIClient/Sources/GoogleSpeechClient.swift
rm Core/APIClient/Sources/GoogleSpeechClientLive.swift
rm Core/APIClient/Sources/GoogleSTTRestClient.swift
rm Core/APIClient/Sources/GoogleTranslationClient.swift
rm Core/APIClient/Sources/GoogleTranslationClientLive.swift
rm Core/APIClient/Sources/GoogleTTSClientLive.swift
rm Core/APIClient/Sources/APIKeys.swift
```

- [ ] **Step 2: SupportedLanguage.swift 최종 정리**

파일 전체를 다음 내용으로 교체.

```swift
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
```

(주의: `.nepali` 케이스가 완전히 제거됨. 기본값 `.english`, `.korean` 등은 그대로이므로 기존 저장된 사용자 언어 설정은 영향 없음. 만약 어떤 코드 경로가 `.nepali`를 참조했다면 컴파일 에러로 드러난다.)

- [ ] **Step 3: 빌드 검증 + .nepali 참조 흔적 검사**

```bash
grep -rn "nepali\|googleSpeechCode\|googleTranslationCode\|googleTTSCode\|googleTTSGender\|appleSpeechLocale\|APIKeys\|GOOGLE_CLOUD_API_KEY" \
  Core Features App Project.swift 2>/dev/null || echo "참조 없음 — OK"

tuist generate --no-open
xcodebuild -workspace SuraSura.xcworkspace -scheme SuraSura \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -15
```

기대:
- grep 출력에 매치 없음 (`참조 없음 — OK` 출력)
- `** BUILD SUCCEEDED **`

매치가 남아 있으면 해당 위치를 추가 수정한 뒤 다시 grep/build.

- [ ] **Step 4: Commit**

```bash
git add -A Core/APIClient/Sources/
git commit -m "refactor(APIClient): Google* 클라이언트 및 APIKeys 제거, SupportedLanguage 온디바이스 전용으로 정리

- 네팔어(.nepali) 제거 (Apple Translation/STT 미지원)
- google* 코드 프로퍼티 모두 삭제
- appleSpeechLocale을 sttLocale (non-Optional)로 통일"
```

---

### Task 8: 최종 빌드 + 수동 검증

이 task는 코드 변경이 없는 검증 단계.

- [ ] **Step 1: clean build로 전체 재빌드**

```bash
tuist clean
tuist generate --no-open
xcodebuild -workspace SuraSura.xcworkspace -scheme SuraSura \
  -destination 'generic/platform=iOS Simulator,OS=18.0,name=iPhone 15' \
  -configuration Debug build 2>&1 | tail -20
```

기대: `** BUILD SUCCEEDED **`. 시뮬레이터 이름은 로컬에 설치된 것에 맞춰 조정.

- [ ] **Step 2: 시뮬레이터에서 골든 패스 확인 — 한국어 → 영어**

```bash
xcodebuild -workspace SuraSura.xcworkspace -scheme SuraSura \
  -destination 'platform=iOS Simulator,OS=18.0,name=iPhone 15' \
  -configuration Debug \
  test-without-building 2>&1 | tail -10 || true   # 테스트 없으면 무시
open -a Simulator
xcrun simctl launch booted com.coby.surasura
```

수동 확인 항목:
- 하단 마이크 → 한국어 말하기 → 상단에 영어 번역 표시
- (첫 사용 시) Apple Translation 모델 다운로드 다이얼로그 노출
- 자동 TTS가 켜져 있으면 영어 음성 재생
- 상단 마이크로 영어 → 하단 한국어 번역
- 대면 모드 토글 동작
- 텍스트 전체화면 확장에서 TTS 버튼 동작

- [ ] **Step 3: 비행기 모드(네트워크 차단) 검증**

시뮬레이터에서 네트워크 비활성화 또는 실기기에서 비행기 모드 ON 후 동일 시나리오. 정상 동작해야 한다(번역 모델은 사전 다운로드되어 있어야 함).

```bash
# 시뮬레이터에서 네트워크 끄기 — Settings 앱에서 수동, 또는:
xcrun simctl status_bar booted override --dataNetwork hide
```

(이 명령은 표시만 바꿈; 실제 차단은 호스트 macOS의 네트워크 끄기 또는 시뮬레이터 → Settings → Wi-Fi OFF로 처리.)

- [ ] **Step 4: 코드베이스에 잔존 흔적 최종 검사**

```bash
grep -rn "Google\|googleCloud\|GOOGLE_CLOUD" Core Features App Project.swift 2>/dev/null \
  | grep -v "docs/" \
  | grep -v ".git/" \
  || echo "잔존 흔적 없음 — OK"
```

기대: `잔존 흔적 없음 — OK`. (docs/superpowers/* 디자인/플랜 문서에만 남아 있어야 한다.)

- [ ] **Step 5: 검증 결과 보고**

사용자에게 다음을 보고:
- 빌드 성공 여부
- 수동 검증 결과 (각 시나리오 OK / NG)
- 비행기 모드 검증 결과
- 잔존 흔적 검사 결과

검증 실패 시: 해당 단계의 task로 돌아가 수정 후 재검증. 모두 통과해야 plan 종료.

---

## Self-Review 결과

- **Spec coverage**: 디자인 문서의 모든 결정 사항(deployment target 변경, Apple STT/Translation/TTS 도입, TranslationBridge 패턴, SupportedLanguage 정리, Secrets 제거)이 Task 1-7에 1:1 대응됨. 검증은 Task 8에서 포괄.
- **Placeholder scan**: TBD/TODO/"적절히 처리" 없음. 모든 코드 블록 완전.
- **Type consistency**:
  - `SpeechClient.startStreaming(_ language:)`, `SpeechClient.stopStreaming()` — 일관
  - `TranslationClient.translate(text, target, source)` — Task 4, 6에서 동일 순서로 사용
  - `TranslationBridge.translate(text:source:target:)` / `register(session:source:target:)` — Task 4, 6에서 일관
  - `TTSClient.speak(text, language)` — 기존 인터페이스 유지
  - `SupportedLanguage.bcp47Code` / `sttLocale` — Task 2에서 도입, Task 3·4·5·6에서 사용, Task 7에서 정착
