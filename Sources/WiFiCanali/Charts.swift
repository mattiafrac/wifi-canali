import Charts
import SwiftUI
import WiFiCanaliCore

/// Asse delle frequenze condiviso dai due grafici, così i canali restano allineati in verticale.
struct FrequencyAxis {
    let band: Band

    /// In 5 GHz comprimiamo il buco 5330–5490 MHz (canali 68–96, non usati dal Wi‑Fi).
    func x(_ frequency: Double) -> Double {
        band == .ghz5 && frequency > 5410 ? frequency - 120 : frequency
    }

    func x(channel: Int) -> Double { x(WiFiMath.frequency(channel: channel, band: band)) }

    var domain: ClosedRange<Double> {
        band == .ghz24 ? 2397...2487 : x(5165)...x(5840)
    }

    var channels: [Int] { WiFiMath.displayChannels(band: band) }
    var ticks: [Double] { channels.map { x(channel: $0) } }

    func channel(atX value: Double) -> Int {
        channels.min { abs(x(channel: $0) - value) < abs(x(channel: $1) - value) } ?? channels[0]
    }

    var dfsRange: ClosedRange<Double>? { band == .ghz5 ? x(5250)...x(5730) : nil }
    var weatherRange: ClosedRange<Double>? { band == .ghz5 ? x(5590)...x(5650) : nil }

    func range(_ span: ClosedRange<Double>) -> ClosedRange<Double> { x(span.lowerBound)...x(span.upperBound) }
}

extension FrequencyAxis {
    /// Asse X con i numeri di canale, uguale per tutti i grafici.
    var channelMarks: some AxisContent {
        AxisMarks(values: ticks) { value in
            AxisGridLine()
            AxisValueLabel(anchor: .top) {
                Text("\(channel(atX: value.as(Double.self) ?? 0))")
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
    }
}

/// Tooltip al passaggio del mouse, con linea verticale gestita dal grafico.
struct ChartHover<Tooltip: View>: ViewModifier {
    @Binding var x: Double?
    @ViewBuilder let tooltip: (Double) -> Tooltip
    @State private var location: CGPoint = .zero

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geo in
                let plot = proxy.plotFrame.map { geo[$0] } ?? .zero
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let point):
                                location = point
                                x = plot.contains(point) ? proxy.value(atX: point.x - plot.minX, as: Double.self) : nil
                            case .ended:
                                x = nil
                            }
                        }
                    if let x {
                        let onLeft = location.x < geo.size.width / 2
                        tooltip(x)
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                            .fixedSize()
                            .frame(maxWidth: .infinity, alignment: onLeft ? .leading : .trailing)
                            .padding(onLeft ? .leading : .trailing, onLeft ? location.x + 16 : geo.size.width - location.x + 16)
                            .padding(.top, plot.minY + 4)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }
}

/// Elenco delle reti che occupano un canale da 20 MHz.
struct ChannelTooltip: View {
    let channel: Int
    let band: Band
    let networks: [WiFiNetwork]
    let load: ChannelLoad?

    var body: some View {
        let span = WiFiMath.span(channel: channel, width: 20, band: band)
        let here = networks
            .filter { WiFiMath.overlap($0.span, span) > 0 }
            .sorted { $0.rssi > $1.rssi }

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Canale \(channel)").font(.callout.weight(.semibold))
                if band == .ghz5, WiFiMath.isDFS(channel) {
                    Tag(text: WiFiMath.isWeatherRadar(channel) ? "RADAR METEO" : "DFS")
                }
                Spacer(minLength: 16)
                if let load {
                    Text(String(format: "indice %.1f", load.score)).foregroundStyle(.secondary)
                }
            }
            if here.isEmpty {
                Text("Nessuna rete su questo canale").foregroundStyle(.secondary)
            }
            ForEach(here.prefix(10)) { n in
                HStack(spacing: 6) {
                    Circle()
                        .fill(n.isOwn ? Palette.own : Palette.neighbor)
                        .frame(width: 8, height: 8)
                    Text(n.isOwn ? "\(n.displayName) (tua)" : n.displayName)
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .leading)
                    Spacer(minLength: 12)
                    Text("\(n.rssi) dBm · \(n.width) MHz")
                        .foregroundStyle(.secondary)
                }
            }
            if here.count > 10 {
                Text("e altre \(here.count - 10)…").foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .monospacedDigit()
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    var isBand = false

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: isBand ? 2 : 1)
                .fill(isBand ? color.opacity(0.25) : color)
                .frame(width: isBand ? 14 : 14, height: isBand ? 10 : 3)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Spettro

