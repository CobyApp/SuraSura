import SwiftUI
import ComposableArchitecture
import HomeFeature

@main
struct SuraSuraApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(
                store: Store(initialState: HomeReducer.State()) {
                    HomeReducer()
                }
            )
        }
    }
}
