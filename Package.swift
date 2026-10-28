// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WiFiCanali",
    platforms: [.macOS(.v14)],
    targets: [
        // Logica pura: geometria dei canali e calcolo del canale consigliato.
        .target(name: "WiFiCanaliCore"),
        // App SwiftUI + scansione CoreWLAN.
        .executableTarget(
            name: "WiFiCanali",
            dependencies: ["WiFiCanaliCore"],
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"),
            ]
        ),
        .testTarget(name: "WiFiCanaliCoreTests", dependencies: ["WiFiCanaliCore"]),
    ]
)