struct SpectrumChart: View {
    let networks: [WiFiNetwork]
    let band: Band
    let recommended: ChannelOption?
    let loads: [ChannelLoad]
    @State private var hoverX: Double?

    static let floor = -100.0
    static let top = -15.0

    private var axis: FrequencyAxis { FrequencyAxis(band: band) }

    private struct Point: Identifiable {
        let id: String
        let network: String
        let x: Double
        let y: Double
        let isOwn: Bool
        let isHighlighted: Bool
    }

    var body: some View {
        Chart {
            backgroundBands
            networkShapes
            networkLabels
            if let hoverX {
                RuleMark(x: .value("MHz", hoverX))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXScale(domain: axis.domain)
        .chartYScale(domain: Self.floor...Self.top)
        .chartXAxis { axis.channelMarks }
        .chartYAxis {
            AxisMarks(position: .leading, values: [-90.0, -80, -70, -60, -50, -40, -30]) { value in
                AxisGridLine()
                AxisValueLabel {
                    Text("\(Int(value.as(Double.self) ?? 0))")
                        .font(.caption2)
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .chartLegend(.hidden)
        .modifier(ChartHover(x: $hoverX) { x in
            let channel = axis.channel(atX: x)
            ChannelTooltip(channel: channel, band: band, networks: networks, load: loads.first { $0.channel == channel })
        })
    }

    @ChartContentBuilder
    private var backgroundBands: some ChartContent {
        if let dfs = axis.dfsRange {
            RectangleMark(
                xStart: .value("Da", dfs.lowerBound), xEnd: .value("A", dfs.upperBound),
                yStart: .value("Base", Self.floor), yEnd: .value("Cima", Self.top)
            )
            .foregroundStyle(Palette.muted.opacity(0.08))
            .annotation(position: .overlay, alignment: .topLeading) {
                Text("DFS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(4)
            }
        }
        if let weather = axis.weatherRange {
            RectangleMark(
                xStart: .value("Da", weather.lowerBound), xEnd: .value("A", weather.upperBound),
                yStart: .value("Base", Self.floor), yEnd: .value("Cima", Self.top)
            )
            .foregroundStyle(Palette.muted.opacity(0.10))
            .annotation(position: .overlay, alignment: .topTrailing) {
                Text("Radar meteo").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(4)
            }
        }
        if let recommended {
            let r = axis.range(recommended.span)
            RectangleMark(
                xStart: .value("Da", r.lowerBound), xEnd: .value("A", r.upperBound),
                yStart: .value("Base", Self.floor), yEnd: .value("Cima", Self.top)
            )
            .foregroundStyle(Palette.good.opacity(0.14))
            // Seconda riga, sotto le etichette DFS / radar meteo, per non sovrapporsi.
            .annotation(position: .overlay, alignment: .topLeading) {
                Label("Consigliato", systemImage: "checkmark")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 4)
                    .padding(.top, 22)
            }
        }
    }

    @ChartContentBuilder
    private var networkShapes: some ChartContent {
        ForEach(points) { p in
            AreaMark(
                x: .value("MHz", p.x),
                yStart: .value("Base", Self.floor),
                yEnd: .value("Segnale", p.y),
                series: .value("Rete", p.network)
            )
            .foregroundStyle((p.isOwn ? Palette.own : Palette.neighbor).opacity(p.isOwn ? 0.14 : 0.07))

            LineMark(x: .value("MHz", p.x), y: .value("Segnale", p.y), series: .value("Rete", p.network))
                .foregroundStyle(p.isOwn ? Palette.own : Palette.neighbor)
                .lineStyle(StrokeStyle(lineWidth: p.isOwn || p.isHighlighted ? 2.5 : 1.2, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private var networkLabels: some ChartContent {
        ForEach(labeled) { n in
            PointMark(
                x: .value("MHz", axis.x((n.span.lowerBound + n.span.upperBound) / 2)),
                y: .value("Segnale", Double(n.rssi))
            )
            .symbolSize(0)
            .annotation(position: .top, spacing: 2) {
                Text(n.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// Trapezi: la tua rete per ultima, così è disegnata sopra le altre.
    private var points: [Point] {
        let hoveredSpan = hoverX.map { WiFiMath.span(channel: axis.channel(atX: $0), width: 20, band: band) }
        let ordered = networks.sorted { !$0.isOwn && $1.isOwn }
        return ordered.flatMap { n -> [Point] in
            let span = n.span
            let edge = min(4, (span.upperBound - span.lowerBound) * 0.12)
            let xs = [span.lowerBound, span.lowerBound + edge, span.upperBound - edge, span.upperBound].map(axis.x)
            let ys = [Self.floor, Double(n.rssi), Double(n.rssi), Self.floor]
            let highlighted = hoveredSpan.map { WiFiMath.overlap(span, $0) > 0 } ?? false
            return (0..<4).map {
                Point(id: "\(n.id)-\($0)", network: n.id, x: xs[$0], y: ys[$0], isOwn: n.isOwn, isHighlighted: highlighted)
            }
        }
    }

    /// Etichette dirette solo per le reti più forti, saltando quelle che si sovrapporrebbero.
    private var labeled: [WiFiNetwork] {
        var chosen: [WiFiNetwork] = []
        let candidates = networks.filter(\.hasName).sorted { ($0.isOwn ? 1 : 0, $0.rssi) > ($1.isOwn ? 1 : 0, $1.rssi) }
        for n in candidates where chosen.count < 6 && n.rssi > -82 {
            let center = (n.span.lowerBound + n.span.upperBound) / 2
            let clashes = chosen.contains { other in
                abs((other.span.lowerBound + other.span.upperBound) / 2 - center) < 40 && abs(other.rssi - n.rssi) < 7
            }
            if !clashes { chosen.append(n) }
        }
        return chosen
    }
}

// MARK: - Interferenza per canale

struct ChannelLoadChart: View {
    let recommendation: Recommendation
    let networks: [WiFiNetwork]
    let band: Band
    let currentChannels: Set<Int>
    @State private var hoverX: Double?

    private var axis: FrequencyAxis { FrequencyAxis(band: band) }
    private var maxScore: Double { max(recommendation.loads.map(\.score).max() ?? 0, 1) * 1.2 }
    private var barHalfWidth: Double { band == .ghz24 ? 1.6 : 7 }

    var body: some View {
        Chart {
            backgroundBands
            bars
            if let hoverX {
                RuleMark(x: .value("MHz", axis.x(channel: axis.channel(atX: hoverX))))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXScale(domain: axis.domain)
        .chartYScale(domain: 0...maxScore)
        .chartXAxis { axis.channelMarks }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    Text(String(format: "%.1f", value.as(Double.self) ?? 0))
                        .font(.caption2)
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .chartLegend(.hidden)
        .modifier(ChartHover(x: $hoverX) { x in
            let channel = axis.channel(atX: x)
            ChannelTooltip(
                channel: channel, band: band, networks: networks,
                load: recommendation.loads.first { $0.channel == channel }
            )
        })
    }

    @ChartContentBuilder
    private var backgroundBands: some ChartContent {
        if let dfs = axis.dfsRange {
            RectangleMark(
                xStart: .value("Da", dfs.lowerBound), xEnd: .value("A", dfs.upperBound),
                yStart: .value("Base", 0.0), yEnd: .value("Cima", maxScore)
            )
            .foregroundStyle(Palette.muted.opacity(0.08))
        }
        if let best = recommendation.best {
            let r = axis.range(best.span)
            RectangleMark(
                xStart: .value("Da", r.lowerBound), xEnd: .value("A", r.upperBound),
                yStart: .value("Base", 0.0), yEnd: .value("Cima", maxScore)
            )
            .foregroundStyle(Palette.good.opacity(0.14))
        }
    }

    @ChartContentBuilder
    private var bars: some ChartContent {
        ForEach(recommendation.loads) { load in
            let x = axis.x(channel: load.channel)
            let isCurrent = currentChannels.contains(load.channel)
            RectangleMark(
                xStart: .value("Da", x - barHalfWidth), xEnd: .value("A", x + barHalfWidth),
                yStart: .value("Base", 0.0), yEnd: .value("Interferenza", load.score)
            )
            .foregroundStyle(isCurrent ? Palette.own : Palette.neighbor)
            .cornerRadius(3)
            .annotation(position: .top, spacing: 3) {
                if isCurrent {
                    Image(systemName: "wifi")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.own)
                }
            }
        }
    }
}
