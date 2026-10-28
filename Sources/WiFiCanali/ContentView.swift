import SwiftUI
import WiFiCanaliCore

struct ContentView: View {
    @EnvironmentObject private var store: WiFiStore
    @EnvironmentObject private var location: LocationAccess

    var body: some View {
        ScrollView {
            DashboardView().padding(20)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $store.autoScan) {
                    Label("Automatica", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("Ripete la scansione ogni \(Int(WiFiStore.autoScanInterval)) secondi")
                Button {
                    store.scan()
                } label: {
                    Label("Scansiona", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(store.isScanning)
                .help("Scansiona ora (⌘R)")
            }
        }
        .task {
            store.scan()
            if Snapshot.path != nil {
                await Snapshot.capture(store: store, location: location)
            } else if location.isUndetermined {
                location.request()
            }
        }
        .onChange(of: location.isGranted) { _, granted in
            if granted { store.scan() }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: WiFiStore
    @EnvironmentObject private var location: LocationAccess
    @AppStorage("band") private var band: Band = .ghz5
    @AppStorage("width") private var width = 80
    @AppStorage("region") private var region: Region = .europe

    private var bandNetworks: [WiFiNetwork] { store.networks.filter { $0.band == band } }

    /// Canale e larghezza del tuo router nella banda mostrata.
    private var router: ChannelRef? {
        guard let current = store.current, current.band == band else { return nil }
        return OwnNetwork.routerChannel(current, in: store.networks)
    }

    var body: some View {
        let recommendation = ChannelAdvisor.recommend(
            networks: store.networks, band: band, width: width, region: region, current: router
        )

        VStack(alignment: .leading, spacing: 16) {
            controls
            if !location.isGranted { LocationBanner() }
            if let error = store.errorMessage { ErrorBanner(text: error) }

            HStack(alignment: .top, spacing: 16) {
                ConnectionCard(
                    current: store.current,
                    router: router ?? store.current.map { OwnNetwork.routerChannel($0, in: store.networks) },
                    evaluation: recommendation.current,
                    shownBand: band
                )
                RecommendationCard(
                    title: "Canale consigliato", systemImage: "checkmark.seal",
                    option: recommendation.best, current: recommendation.current,
                    emptyText: "Ancora nessun dato: avvia una scansione."
                )
                if band == .ghz5 {
                    RecommendationCard(
                        title: "Migliore senza DFS", systemImage: "shield",
                        option: recommendation.bestWithoutDFS, current: recommendation.current,
                        emptyText: "Con \(width) MHz in \(region.rawValue) non esiste un blocco senza canali DFS: prova 80 MHz."
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Card(title: "Spettro \(band.rawValue)", systemImage: "waveform.path.ecg") {
                HStack(spacing: 16) {
                    LegendItem(color: Palette.own, text: "La tua rete")
                    LegendItem(color: Palette.neighbor, text: "Reti vicine")
                    LegendItem(color: Palette.good, text: "Blocco consigliato", isBand: true)
                    if band == .ghz5 { LegendItem(color: Palette.muted, text: "Canali DFS", isBand: true) }
                    Spacer()
                    Text("Altezza = segnale (dBm) · passa il mouse per i dettagli")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                SpectrumChart(
                    networks: bandNetworks, band: band,
                    recommended: recommendation.best, loads: recommendation.loads
                )
                .frame(height: 300)
            }

            Card(title: "Interferenza per canale", systemImage: "chart.bar.fill") {
                Text("Per ogni canale da 20 MHz: le reti che lo occupano, pesate per segnale (1 ≈ una rete forte). L'icona Wi‑Fi segna i canali del tuo router.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ChannelLoadChart(
                    recommendation: recommendation, networks: bandNetworks, band: band,
                    currentChannels: Set(router.map { WiFiMath.channels(primary: $0.channel, width: $0.width, band: band) } ?? [])
                )
                .frame(height: 190)
            }

            Card(title: "Reti rilevate (\(bandNetworks.count))", systemImage: "list.bullet") {
                NetworkTable(networks: bandNetworks)
            }

            tips
        }
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Picker("Banda", selection: $band) {
                Text("5 GHz").tag(Band.ghz5)
                Text("2.4 GHz").tag(Band.ghz24)
            }
            .pickerStyle(.segmented)
            .fixedSize()

            if band == .ghz5 {
                Picker("Larghezza", selection: $width) {
                    ForEach([20, 40, 80, 160], id: \.self) { Text("\($0) MHz").tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("La larghezza che vuoi impostare sul router. 80 MHz è il compromesso tipico; con tante reti vicine 40 MHz è più stabile.")

                Picker("Regione", selection: $region) {
                    ForEach(Region.allCases) { Text($0.rawValue).tag($0) }
                }
                .fixedSize()
                .help("Europa: canali 36–140. USA: anche 144–165.")
            }

            Spacer()

            HStack(spacing: 8) {
                if store.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Scansione…")
                } else if let last = store.lastScan {
                    Text("Ultima scansione \(last.formatted(date: .omitted, time: .standard)) · \(store.scanCount) in totale")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private var tips: some View {
        Card(title: "Come usarlo", systemImage: "lightbulb") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• Attiva la scansione **Automatica** per un paio di minuti: non tutte le reti compaiono a ogni passaggio (soprattutto sui canali DFS) e l'app ricorda quelle viste negli ultimi \(Int(WiFiStore.memory)) secondi.")
                Text("• Fai la scansione vicino al router e nei punti in cui usi di più la Wi‑Fi: conta l'interferenza che senti tu, non quella dei vicini.")
                Text("• Sul router imposta il canale consigliato e la stessa larghezza scelta qui, togliendo la selezione automatica del canale. Se hai cadute periodiche, preferisci il blocco **senza DFS**.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
