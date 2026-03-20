import SwiftUI
import ComposableArchitecture
import HomeFeature

@main
struct SuraSuraApp: App {
    // 앱 수명 내내 유지되는 Store (colorScheme 상태 보존)
    let store = Store(initialState: HomeReducer.State()) {
        HomeReducer()
    }

    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
        }
    }
}
