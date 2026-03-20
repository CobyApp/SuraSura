import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Button {
                            store.send(.colorSchemeChanged(scheme))
                        } label: {
                            HStack {
                                Label(scheme.label, systemImage: scheme.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if store.appColorScheme == scheme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accentColor)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(String(localized: "settings.appearance", bundle: .module))
                }
            }
            .navigationTitle(String(localized: "settings.title", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.done", bundle: .module)) {
                        store.send(.settingsDismissed)
                    }
                }
            }
        }
    }
}

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
