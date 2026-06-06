import SwiftUI

@main
struct LocalOverthinkerMacApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("Local Overthinker") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 960, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
