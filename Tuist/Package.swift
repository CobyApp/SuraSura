// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription

/// TCA 관련 라이브러리를 dynamic framework으로 강제 설정
/// static으로 두면 여러 모듈에 중복 탑재되어 EXC_BAD_ACCESS 발생
let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture":       .framework,
        "Dependencies":                 .framework,
        "DependenciesMacros":           .framework,
        "CasePaths":                    .framework,
        "CasePathsMacros":              .framework,
        "SwiftNavigation":              .framework,
        "SwiftUINavigation":            .framework,
        "UIKitNavigation":              .framework,
        "Perception":                   .framework,
        "Sharing":                      .framework,
        "IdentifiedCollections":        .framework,
        "ConcurrencyExtras":            .framework,
        "Clocks":                       .framework,
        "CombineSchedulers":            .framework,
        "XCTestDynamicOverlay":         .framework,
        "IssueReporting":               .framework,
        "CustomDump":                   .framework,
    ]
)
#endif

let package = Package(
    name: "SuraSura",
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.15.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            from: "1.4.0"
        ),
    ]
)
