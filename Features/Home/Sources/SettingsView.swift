import SwiftUI
import ComposableArchitecture

private let kBlue = Color(red: 0.11, green: 0.53, blue: 0.87)

struct SettingsView: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            headerRow
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    appearanceCard
                    translationCard
                    versionFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - 드래그 핸들

    private var dragHandle: some View {
        Capsule()
            .fill(Color(.systemFill))
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    // MARK: - 헤더

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "settings.title", bundle: .module))
                    .font(.system(size: 24, weight: .bold))
                Text("すらすら")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            Button { store.send(.settingsDismissed) } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 30))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - 외관 카드

    private var appearanceCard: some View {
        settingsCard(
            icon: "paintbrush.fill",
            iconColor: Color.purple,
            title: String(localized: "settings.appearance", bundle: .module)
        ) {
            HStack(spacing: 8) {
                ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                    appearanceSegment(scheme)
                }
            }
            .padding(.top, 2)
        }
    }

    private func appearanceSegment(_ scheme: AppColorScheme) -> some View {
        let isSelected = store.appColorScheme == scheme
        return Button { store.send(.colorSchemeChanged(scheme)) } label: {
            VStack(spacing: 8) {
                Image(systemName: scheme.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? kBlue : Color.secondary)
                Text(scheme.shortLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? kBlue : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? kBlue.opacity(0.1) : Color(.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? kBlue.opacity(0.45) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: store.appColorScheme)
    }

    // MARK: - 번역 카드

    private var translationCard: some View {
        settingsCard(
            icon: "speaker.wave.2.fill",
            iconColor: kBlue,
            title: String(localized: "settings.translation", bundle: .module)
        ) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(String(localized: "settings.auto_speak", bundle: .module))
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.isAutoSpeakEnabled },
                        set: { _ in store.send(.autoSpeakToggled) }
                    ))
                    .labelsHidden()
                    .tint(kBlue)
                }
                .padding(.top, 2)

                Divider()
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Text(String(localized: "settings.auto_speak.footer", bundle: .module))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 버전

    private var versionFooter: some View {
        Text("v1.0.0")
            .font(.system(size: 12))
            .foregroundStyle(Color(.tertiaryLabel))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    // MARK: - 카드 컨테이너

    private func settingsCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 섹션 헤더
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }

            Divider()

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
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
    var shortLabel: String {
        switch self {
        case .system: return String(localized: "settings.appearance.system.short", bundle: .module)
        case .light:  return String(localized: "settings.appearance.light.short", bundle: .module)
        case .dark:   return String(localized: "settings.appearance.dark.short", bundle: .module)
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
