import AppKit
import SwiftUI

/// Solo per sviluppo: `WiFiCanali --snapshot out.png [--dark]` salva un'immagine della
/// dashboard dopo la prima scansione ed esce. Usa ImageRenderer, quindi i controlli
/// AppKit (tabella, menu a tendina) compaiono come segnaposto.
enum Snapshot {
    static var path: String? {
        let args = CommandLine.arguments
        return args.firstIndex(of: "--snapshot").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
    }

    static var isDark: Bool { CommandLine.arguments.contains("--dark") }

    @MainActor
    static func capture(store: WiFiStore, location: LocationAccess) async {
        guard let path else { return }
        if isDark { NSApp.appearance = NSAppearance(named: .darkAqua) }
        try? await Task.sleep(for: .seconds(8))

        let view = DashboardView()
            .padding(20)
            .frame(width: 1200)
            .background(Color(nsColor: .windowBackgroundColor))
            .environmentObject(store)
            .environmentObject(location)
            .environment(\.colorScheme, isDark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
            print("Snapshot salvato in \(path)")
        }
        NSApp.terminate(nil)
    }
}
