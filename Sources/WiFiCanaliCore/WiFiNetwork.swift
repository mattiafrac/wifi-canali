import Foundation

public enum Band: String, CaseIterable, Identifiable, Sendable {
    case ghz24 = "2.4 GHz"
    case ghz5 = "5 GHz"
    case ghz6 = "6 GHz"

    public var id: String { rawValue }
}

public enum Region: String, CaseIterable, Identifiable, Sendable {
    case europe = "Europa"
    case usa = "USA"

    public var id: String { rawValue }
}

/// Una rete vista durante la scansione.
public struct WiFiNetwork: Identifiable, Hashable, Sendable {
    public var id: String
    public var ssid: String?
    public var bssid: String?
    public var band: Band
    /// Canale primario (quello su cui viaggiano i beacon).
    public var channel: Int
    /// Larghezza di banda in MHz: 20, 40, 80 o 160.
    public var width: Int
    public var rssi: Int
    public var noise: Int
    /// Rete del proprio router: non conta come interferenza.
    public var isOwn: Bool
    public var lastSeen: Date

    public init(
        id: String, ssid: String?, bssid: String?, band: Band, channel: Int, width: Int,
        rssi: Int, noise: Int = 0, isOwn: Bool = false, lastSeen: Date = Date()
    ) {
        self.id = id
        self.ssid = ssid
        self.bssid = bssid
        self.band = band
        self.channel = channel
        self.width = width
        self.rssi = rssi
        self.noise = noise
        self.isOwn = isOwn
        self.lastSeen = lastSeen
    }

    public var hasName: Bool { !(ssid ?? "").isEmpty }
    public var displayName: String { hasName ? ssid! : "(nome nascosto)" }

    /// Spettro occupato in MHz.
    public var span: ClosedRange<Double> {
        WiFiMath.span(channel: channel, width: width, band: band)
    }

    /// Canali da 20 MHz coperti, es. "36–48" per un 80 MHz.
    public var blockLabel: String {
        let channels = WiFiMath.channels(primary: channel, width: width, band: band)
        guard channels.count > 1 else { return "\(channel)" }
        return "\(channels.first!)–\(channels.last!)"
    }
}
