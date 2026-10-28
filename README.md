# Canali Wi‑Fi

App per macOS (14+) che scansiona le reti Wi‑Fi vicine e consiglia il canale 5 GHz (o 2.4 GHz) meno disturbato.

Basta Swift 5.10+: vanno bene i Command Line Tools (`xcode-select --install`), Xcode non serve.

- **Compila l'app:** `./build-app.sh` → `build/Canali WiFi.app` (`--install` la copia in `~/Applications`)
- **Test:** `./test.sh`
- **Da terminale:** `.build/debug/WiFiCanali --scan [--width 40] [--usa]`

Ogni nuova compilazione cambia la firma ad-hoc: macOS potrebbe richiedere di nuovo il permesso Posizione,
che serve solo per vedere i nomi delle reti.

## Come sceglie il canale

Per ogni blocco di canali possibile (20/40/80/160 MHz, Europa 36–140 o USA 36–165) somma le reti vicine
che si sovrappongono, pesate per segnale (−95 dBm → 0, −50 dBm o più → 1). Le reti del tuo router non contano
e più reti trasmesse dalla stessa radio contano una volta sola. I canali DFS hanno una piccola penalità,
quelli dei radar meteo (120–128) una più grande, perché un radar costringe il router a cambiare canale.

## Licenza

MIT
