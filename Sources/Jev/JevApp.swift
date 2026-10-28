import SwiftUI

@main
struct JevApp: App {
    @StateObject private var store = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
