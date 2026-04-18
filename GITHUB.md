# Oratio — GitHub-Workflow

Komplette Anleitung: Repo anlegen, Code pushen, Pages aktivieren und Releases veröffentlichen. Für dein zukünftiges Ich geschrieben.

---

## 0. Voraussetzungen

- **GitHub-Account** (altner)
- **GitHub CLI (`gh`)** installiert und authentifiziert
  ```bash
  brew install gh
  gh auth login      # Interaktiv: GitHub.com, SSH-Protokoll, via Browser
  gh auth status     # sollte „Logged in to github.com" zeigen
  ```
- **SSH-Key** bei GitHub hinterlegt (hat `gh auth login` normalerweise schon erledigt)
- Repo lokal geklont / initialisiert

---

## 1. Repo auf GitHub anlegen

### Variante A: über `gh` (empfohlen)

Aus dem Projekt-Root:

```bash
cd ~/Developer/MacOS/Oratio
gh repo create Oratio --public --source=. --remote=origin
```

Flags:
- `--public` → öffentlich (für privat: `--private`)
- `--source=.` → nutzt das aktuelle Verzeichnis
- `--remote=origin` → legt den Git-Remote direkt an

### Variante B: manuell über die Weboberfläche

1. github.com → neues Repo „Oratio", **ohne** README/gitignore/License (haben wir lokal)
2. Remote hinzufügen:
   ```bash
   git remote add origin git@github.com:altner/Oratio.git
   ```

---

## 2. Ersten Commit pushen

```bash
# Alles stagen + committen (falls noch nicht)
git add .
git commit -m "$(cat <<'EOF'
feat: Initial Oratio MVP

Push-to-Talk Diktier-App für macOS mit:
- Lokalem WhisperKit und Cloud-API (OpenAI-kompatibel)
- LLM-Nachbearbeitung (Grammatik, Stil, Höflich, Custom)
- Füllwort-Filter, Pre-Roll-Puffer, Auto-Sleep
- Keychain für API-Keys, Presets für OpenAI/Groq/OpenRouter
- xcodegen-basiertes Projekt, docs/ für GitHub Pages
EOF
)"

# Pushen
git branch -M main          # Branch in "main" umbenennen (falls noch "master")
git push -u origin main
```

**Auth-Problem?** Siehe Troubleshooting am Ende.

---

## 3. Repo-Metadaten setzen (Description, Topics, Homepage)

```bash
gh repo edit altner/Oratio \
  --description "Push-to-Talk Diktier-App für macOS mit Whisper (lokal oder Cloud) und optionaler LLM-Nachbearbeitung" \
  --homepage "https://altner.github.io/Oratio/" \
  --add-topic macos \
  --add-topic swift \
  --add-topic swiftui \
  --add-topic dictation \
  --add-topic speech-to-text \
  --add-topic whisper \
  --add-topic whisperkit \
  --add-topic menu-bar-app \
  --add-topic apple-silicon \
  --add-topic openai \
  --add-topic groq \
  --add-topic push-to-talk
```

---

## 4. GitHub Pages via `gh-pages`-Branch

Wir verwalten die Website-Quellen in `docs/` auf `main`. Für die Veröffentlichung wird ein separater `gh-pages`-Branch gepflegt, dessen Inhalt = `docs/` im Root.

### Einmal einrichten

```bash
# Vom main-Branch aus:
git subtree push --prefix docs origin gh-pages
```

Das legt remote den Branch `gh-pages` an mit `index.html`, `app-icon.png`, `.nojekyll` direkt im Root.

### In den GitHub-Einstellungen aktivieren

1. Repo → **Settings** → **Pages**
2. **Source**: *Deploy from a branch*
3. **Branch**: `gh-pages`, Folder: `/ (root)`
4. **Save** → nach ~1 Min erreichbar unter `https://altner.github.io/Oratio/`

### Bei jedem Website-Update

Edits in `docs/` machen, committen, dann:

```bash
git subtree push --prefix docs origin gh-pages
```

**Bei Konflikten** (selten, z. B. nach Force-Push):

```bash
git push origin $(git subtree split --prefix docs main):refs/heads/gh-pages --force
```

---

## 5. Release erstellen (v0.1.0)

