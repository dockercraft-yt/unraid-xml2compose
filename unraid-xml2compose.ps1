<#
.SYNOPSIS
    Konvertiert unRAID Docker XML Templates in Docker Compose YAML-Dateien.
.DESCRIPTION
    PowerShell-Port des Python-Skripts "undock-compose".
    Unterstützt Einzeldateien oder Ordner voller XML-Templates.
.EXAMPLE
    .\xml-2-compose.ps1 -InputFile "C:\templates\app.xml" -IncludeLabels $true
.EXAMPLE
    .\xml-2-compose.ps1 -InputFolder "C:\templates" -IncludeLabels $false
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$InputFile,

    [Parameter(Mandatory = $false)]
    [string]$InputFolder,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "",

    [bool]$IncludeLabels = $false
)

# --- Initial Setup ---
$ErrorActionPreference = "Stop"
$ModuleName = "powershell-yaml"
$TempModuleInstalled = $false

Write-Host "xml-2-compose PowerShell Edition" -ForegroundColor Cyan
Write-Host "-----------------------------------`n"

# --- Check & load YAML module ---
if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
    Write-Host "Installing temporary module '$ModuleName'..." -ForegroundColor Yellow
    try {
        Install-Module $ModuleName -Scope CurrentUser -Force -ErrorAction Stop
        $TempModuleInstalled = $true
    } catch {
        Write-Error "Konnte Modul '$ModuleName' nicht installieren. Bitte manuell prüfen."
        exit 1
    }
}

Import-Module $ModuleName

# --- XML Tag Helper ---
function Get-Tag {
    param([string]$Tag)
    $node = $Xml.SelectSingleNode("//$Tag")
    if ($null -ne $node -and $node.InnerText) {
        return $node.InnerText.Trim()
    }
    return ""
}

# --- unRAID Template Helper ---
function Get-UnraidLabels {
    @{
        "net.unraid.docker.registry"   = Get-Tag "Registry"
        "net.unraid.docker.shell"      = Get-Tag "Shell"
        "net.unraid.docker.support"    = Get-Tag "Support"
        "net.unraid.docker.project"    = Get-Tag "Project"
        "net.unraid.docker.overview"   = Get-Tag "Overview"
        "net.unraid.docker.category"   = Get-Tag "Category"
        "net.unraid.docker.icon"       = Get-Tag "Icon"
        "net.unraid.docker.webui"      = Get-Tag "WebUI"
        "net.unraid.docker.managed"    = "compose"
        "net.unraid.docker.template"   = Get-Tag "TemplateURL"
        "net.unraid.docker.installed"  = Get-Tag "DateInstalled"
        "net.unraid.docker.donate.text"= Get-Tag "DonateText"
        "net.unraid.docker.donate.link"= Get-Tag "DonateLink"
        "net.unraid.docker.requires"   = Get-Tag "Requires"
    }
}

function Get-UnraidEnvironment {
    @{
        "TZ"                 = "UTC"
        "HOST_OS"            = "Unraid"
        "HOST_HOSTNAME"      = Get-Tag "Name"
        "HOST_CONTAINERNAME" = Get-Tag "Name"
    }
}

# --- Config Parser ---
function Get-Configs {
    $ports = @()
    $volumes = @()
    $devices = @()
    $environment = @{}
    $labels = @{}

    foreach ($config in $Xml.SelectNodes("//Config")) {
        $attrs = $config.Attributes
        $Type  = $attrs["Type"].Value
        $Name  = $attrs["Name"].Value
        $Target= $attrs["Target"].Value
        $Default = $attrs["Default"].Value
        $Mode  = if ($attrs["Mode"]) { $attrs["Mode"].Value } else { "" }
        $Value = if ($config.InnerText) { $config.InnerText.Trim() } else { $Default }
        $Value = $Value -replace '\$', '$$'
        $header = "net.unraid.docker.config.$($Name -replace ' ', '_')"

        switch ($Type) {
            "Port" {
                $ports += @{
                    target = [int]$Target
                    published = [int]$Value
                    protocol = $Mode
                }
            }
            "Path" {
                $v = ("{0}:{1}" -f $Value, $Target)
                if ($Mode) { $v += ":$Mode" }
                $volumes += $v
            }
            "Device" {
                $d = ("{0}:{1}" -f $Value, $Target)
                if ($Mode) { $d += ":$Mode" }
                $devices += $d
            }
            "Devices" {
                $d = ("{0}:{1}" -f $Value, $Target)
                if ($Mode) { $d += ":$Mode" }
                $devices += $d
            }
            "Variable" {
                $environment[$Target] = "$Value"
            }
            "Label" {
                $labels[$Target] = "$Value"
            }
        }

        if ($IncludeLabels) {
            $labels["$header.default"] = $Default
            $labels["$header.description"] = if ($attrs["Description"]) { $attrs["Description"].Value } else { "" }
            $labels["$header.display"] = if ($attrs["Display"]) { $attrs["Display"].Value } else { "" }
            $labels["$header.required"] = if ($attrs["Required"]) { $attrs["Required"].Value } else { "" }
            $labels["$header.mask"] = if ($attrs["Mask"]) { $attrs["Mask"].Value } else { "" }
        }
    }

    return [PSCustomObject]@{
        Ports = $ports
        Volumes = $volumes
        Env = $environment
        Labels = $labels
        Devices = $devices
    }
}

