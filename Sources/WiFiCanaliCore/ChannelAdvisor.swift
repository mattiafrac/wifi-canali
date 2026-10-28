import Foundation

public enum CongestionLevel: Int, Comparable, Sendable {
    case free, low, medium, high

    /// Il punteggio è circa il numero di "reti forti equivalenti" che condividono lo spettro.
    public init(score: Double) {
        switch score {
        case ..<0.15: self = .free
        case ..<0.8: self = .low
        case ..<2.0: self = .medium
        default: self = .high
        }
    }

    public var label: String {
        switch self {
        case .free: return "Libero"
        case .low: return "Poco usato"
        case .medium: return "Moderato"
        case .high: return "Affollato"
        }
    }

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Un canale (o blocco 40/80/160 MHz) valutato.
public struct ChannelOption: Identifiable, Hashable, Sendable {
    public var id: String { "\(band.rawValue)-\(primary)-\(width)" }
    public let band: Band
    /// Canale da impostare sul router.
    public let primary: Int
    /// Canali da 20 MHz coperti dal blocco.
    public let channels: [Int]
    public let width: Int
    public let span: ClosedRange<Double>
    /// Interferenza stimata: somma delle reti sovrapposte pesate per segnale.
    public let score: Double
    public let neighborCount: Int

    public var isDFS: Bool { channels.contains(where: WiFiMath.isDFS) }
    public var isWeatherRadar: Bool { channels.contains(where: WiFiMath.isWeatherRadar) }
    public var level: CongestionLevel { CongestionLevel(score: score) }
    public var rangeLabel: String {
        channels.count > 1 ? "\(channels.first!)–\(channels.last!)" : "\(primary)"
    }
}

/// Occupazione di un singolo canale da 20 MHz.
public struct ChannelLoad: Identifiable, Hashable, Sendable {
    public var id: Int { channel }
    public let channel: Int
    public let score: Double
    public let neighborCount: Int
}

public struct ChannelRef: Hashable, Sendable {
    public let channel: Int
    public let width: Int

    public init(channel: Int, width: Int) {
        self.channel = channel
        self.width = width
    }
}

public struct Recommendation: Sendable {
    /// Tutte le opzioni valide, dalla migliore alla peggiore.
    public let options: [ChannelOption]
    public let loads: [ChannelLoad]
    /// Valutazione del canale su cui sei connesso ora (se nella stessa banda).
    public let current: ChannelOption?

    public var best: ChannelOption? { options.first }
    public var bestWithoutDFS: ChannelOption? { options.first { !$0.isDFS } }
}

public enum ChannelAdvisor {
    public static func recommend(
        networks: [WiFiNetwork],
        band: Band,
        width: Int,
        region: Region,
        current: ChannelRef? = nil
    ) -> Recommendation {
        let neighbors = OwnNetwork.radios(networks.filter { $0.band == band && !$0.isOwn })
        let width = band == .ghz24 ? 20 : width

        func interference(over span: ClosedRange<Double>) -> (score: Double, count: Int) {
            var score = 0.0
            var count = 0
            for network in neighbors {
                let overlap = WiFiMath.overlap(network.span, span)
                guard overlap > 0 else { continue }
                score += overlap * WiFiMath.weight(rssi: network.rssi)
                count += 1
            }
            return (score, count)
        }

        let loads = WiFiMath.displayChannels(band: band).map { channel in
            let result = interference(over: WiFiMath.span(channel: channel, width: 20, band: band))
            return ChannelLoad(channel: channel, score: result.score, neighborCount: result.count)
        }
        let loadByChannel = Dictionary(uniqueKeysWithValues: loads.map { ($0.channel, $0.score) })

        func evaluate(primary: Int, width: Int, choosePrimary: Bool) -> ChannelOption {
            let channels = WiFiMath.channels(primary: primary, width: width, band: band)
            let span = WiFiMath.span(channel: primary, width: width, band: band)
            let result = interference(over: span)
            // Dentro il blocco, il primario va sul canale da 20 MHz meno usato dalle reti strette.
            let chosen = choosePrimary
                ? channels.min { (loadByChannel[$0] ?? 0) < (loadByChannel[$1] ?? 0) } ?? primary
                : primary
            return ChannelOption(
                band: band, primary: chosen, channels: channels, width: width,
                span: span, score: result.score, neighborCount: result.count
            )
        }

        let allowed = WiFiMath.allowedChannels(band: band, region: region)
        let allowedSet = Set(allowed)
        var options: [ChannelOption] = []
        if band == .ghz24 {
            options = allowed.map { evaluate(primary: $0, width: 20, choosePrimary: false) }
        } else {
            for origin in [36, 149] {
                for base in stride(from: origin, to: origin + 32 * 4, by: width / 5) {
                    let block = WiFiMath.channels(primary: base, width: width, band: band)
                    guard block.allSatisfy(allowedSet.contains) else { continue }
                    options.append(evaluate(primary: base, width: width, choosePrimary: true))
                }
            }
        }

        // I canali DFS possono far cadere la connessione quando il router rileva un radar:
        // li penalizziamo un po'. Quelli dei radar meteo (10 minuti di ascolto in Europa, rilevamenti
        // più frequenti) molto di più: vincono solo se nettamente più liberi.
        // A parità: meglio non DFS, poi non radar meteo, poi canale più basso.
        func rank(_ o: ChannelOption) -> Double {
            o.score + (o.isDFS ? 0.25 : 0) + (o.isWeatherRadar ? 1.0 : 0)
        }
        options.sort { a, b in
            let qa = (rank(a) * 20).rounded(), qb = (rank(b) * 20).rounded()
            if qa != qb { return qa < qb }
            if a.isDFS != b.isDFS { return !a.isDFS }
            if a.isWeatherRadar != b.isWeatherRadar { return !a.isWeatherRadar }
            return a.primary < b.primary
        }

        let currentOption = current.map {
            evaluate(primary: $0.channel, width: band == .ghz24 ? 20 : $0.width, choosePrimary: false)
        }
        return Recommendation(options: options, loads: loads, current: currentOption)
    }
}
