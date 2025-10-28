# 🐋 unraid-xml2compose

Konvertiert **unRAID Docker XML-Templates** automatisch in **Docker Compose YAML-Dateien** – direkt mit PowerShell.
Ideal für Nutzer, die bestehende unRAID-Container in ein portables Compose-Setup überführen wollen.

---

## Funktionen

- Liest unRAID-XML-Templates und erzeugt Compose-Dateien im YAML-Format
- Unterstützt **Einzeldateien** oder ganze Ordner voller XML-Vorlagen
- Optionales Einfügen aller **unRAID-Label-Informationen** (`-IncludeLabels`)
- Temporäre Nutzung von `powershell-yaml` mit automatischer Installation und Bereinigung
- Kein Compose-Versionseintrag (kompatibel mit Docker Compose v2+)
- Saubere Fehlerbehandlung und automatische Pfadverwaltung

---

## Voraussetzungen

- **PowerShell 5.1** (Windows) oder **PowerShell 7+** (Core, Linux/Mac)
- Internetzugang (für temporäre Modulinstallation)

Das Script installiert bei Bedarf automatisch das Modul
[`powershell-yaml`](https://www.powershellgallery.com/packages/powershell-yaml)
und entfernt es nach der Ausführung wieder.

---

## Verwendung

### Einzeldatei konvertieren
```powershell
.\unraid-xml2compose.ps1 -InputFile "C:\unraid\templates\myapp.xml"
```
### Einzeldatei konvertieren mit Ausgabedatei
```powershell
.\unraid-xml2compose.ps1 -InputFile .\my-example.xml -OutputFile my-example.yaml
```

### Mit Labels
```powershell
.\unraid-xml2compose.ps1 -InputFile "C:\unraid\templates\myapp.xml" -IncludeLabels $true
```

### Ordnerweise konvertieren
```powershell
.\unraid-xml2compose.ps1 -InputFolder "C:\unraid\templates"
```

→ Für jede `*.xml` im Ordner wird automatisch eine gleichnamige `.yaml` erzeugt.

---

## Beispielausgabe (`docker-compose.yaml`)

```yaml
services:
  myapp:
    container_name: myapp
    image: linuxserver/myapp:latest
    ports:
      - target: 8080
        published: 8080
    volumes:
      - /mnt/user/appdata/myapp:/config
    environment:
      TZ: UTC
      HOST_OS: Unraid
      HOST_CONTAINERNAME: myapp
    labels:
      net.unraid.docker.webui: http://[IP]:[PORT:8080]
    networks:
      - bridge
networks:
  bridge:
    external: true
    name: bridge
```

---

## Beispielverzeichnis

```
unraid-xml2compose/
├─ unraid-xml2compose.ps1
├─ README.md
└─ templates/
   ├─ myapp.xml
   ├─ nextcloud.xml
   └─ redis.xml
```

Nach der Ausführung:
```
templates/
├─ myapp.xml
├─ myapp.yaml
├─ nextcloud.xml
├─ nextcloud.yaml
└─ redis.yaml
```

---

## Aufräumen

Das Script deinstalliert das YAML-Modul nach Beendigung automatisch:
```powershell
Remove-Module powershell-yaml -ErrorAction SilentlyContinue
Uninstall-Module powershell-yaml -AllVersions -Force -ErrorAction SilentlyContinue
```

---

## Hinweis

Das Script wurde als PowerShell-Port des Projekts
[`undock-compose`](https://github.com/arifer/undock-compose) entwickelt
und vollständig in PowerShell nachgebaut.
Die Umsetzung wurde erweitert, um unRAID-Spezifika zu berücksichtigen.

---

## Lizenz

Dieses Projekt steht unter der **GNU GPL-3.0**.
Nutzung, Änderung und Weitergabe sind erlaubt, solange der Quellcode offen bleibt.
