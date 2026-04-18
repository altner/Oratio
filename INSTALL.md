# Oratio — Installations- & Setup-Anleitung

Schritt-für-Schritt-Anleitung, um Oratio von GitHub zu klonen und lokal auf deinem Mac zum Laufen zu bringen. Auch für das zukünftige Ich gedacht, falls ich vergesse wie.

---

## 0. Voraussetzungen

Du brauchst:

| Tool | Zweck | Installation |
|---|---|---|
| **macOS 14** oder neuer | Mindest-Deployment-Target | (bereits am Start) |
| **Apple Silicon Mac** | M1/M2/M3/… — kein Intel | — |
| **Xcode 15+** | Swift-Compiler, Build-System | App Store → „Xcode" |
| **Xcode Command Line Tools** | git, xcodebuild, swift | `xcode-select --install` |
| **Homebrew** | Paketmanager | [brew.sh](https://brew.sh) |
| **xcodegen** | erzeugt `.xcodeproj` aus `project.yml` | `brew install xcodegen` |
| **git** | Repo klonen | kommt mit Command Line Tools |

### Einmaliges Setup der Tools

```bash
# Xcode aus dem App Store installieren, danach:
sudo xcode-select --install

# Homebrew (wenn nicht schon da)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# xcodegen
brew install xcodegen
```

Prüfen, dass alles da ist:

```bash
xcode-select -p       # sollte /Applications/Xcode.app/... zurückgeben
xcodebuild -version   # sollte Xcode 15+ anzeigen
xcodegen --version    # sollte 2.x anzeigen
git --version
```

---

## 1. Projekt klonen

```bash
# in ein Verzeichnis deiner Wahl wechseln, z. B.:
mkdir -p ~/Developer/MacOS
cd ~/Developer/MacOS

# Repo klonen (URL anpassen)
git clone https://github.com/<DEIN-GITHUB-USER>/Oratio.git
cd Oratio
```

---

## 2. Xcode-Projekt generieren

Das `.xcodeproj` wird **nicht eingecheckt** — es wird aus `project.yml` generiert:

```bash
xcodegen generate
```

Du solltest sehen:
```
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at /…/Oratio/Oratio.xcodeproj
```

**Erklärung:** `project.yml` ist die Quelle der Wahrheit für alle Xcode-Einstellungen (Bundle-ID, Min-Deployment, Signing, Info.plist-Keys, SwiftPM-Dependencies, …). Nach Änderungen an `project.yml` erneut `xcodegen generate` ausführen.

---

## 3. Projekt in Xcode öffnen

```bash
open Oratio.xcodeproj
```

Xcode öffnet sich. **Beim ersten Öffnen** lädt Xcode die SwiftPM-Dependencies im Hintergrund herunter (WhisperKit + KeyboardShortcuts + deren Transitive Deps). Das dauert **1–3 Minuten** beim ersten Mal — unten links in der Xcode-Statusleiste siehst du einen Fortschrittsbalken.

Wenn fertig: Xcode zeigt oben links das Oratio-Target an.

---

## 4. Build & Run

Erste Ausführung:

```
Product → Run       (oder ⌘R)
```

Xcode baut das Projekt (~30 s beim ersten Mal) und startet Oratio.

**Was du siehst:**
- Kein Dock-Icon (das ist korrekt — `LSUIElement=true`)
- Rechts oben in der Menüleiste ein **Mikrofon-Symbol** ("O"-Ring)
- Klick darauf öffnet ein Popover mit Status „Bereit" / „Modell lädt …"

---

## 5. Erstlauf-Setup (Permissions + Modell)

### 5a. Modell-Download (ca. 1,5 GB, einmalig)

Beim ersten Start lädt WhisperKit das Whisper-Modell herunter. Im Popover siehst du:
- `Lädt herunter … X %`
- Danach `Kompiliert Modell für Neural Engine …`
- Schließlich `Bereit` ✓

Der Download landet unter `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/…`. Wenn der Download abbricht, kannst du dort alles löschen und die App neu starten.

### 5b. Mikrofon-Berechtigung

Beim **ersten Diktat** (Hotkey drücken) erscheint macOS' Mikrofon-Prompt. „Erlauben" klicken.

### 5c. Bedienungshilfen-Berechtigung (wichtig!)

Oratio braucht **Accessibility-Zugriff**, um das simulierte `⌘V` in andere Apps zu schicken. Der Prompt erscheint automatisch beim ersten Hotkey-Druck. Schritte:

1. Dialog „Zugriff auf Bedienungshilfen" erscheint → **Systemeinstellungen öffnen**
2. In der Liste **Oratio** aktivieren (Toggle an)
3. Oratio beenden (Menü → „Oratio beenden")
4. Oratio neu starten (aus Xcode mit ⌘R oder den Build aus `DerivedData` starten)

Alternativ über das App-Popover: **orange Warnung** → Button „Systemeinstellungen öffnen".

### 5d. Hotkey prüfen / anpassen

Default: **⌥Leertaste (Option + Space)** halten.

Ändern unter Einstellungen → **Allgemein** → Tastenkürzel.

---

## 6. Erstes Diktat

1. TextEdit öffnen (oder eine beliebige App mit Textfeld)
2. Cursor ins Textfeld klicken
3. **⌥Leertaste halten**
4. Auf Deutsch sprechen: *„Dies ist ein Test. Funktioniert das?"*
5. **Loslassen**
6. Text erscheint an der Cursor-Position

---

## 7. API-Key hinterlegen (optional, für Cloud-Backend & LLM-Korrektur)

Wenn du OpenAI/Groq/OpenRouter für Transkription oder Nachbearbeitung nutzen willst:

1. Account erstellen bei:
   - [OpenAI](https://platform.openai.com/api-keys) (kostenpflichtig)
   - [Groq](https://console.groq.com/keys) (gratis Tier, extrem schnell)
   - [OpenRouter](https://openrouter.ai/keys) (Pay-as-you-go, viele Modelle)
2. Key kopieren
3. In Oratio: **Einstellungen** → **Transkription** → Dienst wählen → Key einfügen → **Speichern**
4. „Verbindung testen" klicken (grüner Haken = OK)
5. **Backend** auf „Cloud-API" umschalten (falls du Cloud statt lokal willst)

Für die **Nachbearbeitung** gleich: Tab **Nachbearbeitung** → Key speichern (gleicher oder eigener).

---

## 8. Dev-Loop: Änderungen machen und neu bauen

Nach jeder Änderung an `project.yml`:

```bash
xcodegen generate
```

Nach jeder Code-Änderung (in Xcode): einfach `⌘R`.

**Tipp:** `pkill -f Oratio` killt alle laufenden Instanzen, falls beim Neustart aus Xcode manchmal zwei Mikros in der Menüleiste erscheinen.

---

## 9. Troubleshooting

### Problem: „Text wird nicht eingefügt, obwohl alles Grün ist"

→ Accessibility-Berechtigung wurde durch einen Rebuild invalidiert (ad-hoc-Signatur hat sich geändert). Fix:

```bash
pkill -f Oratio
tccutil reset Accessibility org.altner.Oratio
open ~/Library/Developer/Xcode/DerivedData/Oratio-*/Build/Products/Debug/Oratio.app
```

Dann beim nächsten Hotkey erneut Dialog bestätigen → in den Systemeinstellungen aktivieren → neu starten.

### Problem: „Modell-Download hängt bei einem Prozentsatz"

```bash
# Cache löschen:
rm -rf ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930_turbo
# Oratio neu starten → Download beginnt frisch
```

### Problem: „Zwei Mikro-Symbole in der Menüleiste"

```bash
pkill -9 -f "Oratio.app/Contents/MacOS/Oratio"
# dann App einmal sauber starten
```

### Problem: „Build schlägt fehl — Package resolution error"

Wahrscheinlich Netzwerk-Problem beim Dependency-Fetch. In Xcode:
```
File → Packages → Reset Package Caches
File → Packages → Resolve Package Versions
```
Oder per CLI:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Oratio-*
xcodegen generate
xcodebuild -project Oratio.xcodeproj -scheme Oratio -resolvePackageDependencies
```

### Problem: „HTTP 400: Audio file is too short"

Du hast den Hotkey zu kurz gedrückt (<0,5 s). Oratio sollte das abfangen und eine freundliche Meldung zeigen. Falls nicht: länger halten.

### Problem: „Aufnahme zu kurz – Meldung bei längerem Drücken"

Prüfe die Mikrofon-Auswahl in den macOS-Einstellungen. Pre-Roll-Puffer füllt sich erst nach ~300 ms mit Audio — beim allerersten Hotkey-Druck nach App-Start kann das noch leer sein.

### Problem: „Korrektur fehlgeschlagen: HTTP 401"

API-Key ist falsch oder abgelaufen. Settings → Tab wählen → Key neu speichern.

---

## 10. App aus dem Dev-Build heraus benutzen (ohne Xcode)

Nach einem erfolgreichen Build findest du die App unter:

```
~/Library/Developer/Xcode/DerivedData/Oratio-*/Build/Products/Debug/Oratio.app
```

Du kannst sie von dort aus starten:
```bash
open ~/Library/Developer/Xcode/DerivedData/Oratio-*/Build/Products/Debug/Oratio.app
```

Oder in den Applications-Ordner kopieren (dann bleibt die Accessibility-Berechtigung stabiler, weil der Pfad nicht wechselt):
```bash
cp -R ~/Library/Developer/Xcode/DerivedData/Oratio-*/Build/Products/Debug/Oratio.app /Applications/
open /Applications/Oratio.app
```

**Achtung:** Nach einem Rebuild musst du den `cp -R` erneut ausführen, sonst startet die alte Version.

---

## 11. Auto-Start beim Login (optional)

Manuell via macOS:

1. **Systemeinstellungen** → **Allgemein** → **Anmeldeobjekte**
2. `+` klicken → Oratio.app auswählen → hinzufügen
3. Bei der nächsten Anmeldung startet Oratio automatisch

---

## 12. Updates aus dem Repo ziehen

```bash
cd ~/Developer/MacOS/Oratio
git pull
xcodegen generate          # falls project.yml geändert wurde
open Oratio.xcodeproj      # dann ⌘R in Xcode
```

---

## 13. Komplette Deinstallation

Wenn du Oratio sauber loswerden willst:

```bash
# Laufenden Prozess beenden
pkill -f Oratio

# App aus Applications (falls dort)
rm -rf /Applications/Oratio.app

# DerivedData-Build
rm -rf ~/Library/Developer/Xcode/DerivedData/Oratio-*

# Modell-Cache
rm -rf ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930_turbo

# UserDefaults
defaults delete org.altner.Oratio 2>/dev/null

# Keychain-Einträge
security delete-generic-password -s "org.altner.Oratio.openai" -a "api-key" 2>/dev/null
security delete-generic-password -s "org.altner.Oratio.openai" -a "correction-api-key" 2>/dev/null

# Accessibility-Eintrag
tccutil reset Accessibility org.altner.Oratio

# Repo (wenn du die Quellen auch wegwerfen willst)
rm -rf ~/Developer/MacOS/Oratio
```

---

## 14. Merkhilfe: Oratio in unter 60 Sekunden starten

```bash
brew install xcodegen                              # einmalig
git clone <repo-url> ~/Developer/MacOS/Oratio      # einmalig
cd ~/Developer/MacOS/Oratio
xcodegen generate
open Oratio.xcodeproj
# → Xcode ⌘R → Mic erlauben → Accessibility aktivieren → App neu starten → fertig
```

Viel Spaß beim Diktieren. 🎤
