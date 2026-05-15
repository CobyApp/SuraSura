# SuraSura — Google Cloud API 제거 및 온디바이스 전환 설계

작성일: 2026-05-15

## 1. 배경 및 목표

현재 SuraSura 앱은 다음 Google Cloud API에 의존합니다.

- Google Speech-to-Text REST (Apple Speech 미지원/불안정 언어용 fallback)
- Google Cloud Translation v2 (모든 번역)
- Google Cloud Text-to-Speech REST (모든 TTS)

이 의존성을 모두 제거하고 **모든 음성/번역/TTS를 iOS 온디바이스 프레임워크**로 처리한다. API Key, 네트워크 호출, 외부 의존성을 완전히 제거하여 오프라인 동작과 프라이버시를 강화한다.

## 2. 핵심 결정 사항

| 항목 | 결정 |
| --- | --- |
| Deployment target | iOS 17.4 → **iOS 18.0** |
| STT | `SFSpeechRecognizer` (`requiresOnDeviceRecognition = true`)만 사용 |
| 번역 | Apple **`Translation`** framework (`TranslationSession`) |
| TTS | `AVSpeechSynthesizer` |
| 번역 모델 다운로드 UX | Apple 기본(첫 사용 시 자동 동의 다이얼로그) |
| `SupportedLanguage` | Apple 온디바이스 지원 언어만 유지, 네팔어 제거 |
| Secrets/API Key | 완전 제거 (xcconfig 참조·infoPlist 키·Secrets 파일 모두) |

## 3. 모듈/타입 단위 변경

### 3.1 `Core/APIClient` — 외부 인터페이스 재설계

기존 `GoogleSpeechClient`, `GoogleTranslationClient`, `TTSClient` 세 개의 클라이언트를 다음으로 교체한다. 모듈 이름은 그대로(`APIClient`) 두되, "Google" 접두어를 모두 제거한다.

| 신규 타입 | 역할 | liveValue 백엔드 |
| --- | --- | --- |
| `SpeechClient` | STT 스트리밍 | `SFSpeechRecognizer` on-device |
| `TranslationClient` | 텍스트 번역 | Apple `Translation` framework |
| `TTSClient` | 텍스트 음성 합성 | `AVSpeechSynthesizer` |

각 클라이언트는 기존과 동일하게 `@DependencyClient` 매크로 + `DependencyKey`로 노출한다. `DependencyValues` 키 이름도 일반화한다(`googleSpeechClient` → `speechClient`, `googleTranslationClient` → `translationClient`, `ttsClient`는 유지).

### 3.2 `SpeechClient` (STT)

기존 `GoogleSpeechClientLive`는 Apple/Google 두 경로를 분기했다. 새 구현은 **Apple 경로만 남기고 단순화**한다.

- `AVAudioEngine` + `SFSpeechAudioBufferRecognitionRequest`
- `request.requiresOnDeviceRecognition = true` 강제 (네트워크 사용 차단)
- `request.shouldReportPartialResults = true`
- 인터페이스는 `startStreaming(_ language:) -> AsyncStream<String>` / `stopStreaming()` 그대로 유지

Locale은 `SupportedLanguage.appleSpeechLocale`(non-Optional)에서 가져온다. `supportsOnDeviceRecognition` 점검은 init 시점이 아닌 `startStreaming` 시점에 수행하며, 미지원이면 `AsyncStream`을 finish로 즉시 종료한다(에러 메시지는 Reducer에서 별도 표시).

### 3.3 `TranslationClient` (번역)

Apple `Translation` framework의 공식 사용 경로는 **SwiftUI의 `.translationTask` modifier를 통한 `TranslationSession` 주입**이다. iOS 18에서도 `TranslationSession`을 modifier 외부에서 자유롭게 생성하기 어려우므로, 다음과 같은 통합 패턴을 사용한다.

**패턴: View가 `TranslationSession`을 보유하고, Reducer는 요청 의도만 표현**

1. `HomeView`(또는 전용 host view)에 `.translationTask(source:target:)`를 부착한다. source/target은 `store.speechRecognition.sourceLanguage` / `store.translation.targetLanguage`에서 파생된 `Locale.Language`.
2. modifier가 제공하는 `TranslationSession`을 `@State`로 잡고, View 내부의 `Task`가 `store.translation.pendingTranslationText`(신규 상태)를 관찰해 변경될 때마다 `session.translate(_:)` 호출.
3. 결과는 `store.send(.translation(.translationCompleted(...)))`로 전달.

이를 위해 `TranslationClient`의 인터페이스는 **번역 요청을 큐잉하는 형태**로 바꾼다.

```swift
@DependencyClient
public struct TranslationClient: Sendable {
    public var translate: @Sendable (_ text: String, _ target: SupportedLanguage, _ source: SupportedLanguage) async throws -> String = { _, _, _ in "" }
}
```

