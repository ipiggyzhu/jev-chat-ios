import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            AssistantView()
                .tabItem { Label("助手", systemImage: "text.bubble") }
            KnowledgeView()
                .tabItem { Label("知识库", systemImage: "books.vertical") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
