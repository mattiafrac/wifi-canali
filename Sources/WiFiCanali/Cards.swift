import SwiftUI
import WiFiCanaliCore

struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(spacing: 6) {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }
}

struct LevelBadge: View {
    let level: CongestionLevel

    var body: some View {
        Label {
            Text(level.label)
        } icon: {
            Image(systemName: level.symbol).foregroundStyle(level.color)
        }
        .font(.callout.weight(.medium))
    }
}

struct Tag: View {
    let text: String
    var color: Color = Palette.warning

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .fixedSize()
    }
}

struct ConnectionCard: View {
    let current: CurrentConnection?
    /// Canale e larghezza del router (può essere più larga di quella usata dal Mac).
    let router: ChannelRef?
    let evaluation: ChannelOption?
    let shownBand: Band

    var body: some View {
        Card(title: "La tua connessione", systemImage: "wifi") {
            if let c = current {
                let width = router?.width ?? c.width
                let channels = WiFiMath.channels(primary: c.channel, width: width, band: c.band)
                let isDFS = c.band == .ghz5 && channels.contains(where: WiFiMath.isDFS)
                let isWeather = c.band == .ghz5 && channels.contains(where: WiFiMath.isWeatherRadar)

                Text(c.ssid ?? "Rete attuale")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Canale \(c.channel) · \(width) MHz · \(c.band.rawValue)")
                    if isDFS { Tag(text: isWeather ? "RADAR METEO" : "DFS") }
                }
                .font(.callout)

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                    GridRow {
                        Text("Segnale").foregroundStyle(.secondary)
                        Text("\(c.rssi) dBm · \(signalLabel(c.rssi))")
                    }
                    GridRow {
                        Text("Rumore · SNR").foregroundStyle(.secondary)
                        Text("\(c.noise) dBm · \(c.snr) dB")
                    }
                    GridRow {
                        Text("Velocità").foregroundStyle(.secondary)
                        Text("\(Int(c.txRate)) Mbps · \(c.phyMode)")
                    }
                    if let e = evaluation {
                        GridRow {
                            Text("Interferenza").foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                LevelBadge(level: e.level)
                                Text("· \(e.neighborCount) \(e.neighborCount == 1 ? "rete" : "reti")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .font(.callout)
                .monospacedDigit()

                if isWeather {
                    Warning(text: "Canali dei radar meteo (120–128): all'accensione il router deve ascoltare 10 minuti prima di usarli e, se rileva un radar, deve cambiare canale. Tipica causa di cadute periodiche.")
                } else if isDFS {
                    Warning(text: "Canale DFS: se il router rileva un radar deve cambiare canale e la Wi‑Fi si interrompe per circa un minuto. Possibile causa di cadute periodiche.")
                }
                if c.band != shownBand {
                    Text("Sei connesso in \(c.band.rawValue): qui stai guardando la \(shownBand.rawValue).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Non connesso a una rete Wi‑Fi.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func signalLabel(_ rssi: Int) -> String {
        if rssi >= -55 { return "ottimo" }
        if rssi >= -67 { return "buono" }
        if rssi >= -75 { return "discreto" }
        return "debole"
    }
}

struct Warning: View {
    let text: String

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warning)
        }
        .font(.caption)
        .padding(8)
        .background(Palette.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RecommendationCard: View {
    let title: String
    let systemImage: String
    let option: ChannelOption?
    let current: ChannelOption?
    let emptyText: String

    var body: some View {
        Card(title: title, systemImage: systemImage) {
            if let o = option {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(o.primary)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(o.channels.count > 1 ? "Canale \(o.primary) · \(o.width) MHz" : "Canale \(o.primary)")
                            .font(.callout.weight(.medium))
                        if o.channels.count > 1 {
                            Text("occupa i canali \(o.rangeLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 6) {
                    LevelBadge(level: o.level)
                    Text("· \(o.neighborCount) \(o.neighborCount == 1 ? "rete" : "reti")")
                        .foregroundStyle(.secondary)
                    if o.isWeatherRadar {
                        Tag(text: "RADAR METEO")
                    } else if o.isDFS {
                        Tag(text: "DFS")
                    }
                }
                .font(.callout)
                comparison(o)
            } else {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func comparison(_ o: ChannelOption) -> some View {
        if let c = current {
            if c.channels == o.channels {
                Label("Il tuo router è già qui", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if Set(o.channels).isSubset(of: c.channels) {
                Text("È una parte del blocco che il router usa ora (\(c.rangeLabel), \(c.width) MHz): basta impostare canale \(o.primary) a \(o.width) MHz.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(String(format: "Indice interferenza %.1f (canale attuale: %.1f)", o.score, c.score))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Somma delle reti che si sovrappongono, pesate per segnale: 1 ≈ una rete forte.")
            }
        } else {
            Text(String(format: "Indice interferenza %.1f", o.score))
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Somma delle reti che si sovrappongono, pesate per segnale: 1 ≈ una rete forte.")
        }
    }
}

struct LocationBanner: View {
    @EnvironmentObject private var location: LocationAccess

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.title3)
                .foregroundStyle(Palette.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nomi delle reti nascosti")
                    .font(.callout.weight(.semibold))
                Text("macOS mostra i nomi delle reti solo alle app con accesso a Posizione. Canali e segnali funzionano lo stesso, ma senza nomi la tua rete viene riconosciuta solo per approssimazione. La posizione non viene letta né salvata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(location.isUndetermined ? "Consenti" : "Apri Impostazioni") { location.request() }
        }
        .padding(12)
        .background(Palette.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ErrorBanner: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(Palette.critical)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.critical.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