`liveValue`는 별도의 `TranslationBridge`(`@MainActor` 싱글톤)를 통해 View 레이어에서 등록한 `TranslationSession`에 위임한다.

- 등록: `HomeView`의 `.translationTask` modifier 클로저 안에서 `TranslationBridge.shared.register(session, source:, target:)` 호출. source/target이 변하면 SwiftUI가 modifier를 재실행하므로 자동 갱신된다.
- 호출: `liveValue.translate(text, target, source)`는 `TranslationBridge.shared.translate(text, source:, target:)`로 위임. 브리지는 현재 등록된 session의 source/target이 요청과 일치하는지 확인하고 일치할 때만 번역을 수행. 불일치/미등록이면 일정 시간(예: 1초) waiting 후 `TranslationError.sessionNotReady`.
- 해제: `HomeView`의 `.onDisappear` 또는 `.translationTask` 클로저 종료 시 명시적 해제는 불필요(다음 등록이 덮어씀).

이 브리지 패턴이 TCA의 "의존성은 Reducer에서, Apple Translation은 View에서"라는 두 제약을 동시에 만족시킨다.

대안으로 단순화를 위해 `TranslationClient` 인터페이스 자체를 없애고 `TranslationReducer.Action`에 `.runTranslation(SessionHandle)`을 두어 View가 직접 처리하는 안도 있으나, 현재 코드 구조(번역/TTS가 dependency client 패턴)에 잘 들어맞으려면 브리지 안이 변경 폭이 작다. **브리지 안을 채택**한다.

소스 언어가 필요한 이유: 기존 Google API는 source auto-detect였으나 Apple Translation은 source/target 모두 명시해야 모델이 정확하게 매칭된다.

### 3.4 `TTSClient` (TTS)

`GoogleTTSClientLive`를 `AppleTTSClientLive`로 교체.

- `AVSpeechSynthesizer`를 단일 인스턴스로 보관
- `speak(text, language)`: `AVSpeechUtterance` 생성 + `voice = AVSpeechSynthesisVoice(language: language.bcp47Code)`
- 재생 완료 감지: `AVSpeechSynthesizerDelegate.speechSynthesizer(_:didFinish:)`를 `CheckedContinuation`으로 감싸 `async`로 노출
- `stop()`: `synthesizer.stopSpeaking(at: .immediate)`
- `AVAudioSession`은 `.playback / .default` 카테고리로 설정

`TTSClient`의 외부 인터페이스(`speak(text, language)`, `stop()`)는 그대로 유지. Reducer/View 호출부 변경 없음.

### 3.5 `SupportedLanguage` 정리

`Core/APIClient/Sources/SupportedLanguage.swift`를 다음과 같이 정리한다.

- **`.nepali` case 제거** (STT/번역 모두 미지원)
- **Apple Translation iOS 18.0 지원 언어** 기준으로 enum 멤버 검증. 현재 enum에 있는 케이스 중 iOS 18에서 Apple Translation/STT 모두 지원되지 않는 항목은 제거. 구현 단계에서 `LanguageAvailability().status(from:to:)`로 검증해 최종 목록 확정.
- `appleSpeechLocale`을 **Optional 제거** (모든 case가 지원되므로 항상 non-nil `Locale`)
- Google 전용 프로퍼티 모두 삭제: `googleSpeechCode`, `googleTranslationCode`, `googleTTSCode`, `googleTTSGender`
- 신규 프로퍼티: `bcp47Code: String` (예: `"ko-KR"`, `"en-US"`) — STT/번역/TTS 공통으로 사용

`displayName`, `flag`, `shortName`, `localeIdentifier`, `localizedName`은 그대로 유지.

### 3.6 Reducer 영향

- `SpeechRecognitionReducer`: `@Dependency(\.googleSpeechClient)` → `@Dependency(\.speechClient)`. 그 외 로직 변경 없음.
- `TranslationReducer`: `@Dependency(\.googleTranslationClient)` → `@Dependency(\.translationClient)`. `translate(text, target)` 호출이 `translate(text, target, source)`로 바뀜 — `state.targetLanguage`와 함께 source language도 인자로 전달해야 하므로 `State`에 `sourceLanguage: SupportedLanguage`를 추가하거나 `HomeReducer`가 액션에 source를 실어 보낸다. 후자가 변경 폭이 더 작다 → `.translateRequested(text, source)`로 시그니처 확장.
- `HomeReducer`: 위 시그니처 변경에 맞춰 `.speechRecognition(.recognizedTextUpdated)` 핸들러에서 source를 함께 전달.

### 3.7 View 영향

- `HomeView`에 **`.translationTask(source:target:)` modifier 부착**과 `TranslationBridge` 등록 로직 추가.
- source/target은 `activeMic`에 따라 동적으로 계산.
- modifier는 source/target이 변경될 때마다 새로운 session을 제공하므로, View는 받은 session을 bridge에 갱신 등록.
- 그 외 UI 변경 없음.

### 3.8 빌드/구성 변경

