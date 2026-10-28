import Foundation

/// La rete a cui il Mac è connesso ora.
public struct CurrentConnection: Equatable, Sendable {
    public var ssid: String?
    public var bssid: String?
    public var band: Band
    public var channel: Int
    public var width: Int
    public var rssi: Int
    public var noise: Int
    public var txRate: Double
    public var phyMode: String

    public init(
        ssid: String?, bssid: String?, band: Band, channel: Int, width: Int,
        rssi: Int, noise: Int, txRate: Double = 0, phyMode: String = "—"
    ) {
        self.ssid = ssid
        self.bssid = bssid
        self.band = band
        self.channel = channel
        self.width = width
        self.rssi = rssi
        self.noise = noise
        self.txRate = txRate
        self.phyMode = phyMode
    }

    public var snr: Int { rssi - noise }
    public var ref: ChannelRef { ChannelRef(channel: channel, width: width) }
    public var blockLabel: String {
        let channels = WiFiMath.channels(primary: channel, width: width, band: band)
        return channels.count > 1 ? "\(channels.first!)–\(channels.last!)" : "\(channel)"
    }
}

public enum OwnNetwork {
    /// Segna le reti del tuo router, che non devono contare come interferenza.
    public static func mark(_ networks: [WiFiNetwork], current: CurrentConnection?) -> [WiFiNetwork] {
        guard let current else {
            return networks.map { var n = $0; n.isOwn = false; return n }
        }
        // Le reti senza BSSID (permesso Posizione assente, o non ancora attivo alla prima scansione)
        // non si possono confrontare per nome: indoviniamo la rete a cui sei connesso cercando
        // quella sullo stesso canale con il segnale più simile.
        // (Non confrontiamo la larghezza: il Mac può usarne una minore del router, es. 80 su 160 MHz.)
        let guess = networks
            .filter { $0.bssid == nil && $0.band == current.band && $0.channel == current.channel }
            .min { abs($0.rssi - current.rssi) < abs($1.rssi - current.rssi) }
        let router = guess.flatMap { abs($0.rssi - current.rssi) <= 6 ? $0 : nil }

        return networks.map { network in
            var n = network
            let sameSSID = current.ssid != nil && n.ssid == current.ssid
            let sameRouter = n.bssid.map { sameDevice($0, current.bssid) } ?? false
            // Anche le altre reti della stessa radio (es. ospiti) sono tue.
            let guessed = n.bssid == nil && (router.map { n.id == $0.id || sameRadio(n, $0, tolerance: 4) } ?? false)
            n.isOwn = sameSSID || sameRouter || guessed
            return n
        }
    }

    /// Canale e larghezza su cui trasmette davvero il tuo router: il Mac può collegarsi
    /// con una larghezza minore, ma l'interferenza va valutata su tutto lo spettro del router.
    public static func routerChannel(_ current: CurrentConnection, in marked: [WiFiNetwork]) -> ChannelRef {
        let router = marked.first { $0.isOwn && $0.band == current.band && $0.channel == current.channel }
        return ChannelRef(channel: current.channel, width: max(router?.width ?? 0, current.width))
    }

    /// Le reti dello stesso router (2.4/5 GHz, ospiti) hanno BSSID che di solito
    /// differiscono solo nel primo o nell'ultimo byte.
    public static func sameDevice(_ a: String, _ b: String?) -> Bool {
        guard let b else { return false }
        let pa = a.lowercased().split(separator: ":"), pb = b.lowercased().split(separator: ":")
        guard pa.count == 6, pb.count == 6 else { return a.lowercased() == b.lowercased() }
        return pa[1...4] == pb[1...4]
    }

    /// Più reti trasmesse dalla stessa radio (es. principale + ospiti) occupano l'aria una volta sola.
    /// Senza BSSID ci basiamo sul segnale quasi identico (`tolerance` in dB).
    static func sameRadio(_ a: WiFiNetwork, _ b: WiFiNetwork, tolerance: Int = 1) -> Bool {
        guard a.band == b.band, a.channel == b.channel, a.width == b.width else { return false }
        if let ba = a.bssid, let bb = b.bssid { return sameDevice(ba, bb) }
        return abs(a.rssi - b.rssi) <= tolerance
    }

    /// Una voce per radio fisica, tenendo il segnale più forte.
    public static func radios(_ networks: [WiFiNetwork]) -> [WiFiNetwork] {
        var result: [WiFiNetwork] = []
        for network in networks.sorted(by: { $0.rssi > $1.rssi }) where !result.contains(where: { sameRadio($0, network) }) {
            result.append(network)
        }
        return result
    }
}