GitHub Releases = Tags + Release Notes + optional Binary-Assets. Für Oratio bedeutet das: Git-Tag setzen, App bauen, `.zip` dranhängen, Release Notes schreiben.

### 5a. Release-Build bauen

```bash
cd ~/Developer/MacOS/Oratio
xcodegen generate
xcodebuild -project Oratio.xcodeproj \
           -scheme Oratio \
           -configuration Release \
           clean build
```

Das `.app` liegt nach erfolgreichem Build unter:
```
~/Library/Developer/Xcode/DerivedData/Oratio-*/Build/Products/Release/Oratio.app
```

### 5b. App als ZIP verpacken

`ditto` erhält macOS-Metadaten korrekt (im Gegensatz zu `zip`):

```bash
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Oratio-*/Build/Products/Release/Oratio.app)
cd "$(dirname "$APP")"
ditto -c -k --sequesterRsrc --keepParent Oratio.app ~/Desktop/Oratio-0.1.0.zip
echo "ZIP: ~/Desktop/Oratio-0.1.0.zip"
```

### 5c. Git-Tag setzen

```bash
cd ~/Developer/MacOS/Oratio
git tag -a v0.1.0 -m "Oratio 0.1.0 — erster MVP-Release"
git push origin v0.1.0
```

### 5d. Release via `gh` veröffentlichen

```bash
gh release create v0.1.0 \
  ~/Desktop/Oratio-0.1.0.zip \
  --title "Oratio 0.1.0 — MVP" \
  --notes "$(cat <<'EOF'
## 🎉 Erster Release

Push-to-Talk Diktieren auf macOS — Whisper lokal oder Cloud, optionale LLM-Nachbearbeitung.

### Features
- **Push-to-Talk** (⌥Leertaste halten) oder Toggle-Modus
- **Zwei STT-Backends**: lokal via WhisperKit (Whisper Large v3 Turbo, Apple Neural Engine) oder Cloud (OpenAI / Groq / OpenRouter / custom)
- **LLM-Nachbearbeitung** mit 4 Modi + eigenem Prompt (Rechtschreibung, Professioneller Stil, Höflich umformulieren, Custom)
- **Füllwort-Filter** (regex, offline): „ähm", „öh", „hmm"
- **300 ms Pre-Roll-Puffer** — keine verlorenen Wortanfänge
- **Auto-Sleep** nach 30 s Inaktivität — Mikro-LED aus
- **Keychain-Storage** für API-Keys, getrennte Einträge für Transkription & Nachbearbeitung
- **Multi-Provider-Presets**: OpenAI, Groq, OpenRouter, Eigener Dienst

### Installation
1. `Oratio-0.1.0.zip` herunterladen und entpacken
2. `Oratio.app` in den Applications-Ordner ziehen
3. Beim ersten Start: Rechtsklick → „Öffnen" (weil ad-hoc signiert)
4. Mikrofon-Berechtigung erlauben
5. Bedienungshilfen-Zugriff in den Systemeinstellungen aktivieren, Oratio einmal neu starten

### Voraussetzungen
- macOS 14 (Sonoma) oder neuer
- Apple Silicon (M1 / M2 / M3 / …)

### Bekannte Einschränkungen
- Ad-hoc signiert, nicht notarisiert → Gatekeeper-Warnung beim ersten Öffnen
- Kein Intel-Support
- Anthropic API nur via OpenRouter

Feedback & Bugs gerne als Issue. 🎤
EOF
)"
```

### 5e. Release prüfen

```bash
gh release view v0.1.0 --web
```

Öffnet die Release-Seite im Browser.

---

## 6. Gatekeeper-Hinweis für Nutzer

