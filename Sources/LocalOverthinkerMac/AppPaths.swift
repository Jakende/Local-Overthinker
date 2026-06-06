import Foundation

enum AppPaths {
    static var userDataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("Local Overthinker", isDirectory: true)
    }

    static var stateFileURL: URL {
        userDataDirectory.appendingPathComponent("state.json")
    }
}
