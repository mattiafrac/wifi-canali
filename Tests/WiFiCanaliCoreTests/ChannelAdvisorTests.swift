import Testing
@testable import WiFiCanaliCore

private func net(_ channel: Int, _ width: Int, _ rssi: Int, band: Band = .ghz5, own: Bool = false) -> WiFiNetwork {
    WiFiNetwork(
        id: "\(channel)-\(width)-\(rssi)-\(own)", ssid: nil, bssid: nil,
        band: band, channel: channel, width: width, rssi: rssi, isOwn: own
    )
}

@Test func spanOf80MHzBlockIgnoresWhichPrimary() {
    #expect(WiFiMath.span(channel: 36, width: 80, band: .ghz5) == 5170...5250)
    #expect(WiFiMath.span(channel: 44, width: 80, band: .ghz5) == 5170...5250)
    #expect(WiFiMath.span(channel: 157, width: 80, band: .ghz5) == 5735...5815)
}

@Test func spanOf160MHzUpperBlock() {
    #expect(WiFiMath.span(channel: 116, width: 160, band: .ghz5) == 5490...5650)
    #expect(WiFiMath.channels(primary: 116, width: 160, band: .ghz5) == [100, 104, 108, 112, 116, 120, 124, 128])
}

@Test func partialOverlapOn24GHz() {
    let one = WiFiMath.span(channel: 1, width: 20, band: .ghz24)
    let three = WiFiMath.span(channel: 3, width: 20, band: .ghz24)
    let six = WiFiMath.span(channel: 6, width: 20, band: .ghz24)
    #expect(WiFiMath.overlap(one, three) == 0.5)
    #expect(WiFiMath.overlap(one, six) == 0)
}

@Test func wideNeighborFullyBlocksNarrowChannel() {
    let neighbor = WiFiMath.span(channel: 36, width: 80, band: .ghz5)
    let candidate = WiFiMath.span(channel: 44, width: 20, band: .ghz5)
    #expect(WiFiMath.overlap(neighbor, candidate) == 1)
}

@Test func europe80MHzBlocks() {
    let rec = ChannelAdvisor.recommend(networks: [], band: .ghz5, width: 80, region: .europe)
    #expect(Set(rec.options.map(\.channels.first!)) == [36, 52, 100, 116])
}

@Test func prefersEmptyBlockAndOffersNonDFSAlternative() {
    let networks = [net(36, 80, -55), net(40, 80, -60), net(100, 80, -88)]
    let rec = ChannelAdvisor.recommend(networks: networks, band: .ghz5, width: 80, region: .europe)
    // 52–64 e 116–128 sono vuoti: vince 52 perché 116–128 include i radar meteo.
    #expect(rec.best?.channels.first == 52)
    #expect(rec.bestWithoutDFS?.channels.first == 36)
    #expect(rec.bestWithoutDFS?.neighborCount == 2)
}

@Test func ownNetworkIsNotInterference() {
    let networks = [net(36, 80, -40, own: true)]
    let rec = ChannelAdvisor.recommend(
        networks: networks, band: .ghz5, width: 80, region: .europe,
        current: ChannelRef(channel: 36, width: 80)
    )
    #expect(rec.current?.score == 0)
    #expect(rec.best?.channels.first == 36)
}

@Test func primaryAvoidsBusySubchannel() {
    let networks = [net(36, 20, -50), net(40, 20, -55), net(48, 20, -60)]
    let rec = ChannelAdvisor.recommend(networks: networks, band: .ghz5, width: 80, region: .europe)
    let block36 = rec.options.first { $0.channels.first == 36 }
    #expect(block36?.primary == 44)
}

@Test func picksFreeChannelOn24GHz() {
    let networks = [net(1, 20, -50, band: .ghz24), net(6, 20, -55, band: .ghz24), net(9, 20, -85, band: .ghz24)]
    let rec = ChannelAdvisor.recommend(networks: networks, band: .ghz24, width: 20, region: .europe)
    #expect(rec.best?.primary == 11)
}

@Test func sameRouterWithGuestNetworkCountsOnce() {
    let main = WiFiNetwork(id: "a", ssid: "Casa", bssid: "a0:11:22:33:44:50", band: .ghz5, channel: 36, width: 80, rssi: -60)
    let guest = WiFiNetwork(id: "b", ssid: "Ospiti", bssid: "a2:11:22:33:44:51", band: .ghz5, channel: 36, width: 80, rssi: -61)
    let other = WiFiNetwork(id: "c", ssid: "Vicino", bssid: "f0:99:88:77:66:55", band: .ghz5, channel: 36, width: 80, rssi: -61)
    #expect(OwnNetwork.radios([main, guest, other]).count == 2)
}

@Test func ownRouterRecognisedAcrossBands() {
    let five = WiFiNetwork(id: "a", ssid: "Casa-5G", bssid: "a0:11:22:33:44:51", band: .ghz5, channel: 128, width: 160, rssi: -34)
    let neighbor = WiFiNetwork(id: "b", ssid: "Vicino", bssid: "f0:99:88:77:66:55", band: .ghz5, channel: 36, width: 80, rssi: -70)
    let current = CurrentConnection(ssid: "Casa", bssid: "a0:11:22:33:44:50", band: .ghz24, channel: 6, width: 20, rssi: -33, noise: -94)
    let marked = OwnNetwork.mark([five, neighbor], current: current)
    #expect(marked.map(\.isOwn) == [true, false])
}

@Test func weatherRadarLosesCloseCall() {
    // 116–128 leggermente più libero di 36–48, ma include i radar meteo: vince 36–48.
    let networks = [net(36, 80, -80), net(116, 80, -85)]
    let rec = ChannelAdvisor.recommend(networks: networks, band: .ghz5, width: 80, region: .europe)
    #expect(rec.options.firstIndex { $0.channels.first == 36 }! < rec.options.firstIndex { $0.channels.first == 116 }!)
}

@Test func ownRouterGuessedWhenScanHasNoNamesYet() {
    // La connessione ha già il nome, ma la scansione è arrivata senza nomi né BSSID.
    let main = net(128, 160, -32)
    let guest = WiFiNetwork(id: "g", ssid: nil, bssid: nil, band: .ghz5, channel: 128, width: 160, rssi: -35)
    let neighbor = net(36, 80, -70)
    let current = CurrentConnection(ssid: "Casa", bssid: "a0:11:22:33:44:50", band: .ghz5, channel: 128, width: 80, rssi: -35, noise: -92)
    let marked = OwnNetwork.mark([main, guest, neighbor], current: current)
    #expect(marked.map(\.isOwn) == [true, true, false])
    #expect(OwnNetwork.routerChannel(current, in: marked).width == 160)
}
