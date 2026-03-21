import ProjectDescription

// MARK: - Constants

let developmentTeamId: String = "3Y8YH8GWMM"
let bundleIdPrefix = "com.coby.surasura"
let deploymentTarget = DeploymentTargets.iOS("17.4")

// MARK: - Target Settings Helpers

/// 일반 프레임워크 타겟용 settings (서명만)
func frameworkSettings() -> Settings {
    .settings(base: [
        "SWIFT_VERSION": "5.9",
        "DEVELOPMENT_TEAM": .string(developmentTeamId),
        "CODE_SIGN_STYLE": "Automatic",
    ])
}

/// 앱 타겟용 settings (서명 + Secrets.xcconfig로 API Key 주입)
/// - Debug: Automatic signing (개발용)
/// - Release: Manual signing (CI/CD App Store 배포용)
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
            ], xcconfig: "Secrets.xcconfig"),
            .release(name: "Release", settings: [
                "CODE_SIGN_STYLE": "Manual",
                "CODE_SIGN_IDENTITY": "Apple Distribution",
                "PROVISIONING_PROFILE_SPECIFIER": "SuraSura AppStore",
            ], xcconfig: "Secrets.xcconfig"),
        ]
    )
}

// MARK: - Project

let project = Project(
    name: "SuraSura",
    options: .options(
        defaultKnownRegions: ["ko", "en", "ja", "zh-Hans"],
        developmentRegion: "ko"
    ),
    settings: .settings(
        base: [
            "MARKETING_VERSION": "1.0",
            "CURRENT_PROJECT_VERSION": "1",
        ],
        configurations: [
            .debug(name: "Debug", settings: [:], xcconfig: nil),
            .release(name: "Release", settings: [:], xcconfig: nil),
        ]
    ),
    targets: [
        // MARK: App
        .target(
            name: "SuraSura",
            destinations: [.iPhone],
            product: .app,
            bundleId: "\(bundleIdPrefix)",
            deploymentTargets: deploymentTarget,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "すらすら",
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
                "GOOGLE_CLOUD_API_KEY": "$(GOOGLE_CLOUD_API_KEY)",
                "NSMicrophoneUsageDescription": "실시간 통역을 위해 마이크가 필요합니다.",
                "NSSpeechRecognitionUsageDescription": "실시간 음성 인식을 위해 권한이 필요합니다.",
                "UILaunchScreen": [:],
            ]),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            dependencies: [
                .target(name: "HomeFeature"),
                .target(name: "SpeechRecognitionFeature"),
                .target(name: "TranslationFeature"),
                .target(name: "APIClient"),
                .target(name: "DesignSystem"),
            ],
            settings: appSettings()
        ),

        // MARK: Features
        .target(
            name: "HomeFeature",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "\(bundleIdPrefix).feature.home",
            deploymentTargets: deploymentTarget,
            sources: ["Features/Home/Sources/**"],
            resources: [
                .glob(pattern: "Features/Home/Sources/Resources/**"),
            ],
            dependencies: [
                .target(name: "SpeechRecognitionFeature"),
                .target(name: "TranslationFeature"),
                .target(name: "DesignSystem"),
                .external(name: "ComposableArchitecture"),
            ],
            settings: frameworkSettings()
        ),
        .target(
            name: "SpeechRecognitionFeature",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "\(bundleIdPrefix).feature.speech",
            deploymentTargets: deploymentTarget,
            sources: ["Features/SpeechRecognition/Sources/**"],
            dependencies: [
                .target(name: "APIClient"),
                .external(name: "ComposableArchitecture"),
            ],
            settings: frameworkSettings()
        ),
        .target(
            name: "TranslationFeature",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "\(bundleIdPrefix).feature.translation",
            deploymentTargets: deploymentTarget,
            sources: ["Features/Translation/Sources/**"],
            dependencies: [
                .target(name: "APIClient"),
                .external(name: "ComposableArchitecture"),
            ],
            settings: frameworkSettings()
        ),

        // MARK: Core
        .target(
            name: "APIClient",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "\(bundleIdPrefix).core.apiclient",
            deploymentTargets: deploymentTarget,
            sources: ["Core/APIClient/Sources/**"],
            dependencies: [
                .external(name: "Dependencies"),
                .external(name: "DependenciesMacros"),
            ],
            settings: frameworkSettings()
        ),
        .target(
            name: "DesignSystem",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "\(bundleIdPrefix).core.designsystem",
            deploymentTargets: deploymentTarget,
            sources: ["Core/DesignSystem/Sources/**"],
            settings: frameworkSettings()
        ),
    ],
    schemes: [
        .scheme(
            name: "SuraSura",
            buildAction: .buildAction(targets: ["SuraSura"]),
            runAction: .runAction(configuration: "Debug")
        )
    ]
)
