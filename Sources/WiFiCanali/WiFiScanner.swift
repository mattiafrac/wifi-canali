import CoreWLAN
import Foundation
import WiFiCanaliCore

struct ScanResult: Sendable {
    var interfaceName: String
    var networks: [WiFiNetwork]
    var current: CurrentConnection?
}

enum ScanError: LocalizedError {
    case noInterface
    case wifiOff
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .noInterface: return "Nessuna interfaccia Wi‑Fi trovata."
        case .wifiOff: return "Il Wi‑Fi è spento: accendilo per scansionare le reti."
        case .failed(let message): return "Scansione non riuscita: \(message)"
        }
    }
}

/// Scansione tramite CoreWLAN. È bloccante (qualche secondo): va chiamata fuori dal main thread.
enum WiFiScanner {
    static func scan() throws -> ScanResult {
        guard let iface = CWWiFiClient.shared().interface() else { throw ScanError.noInterface }
        guard iface.powerOn() else { throw ScanError.wifiOff }

        let found: Set<CWNetwork>
        do {
            found = try iface.scanForNetworks(withSSID: nil, includeHidden: true)
        } catch {
            throw ScanError.failed(error.localizedDescription)
        }

        let now = Date()
        var anonymous = 0
        let networks: [WiFiNetwork] = found.compactMap { network in
            guard let channel = network.wlanChannel, let band = band(of: channel) else { return nil }
            let id: String
            if let bssid = network.bssid {
                id = bssid.lowercased()
            } else {
                // Senza permesso Posizione macOS non fornisce il BSSID: l'id vale solo per questa scansione.
                anonymous += 1
                id = "anon-\(anonymous)"
            }
            return WiFiNetwork(
                id: id, ssid: network.ssid, bssid: network.bssid?.lowercased(), band: band,
                channel: channel.channelNumber, width: width(of: channel),
                rssi: network.rssiValue, noise: network.noiseMeasurement, lastSeen: now
            )
        }

        var current: CurrentConnection?
        if let channel = iface.wlanChannel(), let band = band(of: channel), iface.rssiValue() != 0 {
            current = CurrentConnection(
                ssid: iface.ssid(), bssid: iface.bssid()?.lowercased(), band: band,
                channel: channel.channelNumber, width: width(of: channel),
                rssi: iface.rssiValue(), noise: iface.noiseMeasurement(),
                txRate: iface.transmitRate(), phyMode: phyName(iface.activePHYMode())
            )
        }

        return ScanResult(interfaceName: iface.interfaceName ?? "Wi‑Fi", networks: networks, current: current)
    }

    private static func band(of channel: CWChannel) -> Band? {
        switch channel.channelBand {
        case .band2GHz: return .ghz24
        case .band5GHz: return .ghz5
        case .band6GHz: return .ghz6
        default: return nil
        }
    }

    private static func width(of channel: CWChannel) -> Int {
        switch channel.channelWidth {
        case .width40MHz: return 40
        case .width80MHz: return 80
        case .width160MHz: return 160
        default: return 20
        }
    }

    private static func phyName(_ mode: CWPHYMode) -> String {
        switch mode {
        case .mode11a: return "802.11a"
        case .mode11b: return "802.11b"
        case .mode11g: return "802.11g"
        case .mode11n: return "Wi‑Fi 4 (n)"
        case .mode11ac: return "Wi‑Fi 5 (ac)"
        case .mode11ax: return "Wi‑Fi 6 (ax)"
        default: return mode.rawValue >= 7 ? "Wi‑Fi 7 (be)" : "—"
        }
    }
}
