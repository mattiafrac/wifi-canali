import Foundation
import WiFiCanaliCore

/// Stato dell'app: accumula le reti viste nelle ultime scansioni.
/// Una singola scansione può perdersi qualche rete (soprattutto sui canali DFS),
/// quindi teniamo in memoria quelle viste negli ultimi `memory` secondi.
@MainActor
final class WiFiStore: ObservableObject {
    @Published private(set) var networks: [WiFiNetwork] = []
    @Published private(set) var current: CurrentConnection?
    @Published private(set) var isScanning = false
    @Published private(set) var lastScan: Date?
    @Published private(set) var scanCount = 0
    @Published private(set) var errorMessage: String?
    @Published var autoScan = false {
        didSet { updateTimer() }
    }

    static let memory: TimeInterval = 90
    static let autoScanInterval: TimeInterval = 15

    private var remembered: [String: WiFiNetwork] = [:]
    private var timer: Timer?
    private var retriedForNames = false

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        Task.detached(priority: .userInitiated) {
            let result = Result { try WiFiScanner.scan() }
            await self.finish(result)
        }
    }

    private func finish(_ result: Result<ScanResult, Error>) {
        isScanning = false
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let scan):
            errorMessage = nil
            merge(scan)
            // Subito dopo l'avvio macOS può non applicare ancora il permesso Posizione alla scansione:
            // la connessione ha il nome ma le reti no. In quel caso riproviamo una volta.
            let namesPending = scan.current?.ssid != nil && !scan.networks.isEmpty && scan.networks.allSatisfy { $0.bssid == nil }
            if namesPending && !retriedForNames {
                retriedForNames = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    self.scan()
                }
            }
        }
    }

    private func merge(_ scan: ScanResult) {
        let now = Date()
        current = scan.current
        remembered = remembered.filter { key, network in
            !key.hasPrefix("anon-") && now.timeIntervalSince(network.lastSeen) < Self.memory
        }
        for var network in scan.networks {
            if let previous = remembered[network.id] {
                // Media mobile: il segnale oscilla parecchio tra una scansione e l'altra.
                network.rssi = Int((Double(previous.rssi + network.rssi) / 2).rounded())
            }
            remembered[network.id] = network
        }
        networks = OwnNetwork.mark(Array(remembered.values), current: current).sorted { $0.rssi > $1.rssi }
        lastScan = now
        scanCount += 1
    }

    private func updateTimer() {
        timer?.invalidate()
        timer = nil
        guard autoScan else { return }
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: Self.autoScanInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
    }
}
