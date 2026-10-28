import Foundation

if CommandLine.arguments.contains("--scan") {
    exit(ScanCLI.run(arguments: CommandLine.arguments))
}

MainActor.assumeIsolated {
    WiFiCanaliApp.main()
}
