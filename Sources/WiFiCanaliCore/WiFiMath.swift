import Foundation

/// Geometria dei canali Wi‑Fi: frequenze, blocchi 40/80/160 MHz, sovrapposizioni.
public enum WiFiMath {
    /// Frequenza centrale (MHz) del canale da 20 MHz.
    public static func frequency(channel: Int, band: Band) -> Double {
        switch band {
        case .ghz24: return channel == 14 ? 2484 : Double(2407 + 5 * channel)
        case .ghz5: return Double(5000 + 5 * channel)
        case .ghz6: return Double(5950 + 5 * channel)
        }
    }

    /// Primo canale da 20 MHz del blocco 40/80/160 MHz che contiene il canale primario.
    /// In 5 GHz i blocchi sono allineati a partire da 36 (UNII‑1/2) e da 149 (UNII‑3).
    public static func blockBase(primary: Int, width: Int, band: Band) -> Int {
        let step = max(width, 20) / 5
        let origin: Int
        switch band {
        case .ghz24:
            return primary
        case .ghz5:
            guard primary >= 36 else { return primary }
            origin = primary >= 149 ? 149 : 36
        case .ghz6:
            origin = 1
        }
        return origin + ((primary - origin) / step) * step
    }

    /// Canali da 20 MHz occupati da una rete.
    public static func channels(primary: Int, width: Int, band: Band) -> [Int] {
        guard band != .ghz24, width > 20 else { return [primary] }
        let base = blockBase(primary: primary, width: width, band: band)
        return Array(stride(from: base, to: base + width / 5, by: 4))
    }

    /// Porzione di spettro (MHz) occupata da una rete con canale primario e larghezza dati.
    public static func span(channel: Int, width: Int, band: Band) -> ClosedRange<Double> {
        let f = frequency(channel: channel, band: band)
        switch band {
        case .ghz24:
            guard width >= 40 else { return (f - 10)...(f + 10) }
            // CoreWLAN non dice da che lato sta il canale secondario: usiamo la convenzione più comune.
            return channel <= 7 ? (f - 10)...(f + 30) : (f - 30)...(f + 10)
        case .ghz5, .ghz6:
            let base = blockBase(primary: channel, width: width, band: band)
            let low = frequency(channel: base, band: band) - 10
            return low...(low + Double(max(width, 20)))
        }
    }

    /// Frazione di sovrapposizione rispetto alla più stretta delle due: 0 = nessuna, 1 = totale.
    public static func overlap(_ a: ClosedRange<Double>, _ b: ClosedRange<Double>) -> Double {
        let shared = min(a.upperBound, b.upperBound) - max(a.lowerBound, b.lowerBound)
        guard shared > 0 else { return 0 }
        let narrower = min(a.upperBound - a.lowerBound, b.upperBound - b.lowerBound)
        return min(shared / narrower, 1)
    }

    /// Quanto pesa una rete vicina in base al segnale: 0 a −95 dBm, 1 da −50 dBm in su.
    /// Lineare in dB: una rete a −70 dBm vale circa mezza rete "forte".
    public static func weight(rssi: Int) -> Double {
        min(max(Double(rssi + 95) / 45, 0), 1)
    }

    /// Canali DFS: il router deve ascoltare i radar e, se ne rileva uno, cambiare canale.
    public static func isDFS(_ channel: Int) -> Bool { (52...144).contains(channel) }

    /// Canali dei radar meteo (120–128): in Europa richiedono 10 minuti di ascolto prima dell'uso.
    public static func isWeatherRadar(_ channel: Int) -> Bool { (120...128).contains(channel) }

    /// Canali da 20 MHz mostrati nei grafici.
    public static func displayChannels(band: Band) -> [Int] {
        switch band {
        case .ghz24:
            return Array(1...13)
        case .ghz5:
            return [36, 40, 44, 48, 52, 56, 60, 64]
                + Array(stride(from: 100, through: 144, by: 4))
                + [149, 153, 157, 161, 165]
        case .ghz6:
            return Array(stride(from: 1, through: 233, by: 4))
        }
    }

    /// Canali da 20 MHz utilizzabili dal router nella regione scelta.
    public static func allowedChannels(band: Band, region: Region) -> [Int] {
        switch band {
        case .ghz24:
            // Gli unici tre canali che non si sovrappongono tra loro.
            return [1, 6, 11]
        case .ghz5:
            var channels = [36, 40, 44, 48, 52, 56, 60, 64] + Array(stride(from: 100, through: 140, by: 4))
            if region == .usa { channels += [144, 149, 153, 157, 161, 165] }
            return channels
        case .ghz6:
            return []
        }
    }
}
