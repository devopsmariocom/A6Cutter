# 🔄 Sparkle Auto-Updater Setup

Tento dokument popisuje nastavení automatického updateru pro A6Cutter pomocí Sparkle frameworku.

## 📋 Přehled

Sparkle umožňuje uživatelům automaticky stahovat a instalovat aktualizace aplikace bez nutnosti manuálního stažení z GitHubu.

## 🛠️ Nastavení

### 1. Lokální vývoj

```bash
# Stáhni Sparkle tools
curl -L -o sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-2.6.0.tar.xz
tar -xf sparkle.tar.xz
mkdir -p bin
cp Sparkle-2.6.0/bin/* ./bin/

# Vygeneruj klíče (pouze jednou)
./scripts/generate_sparkle_keys.sh

# Vygeneruj appcast.xml
./scripts/generate_appcast.sh
```

### 2. GitHub Actions

Workflow automaticky:
- ✅ Stáhne Sparkle tools
- ✅ Vygeneruje klíče (pokud neexistují)
- ✅ Vytvoří appcast.xml
- ✅ Přidá appcast.xml do release

## 🔑 Klíče a bezpečnost

### Soukromý klíč
- **Umístění:** `keys/ed25519_private_key.pem`
- **Bezpečnost:** NIKDY necommitovat do Git!
- **Účel:** Podepisování DMG souborů

### Veřejný klíč
- **Umístění:** `keys/ed25519_public_key.pem`
- **Účel:** Ověřování podpisů v aplikaci
- **Info.plist:** Automaticky přidán do `SUPublicEDSAKey`

## 📡 Appcast.xml

### Co to je?
- XML soubor obsahující informace o dostupných aktualizacích
- Sparkle ho používá k detekci nových verzí
- Automaticky generován při každém release

### URL struktura
```
https://github.com/mariovejlupek/A6Cutter/releases.atom
```

## 🚀 Jak to funguje

### 1. Uživatel otevře aplikaci
- Sparkle automaticky kontroluje aktualizace
- Kontrola probíhá každých 24 hodin (nastavitelné)

### 2. Nalezena nová verze
- Zobrazí se notifikace
- Uživatel může stáhnout a nainstalovat

### 3. Instalace
- Stáhne DMG z GitHub releases
- Ověří podpis pomocí veřejného klíče
- Nainstaluje novou verzi
- Restartuje aplikaci

## ⚙️ Konfigurace

### Info.plist nastavení

```xml
<key>SUFeedURL</key>
<string>https://github.com/mariovejlupek/A6Cutter/releases.atom</string>

<key>SUPublicEDSAKey</key>
<string>your-public-key-here</string>

<key>SUEnableAutomaticChecks</key>
<true/>

<key>SUCheckInterval</key>
<integer>86400</integer> <!-- 24 hodin -->
```

### Menu položky

Aplikace automaticky přidá:
- **"Check for Updates..."** v A6Cutter menu
- **"Check for Updates..."** v About dialogu

## 🧪 Testování

### Lokální test
```bash
# Vytvoř test release
git tag v1.0.1
git push origin v1.0.1

# GitHub Actions vytvoří release s appcast.xml
```

### Debug režim
```swift
// V A6CutterApp.swift
updaterController.updater.checkForUpdates()
```

## 🔧 Troubleshooting

### Problém: "No updates found"
- ✅ Zkontroluj `SUFeedURL` v Info.plist
- ✅ Ověř, že appcast.xml je dostupný
- ✅ Zkontroluj, že DMG je podepsaný

### Problém: "Invalid signature"
- ✅ Ověř, že `SUPublicEDSAKey` je správný
- ✅ Zkontroluj, že soukromý klíč je správný
- ✅ Regeneruj klíče pokud je potřeba

### Problém: "Download failed"
- ✅ Zkontroluj internetové připojení
- ✅ Ověř, že DMG URL je dostupný
- ✅ Zkontroluj GitHub permissions

## 📚 Užitečné odkazy

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [Code Signing Guide](https://sparkle-project.org/documentation/code-signing/)

## 🎯 Další kroky

1. **První release:** Vytvoř tag `v1.0.0`
2. **Test:** Otevři aplikaci a zkontroluj "Check for Updates"
3. **Druhý release:** Vytvoř tag `v1.0.1` a otestuj auto-update
4. **Monitoring:** Sleduj GitHub Actions logs

---

**Poznámka:** Tento setup je plně automatický. Stačí vytvořit Git tag a GitHub Actions se postará o zbytek! 🚀