Da die App **ad-hoc signiert** und **nicht notarisiert** ist, warnt macOS beim ersten Öffnen („Oratio kann nicht geöffnet werden, weil der Entwickler nicht verifiziert werden kann").

**Workaround für Nutzer** (in den Release Notes erwähnen):
1. `Oratio.app` in den Applications-Ordner ziehen
2. **Rechtsklick** auf Oratio.app → **Öffnen**
3. Warnung erscheint → **Öffnen** klicken
4. Danach normale Öffnung per Doppelklick / Launchpad

Für „richtige" Distribution ohne diese Warnung: Apple Developer Program ($99/Jahr) → Developer ID Application Cert → `codesign` + `notarytool`. Out of scope für MVP.

---

## 7. Folge-Releases

Für jedes neue Release (z. B. v0.2.0):

```bash
# 1. Version in project.yml hochsetzen (MARKETING_VERSION + CURRENT_PROJECT_VERSION)
# 2. Changelog schreiben / committen
git add project.yml CHANGELOG.md
git commit -m "chore: bump version to 0.2.0"
git push

# 3. Build + ZIP
xcodegen generate
xcodebuild -project Oratio.xcodeproj -scheme Oratio -configuration Release clean build
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Oratio-*/Build/Products/Release/Oratio.app)
cd "$(dirname "$APP")"
ditto -c -k --sequesterRsrc --keepParent Oratio.app ~/Desktop/Oratio-0.2.0.zip

# 4. Tag + Release
cd ~/Developer/MacOS/Oratio
git tag -a v0.2.0 -m "Oratio 0.2.0"
git push origin v0.2.0
gh release create v0.2.0 ~/Desktop/Oratio-0.2.0.zip \
  --title "Oratio 0.2.0" \
  --notes-file RELEASE-NOTES-0.2.0.md
```

Tipp: Release Notes in `.md`-Dateien pflegen, nicht inline — einfacher zu reviewen.

---

## 8. Nützliche `gh`-Kommandos

```bash
gh repo view                       # Repo-Info anzeigen
gh repo view --web                 # Repo im Browser öffnen
gh release list                    # alle Releases
gh release view v0.1.0             # Details eines Releases
gh release delete v0.1.0           # Release wieder löschen (lokalen Tag separat)
gh issue create                    # Issue eröffnen
gh pr create                       # Pull-Request
gh api repos/altner/Oratio/traffic/views   # Zugriffsstatistiken
```

---

## 9. Troubleshooting

### „Password authentication is not supported for Git operations"
GitHub hat Passwort-Auth deaktiviert. Zwei Fixes:

```bash
# Variante A: Remote auf SSH umstellen
git remote set-url origin git@github.com:altner/Oratio.git

# Variante B: gh als Credential-Helper einrichten
gh auth setup-git
```

### „remote: Repository not found"
Entweder tippfehler im Remote-URL oder Repo existiert noch nicht:
```bash
git remote -v
gh repo view altner/Oratio
```

### `git subtree push` schlägt fehl („Updates were rejected")
Happens wenn `gh-pages` divergiert. Force-Push via Split:
```bash
git push origin $(git subtree split --prefix docs main):refs/heads/gh-pages --force
```

### „error: Resource not accessible by integration" beim `gh release create`
Token hat nicht genug Scopes. Re-login mit mehr Rechten:
```bash
gh auth refresh -h github.com -s write:packages,repo
```

### App öffnet sich nach Download als „beschädigt"
Wenn das ZIP über den Browser geladen wurde, hat macOS das Quarantine-Flag gesetzt. Workaround:
```bash
xattr -rd com.apple.quarantine /Applications/Oratio.app
```
(Oder Rechtsklick → Öffnen — der erste Dialog löst den Flag automatisch.)

### Release zeigt keinen ZIP-Download
Beim `gh release create` das File als Positional-Argument hinter die Release-Flags stellen (siehe Beispiel in 5d). Mit `gh release upload v0.1.0 /pfad/zu/file.zip` lassen sich Assets auch nachträglich ergänzen.

---

## 10. 60-Sekunden-Merkhilfe

```bash
# Repo anlegen + pushen
gh repo create Oratio --public --source=. --remote=origin
git push -u origin main

# GitHub Pages
git subtree push --prefix docs origin gh-pages
# → Settings/Pages: Branch "gh-pages", Folder "/ (root)"

# Release
xcodegen generate && xcodebuild -project Oratio.xcodeproj -scheme Oratio -configuration Release clean build
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Oratio-*/Build/Products/Release/Oratio.app)
ditto -c -k --sequesterRsrc --keepParent "$APP" ~/Desktop/Oratio-X.Y.Z.zip
git tag -a vX.Y.Z -m "Oratio X.Y.Z" && git push origin vX.Y.Z
gh release create vX.Y.Z ~/Desktop/Oratio-X.Y.Z.zip --title "Oratio X.Y.Z" --notes-file notes.md
```