# --- Network / Service Parser ---
function Get-Networks {
    $net = Get-Tag "Network"
    @{
        $net = @{
            external = $true
            name = $net
        }
    }
}

function Get-Services {
    $cfg = Get-Configs

    # Merge Labels sicher
    $labels = @{}
    foreach ($k in ($cfg.Labels.Keys + (Get-UnraidLabels).Keys | Select-Object -Unique)) {
        $v1 = $cfg.Labels[$k]
        $v2 = (Get-UnraidLabels)[$k]
        if ($v2) { $labels[$k] = $v2 } elseif ($v1) { $labels[$k] = $v1 }
    }

    # Merge Environment sicher
    $env = [System.Collections.Hashtable]::new()
    foreach ($key in $cfg.Env.Keys) { $env[$key] = $cfg.Env[$key] }
    foreach ($key in (Get-UnraidEnvironment).Keys) { $env[$key] = (Get-UnraidEnvironment)[$key] }

    if (-not $IncludeLabels) {
        $labels.Clear()
    }

    $svcName = Get-Tag "Name"
    return @{
        $svcName = @{
            container_name = $svcName
            image = Get-Tag "Repository"
            privileged = -not ((Get-Tag "Privileged") -eq "false")
            ports = $cfg.Ports
            volumes = $cfg.Volumes
            environment = $env
            labels = $labels
            devices = $cfg.Devices
            networks = @(Get-Tag "Network")
            cpuset = Get-Tag "CPUset"
            command = Get-Tag "PostArgs"
        }
    }
}

# --- Datei-/Ordnerverarbeitung ---
$xmlFiles = @()

if ($InputFolder) {
    if (-not (Test-Path $InputFolder)) {
        Write-Error "Der angegebene Ordner '$InputFolder' existiert nicht."
        exit 1
    }

    Write-Host "Suche XML-Dateien in: $InputFolder ..." -ForegroundColor Cyan
    $xmlFiles = Get-ChildItem -Path $InputFolder -Filter *.xml -File
    if (-not $xmlFiles) {
        Write-Warning "Keine XML-Dateien im Ordner '$InputFolder' gefunden."
        exit 0
    }
}
elseif ($InputFile) {
    if (-not (Test-Path $InputFile)) {
        Write-Error "Eingabedatei '$InputFile' wurde nicht gefunden."
        exit 1
    }
    $xmlFiles = ,(Get-Item $InputFile)
}
else {
    Write-Error "Bitte entweder -InputFile oder -InputFolder angeben."
    exit 1
}

foreach ($xmlFile in $xmlFiles) {
    Write-Host "`nVerarbeite: $($xmlFile.Name)" -ForegroundColor Yellow

    try {
        [xml]$Xml = Get-Content $xmlFile.FullName -Raw
    } catch {
        Write-Warning "Konnte '$($xmlFile.Name)' nicht lesen: $($_.Exception.Message)"
        continue
    }

    if ($InputFolder) {
        $OutputFile = [System.IO.Path]::ChangeExtension($xmlFile.FullName, ".yaml")
    }
    elseif ([string]::IsNullOrWhiteSpace($OutputFile)) {
        $OutputFile = Join-Path (Split-Path $InputFile) "docker-compose.yaml"
    }

    $Compose = @{
        services = Get-Services
        networks = Get-Networks
    }

    try {
        $yaml = ConvertTo-Yaml $Compose
        Set-Content -Path $OutputFile -Value $yaml -Encoding UTF8
        Write-Host "YAML-Datei erstellt: $OutputFile" -ForegroundColor Green
    } catch {
        Write-Warning "Fehler beim Schreiben von '$($xmlFile.Name)': $($_.Exception.Message)"
    }
}

Write-Host "`nVerarbeitung abgeschlossen.`n" -ForegroundColor Cyan

# --- Cleanup ---
if ($TempModuleInstalled) {
    Write-Host "Cleaning up temporary module '$ModuleName'..."
    try {
        Remove-Module $ModuleName -ErrorAction SilentlyContinue
        Uninstall-Module $ModuleName -AllVersions -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Modul konnte nicht vollständig entfernt werden."
    }
}

Write-Host "Fertig."
