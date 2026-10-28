import AppKit
import CoreLocation

/// Da macOS 14 i nomi (SSID) e i BSSID delle reti sono visibili solo alle app con permesso Posizione.
/// La posizione non viene mai letta: serve solo l'autorizzazione.
@MainActor
final class LocationAccess: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status: CLAuthorizationStatus
    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    // Su macOS il permesso concesso risulta "authorizedAlways" (4 = whenInUse, non esposto su macOS).
    var isGranted: Bool { status == .authorizedAlways || status.rawValue == 4 }
    var isUndetermined: Bool { status == .notDetermined }

    func request() {
        if isUndetermined {
            manager.requestWhenInUseAuthorization()
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.status = status }
    }
}
