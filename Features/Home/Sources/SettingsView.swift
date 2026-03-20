import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        NavigationStack {
            appearanceSection
                .navigationTitle(String(localized: "settings.title", bundle: .module))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { doneButton }
        }
    }

    // MARK: - 외관 섹션 (별도 프로퍼티로 분리 → 타입 체크 속도 향상)

    private var appearanceSection: some View {
        List {
            Section {
                colorSchemeRow(.system)
                colorSchemeRow(.light)
                colorSchemeRow(.dark)
            } header: {
                Text(String(localized: "settings.appearance", bundle: .module))
            }
        }
    }

    private func colorSchemeRow(_ scheme: AppColorScheme) -> some View {
        Button {
            store.send(.colorSchemeChanged(scheme))
        } label: {
            colorSchemeLabel(scheme)
        }
        .buttonStyle(.plain)
    }

    private func colorSchemeLabel(_ scheme: AppColorScheme) -> some View {
        HStack {
            Label(scheme.label, systemImage: scheme.icon)
                .foregroundStyle(Color.primary)
            Spacer()
            if store.appColorScheme == scheme {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "settings.done", bundle: .module)) {
                store.send(.settingsDismissed)
            }
        }
    }
}

// MARK: - AppColorScheme UI Extensions

extension AppColorScheme {
    var label: String {
        switch self {
        case .system: return String(localized: "settings.appearance.system", bundle: .module)
        case .light:  return String(localized: "settings.appearance.light", bundle: .module)
        case .dark:   return String(localized: "settings.appearance.dark", bundle: .module)
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    public var swiftUIColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
