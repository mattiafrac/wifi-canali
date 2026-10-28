import Foundation
import WiFiCanaliCore

/// `WiFiCanali --scan [--width 80] [--usa]`: stampa reti e canale consigliato nel terminale.
enum ScanCLI {
    static func run(arguments: [String]) -> Int32 {
        let width = arguments.firstIndex(of: "--width").flatMap { Int(arguments[safe: $0 + 1] ?? "") } ?? 80
        let region: Region = arguments.contains("--usa") ? .usa : .europe

        let scan: ScanResult
        do {
            scan = try WiFiScanner.scan()
        } catch {
            print(error.localizedDescription)
            return 1
        }

        if let c = scan.current {
            print("\(scan.interfaceName): connesso a \(c.ssid ?? "(nome nascosto)") — canale \(c.channel), \(c.width) MHz, \(c.band.rawValue), \(c.rssi) dBm, SNR \(c.snr) dB")
        } else {
            print("\(scan.interfaceName): non connesso")
        }
        print("Reti trovate: \(scan.networks.count)\n")

        for band in [Band.ghz5, .ghz24] {
            let marked = OwnNetwork.mark(scan.networks, current: scan.current)
            let networks = marked.filter { $0.band == band }.sorted { ($0.channel, -$0.rssi) < ($1.channel, -$1.rssi) }
            print("== \(band.rawValue) (\(networks.count) reti) ==")
            for n in networks {
                let line = String(format: "  ch %3d  %3d MHz  %4d dBm  ", n.channel, n.width, n.rssi)
                print(line + n.displayName + (n.isOwn ? "  ← tua" : ""))
            }
            let current = scan.current.flatMap { $0.band == band ? OwnNetwork.routerChannel($0, in: marked) : nil }
            let rec = ChannelAdvisor.recommend(networks: networks, band: band, width: width, region: region, current: current)
            if let best = rec.best { print("  → Consigliato: " + describe(best)) }
            if band == .ghz5, let safe = rec.bestWithoutDFS, safe != rec.best { print("  → Senza DFS:   " + describe(safe)) }
            if let now = rec.current { print("  → Attuale:     " + describe(now)) }
            print("")
        }
        return 0
    }

    private static func describe(_ o: ChannelOption) -> String {
        var text = "canale \(o.primary)"
        if o.channels.count > 1 { text += " (blocco \(o.rangeLabel), \(o.width) MHz)" }
        text += String(format: " — %d reti sovrapposte, indice %.2f, %@", o.neighborCount, o.score, o.level.label)
        if o.isDFS { text += " [DFS]" }
        return text
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
