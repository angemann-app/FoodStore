# ❄️ Eiszeit / FoodStore – Gefrierschrank-Bestandsverwaltung über Nostr & Cloudflare R2

**Eiszeit (FoodStore)** ist eine plattformübergreifende Flutter-App (Android & Web) zur Bestandsaufnahme und Organisation eines **Siemens NoFrost Gefrierschranks** im Familienhaushalt – synchronisiert in Echtzeit über das dezentrale **Nostr-Protokoll** und mit optionalem **Cloudflare R2** Objektspeicher für Produkt- und Dosenfotos.

---

## ✨ Hauptfunktionen

### 1. Originalgetreue Siemens NoFrost Fach-Struktur
- **Fach 1 (Oben):** Schnellzugriff (Kräuter, Butter, Eiswürfel, Kleinteile)
- **Fach 2:** Beeren (z. B. Kultur-Heidelbeeren), Obst, flache Beutel
- **Fach 3:** Gemüse, Beilagen, Pfannengerichte, Dosen
- **Fach 4 • BigBox XXL:** Extra hohe Großraum-Schublade für Braten, Pizza-Kartons, Vorratsboxen
- **Fach 5:** Fleisch, Geflügel, Fisch, Brot & Brötchen
- **Fach 6 (Unten):** Langzeit-Vorrat, Eingekochtes, Eiscreme
- **Türfach (Kühlakku-Halter):** Kühlakkus mit 1-Tap-Umschaltung zwischen *„Im Türfach (Einsatzbereit)"* und *„Unterwegs / In Benutzung"*

### 2. Was kommt wo rein – Was geht wo raus?
- **EAN-Barcode-Scanner (`mobile_scanner`) + OpenFoodFacts-Anbindung:** Automatische Erkennung von Produktname, Marke, Kategorie und Produktbild.
- **Kamera-Foto & Haltbarkeits-Rechner:** Automatischer Vorschlag der empfohlenen Lagerdauer je nach Lebensmittel-Kategorie mit **Gefrierbrand-Warnung** (Grün / Gelb / Rot).
- **1-Tap Entnahme & Umräumen:** Direkt am offenen Schrank `-1`, `+1`, `Komplett raus` oder in ein anderes Fach umräumen.

### 3. Nostr-Synchronisation & 2-Personen-Admin (Host) System
- **Echte BIP-340 Schnorr-Signaturen (`secp256k1`):** Jedes Familienmitglied besitzt ein eigenes Nostr-Schlüsselpaar (`npub`/`nsec`) und signiert jede Ein- und Auslagerung fälschungssicher.
- **Ende-zu-Ende-verschlüsselter Haushalt (`AES-256-GCM` über `kind: 30078` NIP-78):** Bestandsdaten und das Aktivitäts-Log sind auf öffentlichen Relays (`wss://relay.damus.io`, `wss://nos.lol`, `wss://relay.primal.net`) vollständig verschlüsselt.
- **Der Admin-Posten obliegt 2 Personen (`maxAdmins = 2`):**
  - Bis zu **2 Personen** bekleiden gleichzeitig die Rolle **Host / Admin**.
  - Die 2 Hosts verwalten die **Familienmitglieder-Liste**: Sie können neue Familienmitglieder in die Liste aufnehmen und direkt einen **personalisierten Einladungs-QR-Code** generieren.
  - Der 1. Host kann ein weiteres Mitglied zum **2. Host / Admin** ernennen (oder die Rolle neu vergeben).

### 4. Cloudflare R2 Bilder-Speicher (mit Offline-Fallback & 1-Klick-Migration)
- **Direkter S3-Upload (`AWS4-HMAC-SHA256`):** Sobald der Cloudflare R2 Account (`Account ID`, `Bucket`, `Access Key`, `Secret Key`, `Public URL`) hinterlegt ist, werden aufgenommene Fotos automatisch komprimiert und zu R2 hochgeladen.
- **Späteres Einrichten problemlos möglich:** Solange noch kein R2-Account eingetragen ist, speichert die App kompakte Vorschaubilder direkt im verschlüsselten Nostr-Bestand. Sobald der R2-Account später eingetragen wird, können alle vorhandenen Bilder per **1-Klick-Migration** zu Cloudflare R2 hochgeladen werden.

---

## 🚀 Entwicklung & Build

```bash
flutter pub get
flutter test
flutter build apk --release
```
