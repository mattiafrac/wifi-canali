import SwiftUI
import WiFiCanaliCore

struct NetworkTable: View {
    let networks: [WiFiNetwork]
    @State private var sortOrder = [KeyPathComparator(\WiFiNetwork.rssi, order: .reverse)]

    var body: some View {
        Table(networks.sorted(using: sortOrder), sortOrder: $sortOrder) {
            TableColumn("Rete", value: \.displayName) { n in
                HStack(spacing: 6) {
                    Circle()
                        .fill(n.isOwn ? Palette.own : Palette.neighbor)
                        .frame(width: 8, height: 8)
                    Text(n.displayName)
                        .foregroundStyle(n.hasName ? .primary : .secondary)
                    if n.isOwn {
                        Text("tua").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 160, ideal: 240)

            TableColumn("Segnale", value: \.rssi) { n in
                HStack(spacing: 6) {
                    Image(systemName: "wifi", variableValue: WiFiMath.weight(rssi: n.rssi))
                    Text("\(n.rssi) dBm").monospacedDigit()
                }
            }
            .width(min: 90, ideal: 100)

            TableColumn("Canale", value: \.channel) { n in
                Text("\(n.channel)").monospacedDigit()
            }
            .width(min: 50, ideal: 60)

            TableColumn("Larghezza", value: \.width) { n in
                Text("\(n.width) MHz").monospacedDigit()
            }
            .width(min: 70, ideal: 80)

            TableColumn("Occupa i canali") { n in
                HStack(spacing: 6) {
                    Text(n.blockLabel).monospacedDigit().lineLimit(1)
                    if n.band == .ghz5, WiFiMath.channels(primary: n.channel, width: n.width, band: n.band).contains(where: WiFiMath.isDFS) {
                        Tag(text: "DFS")
                    }
                }
            }
            .width(min: 110, ideal: 130)

            TableColumn("BSSID", value: \.bssidText) { n in
                Text(n.bssid ?? "—")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)
        }
        .frame(height: 320)
    }
}
