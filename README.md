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

## Beispiel Ausgangsdatei (`my-example.xml`)

```xml
<?xml version="1.0"?>
<Container version="2">
  <Name>nginx</Name>
  <Repository>lscr.io/linuxserver/nginx</Repository>
  <Registry>https://github.com/orgs/linuxserver/packages/container/package/nginx</Registry>
  <Network>bridge</Network>
  <MyIP/>
  <Shell>bash</Shell>
  <Privileged>false</Privileged>
  <Support>https://github.com/linuxserver/docker-nginx/issues/new/choose</Support>
  <Project>https://nginx.org/</Project>
  <Overview>Nginx(https://nginx.org/) is a simple webserver with php support. The config files reside in `/config` for easy user customization.</Overview>
  <Category>Network:Web Tools:Utilities</Category>
  <WebUI>http://[IP]:[PORT:80]</WebUI>
  <TemplateURL>https://raw.githubusercontent.com/linuxserver/templates/main/unraid/nginx.xml</TemplateURL>
  <Icon>https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/nginx-logo.png</Icon>
  <ExtraParams/>
  <PostArgs/>
  <CPUset/>
  <DateInstalled>1761633250</DateInstalled>
  <DonateText>Donations</DonateText>
  <DonateLink>https://www.linuxserver.io/donate</DonateLink>
  <Requires/>
  <Config Name="WebUI" Target="80" Default="80" Mode="tcp" Description="http" Type="Port" Display="always" Required="true" Mask="false">40080</Config>
  <Config Name="Port: 443" Target="443" Default="443" Mode="tcp" Description="https" Type="Port" Display="always" Required="true" Mask="false">40443</Config>
  <Config Name="NGINX_AUTORELOAD" Target="NGINX_AUTORELOAD" Default="" Mode="{3}" Description="Set to `true` to enable automatic reloading of confs on change without stopping/restarting nginx. Your filesystem must support inotify. This functionality was previously offered via mod(https://github.com/linuxserver/docker-mods/tree/swag-auto-reload)." Type="Variable" Display="always" Required="false" Mask="false"/>
  <Config Name="NGINX_AUTORELOAD_WATCHLIST" Target="NGINX_AUTORELOAD_WATCHLIST" Default="" Mode="{3}" Description="A pipe(https://en.wikipedia.org/wiki/Vertical_bar)-separated list of additional folders for auto reload to watch in addition to `/config/nginx`" Type="Variable" Display="always" Required="false" Mask="false"/>
  <Config Name="Appdata" Target="/config" Default="/mnt/user/appdata/nginx" Mode="rw" Description="Persistent config files" Type="Path" Display="advanced" Required="true" Mask="false">/mnt/user/appdata/nginx</Config>
  <Config Name="PUID" Target="PUID" Default="99" Mode="{3}" Description="" Type="Variable" Display="advanced" Required="true" Mask="false">99</Config>
  <Config Name="PGID" Target="PGID" Default="100" Mode="{3}" Description="" Type="Variable" Display="advanced" Required="true" Mask="false">100</Config>
  <Config Name="UMASK" Target="UMASK" Default="022" Mode="{3}" Description="" Type="Variable" Display="advanced" Required="false" Mask="false">022</Config>
  <TailscaleStateDir/>
</Container>
```

## Beispielausgabe (`my-example.yaml`)

```yaml
networks:
  bridge:
    external: true
    name: bridge
services:
  nginx:
    image: lscr.io/linuxserver/nginx
    privileged: false
    environment:
      HOST_HOSTNAME: nginx
      HOST_OS: Unraid
      TZ: UTC
      PGID: "100"
      HOST_CONTAINERNAME: nginx
      PUID: "99"
      NGINX_AUTORELOAD_WATCHLIST: ""
      UMASK: "022"
      NGINX_AUTORELOAD: ""
    cpuset: ""
    devices: []
    ports:
    - protocol: tcp
      target: 80
      published: 40080
    - protocol: tcp
      target: 443
      published: 40443
    volumes:
    - /mnt/user/appdata/nginx:/config:rw
    networks:
    - bridge
    command: ""
    container_name: nginx
    labels: {}
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
[`undock-compose`](https://github.com/arifer612/undock-compose) entwickelt
und vollständig in PowerShell nachgebaut.
Die Umsetzung wurde erweitert, um unRAID-Spezifika zu berücksichtigen.

---

## Lizenz

Dieses Projekt steht unter der **GNU GPL-3.0**.
Nutzung, Änderung und Weitergabe sind erlaubt, solange der Quellcode offen bleibt.