- `Project.swift`:
  - `deploymentTarget = DeploymentTargets.iOS("18.0")`
  - `infoPlist`에서 `"GOOGLE_CLOUD_API_KEY"` 항목 제거
  - `appSettings()`의 모든 `xcconfig: "Secrets.xcconfig"` 제거 (혹은 인자 자체 제거)
- `Secrets.xcconfig` 파일 삭제 (gitignore에 있을 가능성 → 로컬 파일도 정리)
- `.gitignore`에 있는 Secrets 관련 항목은 그대로 두어도 무해하나, 명시적으로 정리

### 3.9 권한/Info.plist

- `NSMicrophoneUsageDescription` 유지
- `NSSpeechRecognitionUsageDescription` 유지
- 신규 권한 키 불필요 (Apple Translation은 별도 권한 키가 필요 없음)

## 4. 데이터 흐름 (변경 후)

```
[마이크 입력]
    └─ SFSpeechRecognizer (on-device)
         └─ recognizedText 갱신
              └─ HomeReducer가 .translateRequested(text, source) dispatch
                   └─ TranslationClient.translate(text, target, source)
                        └─ TranslationBridge.translate(...)
                             └─ View가 보유한 TranslationSession.translate(...)
                                  └─ translatedText 갱신
                                       └─ isAutoSpeakEnabled면 TTSClient.speak(...)
                                            └─ AVSpeechSynthesizer
```

네트워크 호출은 더 이상 없다.

## 5. 에러 처리

- STT on-device 모델 미설치 언어 선택 시: AsyncStream을 즉시 finish하고 `errorOccurred`로 사용자에게 알림(기존 메시지 유지).
- Apple Translation 모델 미다운로드 + 사용자 거부 시: Apple SDK가 `TranslationSession` 호출에서 throw — `TranslationError`로 매핑하여 `errorOccurred` dispatch.
- TTS 음성 미지원 언어: `AVSpeechSynthesisVoice(language:)`가 nil이면 시스템 기본 음성으로 fallback(시도하되 실패 시 silent).

## 6. 제거 대상 (정리)

**삭제할 파일**:
- `Core/APIClient/Sources/GoogleSpeechClient.swift`
- `Core/APIClient/Sources/GoogleSpeechClientLive.swift`
- `Core/APIClient/Sources/GoogleSTTRestClient.swift`
- `Core/APIClient/Sources/GoogleTranslationClient.swift`
- `Core/APIClient/Sources/GoogleTranslationClientLive.swift`
- `Core/APIClient/Sources/GoogleTTSClientLive.swift`
- `Core/APIClient/Sources/APIKeys.swift`
- `Secrets.xcconfig` (워크스페이스 루트의 로컬 파일, gitignored)

**삭제할 설정**:
- `Project.swift`의 `xcconfig: "Secrets.xcconfig"` 참조 2곳 (Debug/Release)
- `Project.swift`의 `infoPlist`에서 `"GOOGLE_CLOUD_API_KEY"` 항목

## 7. 새로 추가할 파일

- `Core/APIClient/Sources/SpeechClient.swift` (인터페이스 + DependencyKey)
- `Core/APIClient/Sources/SpeechClientLive.swift` (Apple Speech 구현)
- `Core/APIClient/Sources/TranslationClient.swift` (인터페이스 + DependencyKey + bridge)
- `Core/APIClient/Sources/TranslationBridge.swift` (View ↔ Reducer 연결용 actor)
- `Core/APIClient/Sources/AppleTTSClientLive.swift` (AVSpeechSynthesizer 구현)
- 기존 `TTSClient.swift`는 인터페이스만 두고 liveValue만 교체

## 8. 테스트 영향

이 프로젝트에는 별도 테스트 타겟이 없다. 검증 방법:

1. `tuist generate` 후 Xcode 빌드 성공
2. 시뮬레이터 또는 실기기에서 다음 골든 패스 수동 확인
   - 한국어 → 영어 통역 (양방향 마이크 모두)
   - 영어 → 한국어 통역 (face-to-face 모드)
   - 처음 번역 시도 시 모델 다운로드 다이얼로그가 정상 노출되고 다운로드 후 즉시 번역
   - 자동 TTS 토글 ON/OFF
   - 전체화면 확장 후 TTS 버튼
3. 네트워크 차단(비행기 모드) 상태에서도 동일 시나리오가 동작하는지 확인 — 진정한 온디바이스 검증

## 9. Out of Scope

- 다국어 STT 모델 사전 다운로드 UX (설정에서 미리 받기 등) — 추후 별도 작업
- 번역 모델 관리 화면 — 추후 별도 작업
- 새로운 언어 추가 (히브리어, 그리스어 등 Apple 지원이지만 현재 enum에 없는 언어)
- 자동 source 언어 감지 (Apple Translation도 부분 지원하지만 현재 UI는 명시 선택 기반이므로 그대로 둠)
- 단위 테스트 추가
