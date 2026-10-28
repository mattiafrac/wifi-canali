# Canali Wi‑Fi

App per macOS (14+) che scansiona le reti Wi‑Fi vicine e consiglia il canale 5 GHz (o 2.4 GHz) meno disturbato.

## Installazione

**Rapida:** apri il Terminale e incolla:

```bash
curl -fsSL https://raw.githubusercontent.com/mattiafrac/wifi-canali/main/install.sh | bash
```

Scarica l'ultima versione, la mette in Applicazioni e la apre. Rilanciando lo stesso comando aggiorni l'app.

**Manuale:** scarica `Canali-WiFi.dmg` dall'[ultima release](https://github.com/mattiafrac/wifi-canali/releases/latest)
e trascina l'app in Applicazioni. L'app non è notarizzata da Apple, quindi la prima volta macOS la blocca:
apri Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**.

Al primo avvio l'app chiede l'accesso a Posizione: macOS mostra i nomi delle reti solo alle app che ce l'hanno.
La posizione non viene letta né salvata. Funziona su Apple Silicon e Intel.

## Compilare dal codice

Basta Swift 5.10+: vanno bene i Command Line Tools (`xcode-select --install`), Xcode non serve.

- **Compila l'app:** `./build-app.sh` → `build/Canali WiFi.app` (`--install` la copia in `~/Applications`)
- **Test:** `./test.sh`
- **Nuova release:** aggiorna la versione in `Resources/Info.plist`, poi `./release.sh 1.1.0 --publish`
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
