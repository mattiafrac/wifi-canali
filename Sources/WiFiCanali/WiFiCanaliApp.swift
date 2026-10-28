import AppKit
import SwiftUI

struct WiFiCanaliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = WiFiStore()
    @StateObject private var location = LocationAccess()

    var body: some Scene {
        Window("Canali Wi‑Fi", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(location)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1200, height: 940)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scansiona ora") { store.scan() }
                    .keyboardShortcut("r")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
