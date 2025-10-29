##### Language selection:
 [![English](/assets/img/flag_usa.png)](README.md) [![German](/assets/img/flag_germany.png)](README_de.md)
# 🐋 unraid-xml2compose

Automatically converts **unRAID Docker XML templates** into **Docker Compose YAML files** – directly with PowerShell.  
Perfect for users who want to migrate existing unRAID containers into a portable Compose setup.

---

## Features

- Reads unRAID XML templates and generates Compose files in YAML format  
- Supports **single files** or entire **folders** of XML templates  
- Optionally includes all **unRAID label information** (`-IncludeLabels`)  
- Temporary use of `powershell-yaml` with automatic installation and cleanup  
- No Compose version entry (compatible with Docker Compose v2+)  
- Clean error handling and automatic path management  

---

## Requirements

- **PowerShell 5.1** (Windows) or **PowerShell 7+** (Core, Linux/Mac)  
- Internet connection (for temporary module installation)

The script automatically installs the  
[`powershell-yaml`](https://www.powershellgallery.com/packages/powershell-yaml)  
module if necessary and removes it after execution.

---

## Usage

### Convert a single file
```powershell
.\unraid-xml2compose.ps1 -InputFile "C:\unraid\templates\myapp.xml"
```

### Convert a single file with output file
```powershell
.\unraid-xml2compose.ps1 -InputFile .\my-example.xml -OutputFile my-example.yaml
```

### With labels
```powershell
.\unraid-xml2compose.ps1 -InputFile "C:\unraid\templates\myapp.xml" -IncludeLabels $true
```

### Convert an entire folder
```powershell
.\unraid-xml2compose.ps1 -InputFolder "C:\unraid\templates"
```

→ For each `*.xml` file in the folder, a corresponding `.yaml` will be created automatically.

---

## Example input file (`my-example.xml`)

```xml
<?xml version="1.0"?>
<Container version="2">
  <Name>nginx</Name>
  <Repository>lscr.io/linuxserver/nginx</Repository>
  <Registry>https://github.com/orgs/linuxserver/packages/container/package/nginx</Registry>
  <Network>bridge</Network>
  <Privileged>false</Privileged>
  <Support>https://github.com/linuxserver/docker-nginx/issues/new/choose</Support>
  <Project>https://nginx.org/</Project>
  <Overview>Nginx(https://nginx.org/) is a simple webserver with php support. The config files reside in `/config` for easy user customization.</Overview>
  <WebUI>http://[IP]:[PORT:80]</WebUI>
  <TemplateURL>https://raw.githubusercontent.com/linuxserver/templates/main/unraid/nginx.xml</TemplateURL>
  <Icon>https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/nginx-logo.png</Icon>
  <Config Name="WebUI" Target="80" Default="80" Mode="tcp" Description="http" Type="Port">40080</Config>
  <Config Name="Port: 443" Target="443" Default="443" Mode="tcp" Description="https" Type="Port">40443</Config>
  <Config Name="Appdata" Target="/config" Default="/mnt/user/appdata/nginx" Mode="rw" Description="Persistent config files" Type="Path">/mnt/user/appdata/nginx</Config>
  <Config Name="PUID" Target="PUID" Default="99" Type="Variable">99</Config>
  <Config Name="PGID" Target="PGID" Default="100" Type="Variable">100</Config>
  <Config Name="UMASK" Target="UMASK" Default="022" Type="Variable">022</Config>
</Container>
```

## Example output (`my-example.yaml`)

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
      HOST_OS: Unraid
      PGID: "100"
      TZ: UTC
      HOST_HOSTNAME: nginx
      HOST_CONTAINERNAME: nginx
      PUID: "99"
      UMASK: "022"
    ports:
      - 40080:80
      - 40443:443
    volumes:
      - /mnt/user/appdata/nginx:/config:rw
    networks:
      - bridge
    container_name: nginx
    labels: {}
```

---

## Example directory structure

```
unraid-xml2compose/
├─ unraid-xml2compose.ps1
├─ README.md
└─ templates/
   ├─ myapp.xml
   ├─ nextcloud.xml
   └─ redis.xml
```

After execution:
```
templates/
├─ myapp.xml
├─ myapp.yaml
├─ nextcloud.xml
├─ nextcloud.yaml
└─ redis.yaml
```

---

## Cleanup

The script automatically uninstalls the YAML module after completion:
```powershell
Remove-Module powershell-yaml -ErrorAction SilentlyContinue
Uninstall-Module powershell-yaml -AllVersions -Force -ErrorAction SilentlyContinue
```

---

## Note

This script was developed as a PowerShell port of  
[`undock-compose`](https://github.com/arifer612/undock-compose)  
and has been completely rewritten in PowerShell.  
The implementation has been extended to handle unRAID-specific details.

---

## License

This project is licensed under the **GNU GPL-3.0**.  
Use, modification, and redistribution are permitted as long as the source code remains open.
