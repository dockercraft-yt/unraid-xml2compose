param(
    [Parameter(Mandatory = $false)]
    [string]$InputFile,

    [Parameter(Mandatory = $false)]
    [string]$InputFolder,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "",

    [switch]$IncludeLabels
)

# --- Prüfen ob YAML Modul vorhanden ist ---
$moduleName = "powershell-yaml"
$moduleInstalled = Get-Module -ListAvailable -Name $moduleName

if (-not $moduleInstalled) {
    try {
        Write-Host "Installing $moduleName temporarily..."
        Install-Module $moduleName -Force -Scope CurrentUser -ErrorAction Stop
    } catch {
        Write-Error "Failed to install required module '$moduleName'."
        exit 1
    }
}

Import-Module $moduleName -ErrorAction Stop

# --- Hilfsfunktionen ---

function Get-Tag($tagName) {
    return $Xml.Container.$tagName
}

function Get-Ports {
    $ports = @()
    foreach ($config in $Xml.Container.Config) {
        $type = if ($config.Type) { $config.Type.ToString() } else { "" }
        if ($type -eq "Port") {
            $published = ($config.'#text').ToString().Trim()
            $target = if ($config.Target) { $config.Target.ToString().Trim() } else { "" }
            $mode = if ($config.Mode) { $config.Mode.ToString().Trim() } else { "" }

            if (-not [string]::IsNullOrWhiteSpace($published) -and -not [string]::IsNullOrWhiteSpace($target)) {
                $entry = "${published}:${target}"
                if ($mode -ieq "udp") { $entry += "/udp" }
                $ports += $entry
            }
        }
    }
    return ,@($ports)  # ensure array (even if single or empty)
}

function Get-Volumes {
    $volumes = @()
    foreach ($config in $Xml.Container.Config) {
        $type = if ($config.Type) { $config.Type.ToString() } else { "" }
        if ($type -eq "Path") {
            $source = if ($config.'#text') { $config.'#text'.ToString().Trim() } else { "" }
            $target = if ($config.Target) { $config.Target.ToString().Trim() } else { "" }
            $mode = if ($config.Mode) { $config.Mode.ToString().Trim() } else { "" }

            if (-not [string]::IsNullOrWhiteSpace($source) -and -not [string]::IsNullOrWhiteSpace($target)) {
                if (-not [string]::IsNullOrWhiteSpace($mode)) {
                    $volumes += "${source}:${target}:${mode}"
                } else {
                    $volumes += "${source}:${target}"
                }
            }
        }
    }
    return ,@($volumes)  # ensure array
}

function Get-Devices {
    $devices = @()
    foreach ($config in $Xml.Container.Config) {
        $type = if ($config.Type) { $config.Type.ToString() } else { "" }
        if ($type -in @("Device", "Devices")) {
            $val = if ($config.'#text') { $config.'#text'.ToString().Trim() } else { "" }
            $target = if ($config.Target) { $config.Target.ToString().Trim() } else { "" }
            $mode = if ($config.Mode) { $config.Mode.ToString().Trim() } else { "" }

            if (-not [string]::IsNullOrWhiteSpace($val) -and -not [string]::IsNullOrWhiteSpace($target)) {
                if (-not [string]::IsNullOrWhiteSpace($mode)) {
                    $devices += "${val}:${target}:${mode}"
                } else {
                    $devices += "${val}:${target}"
                }
            }
        }
    }
    return ,@($devices)  # ensure array
}


function Get-Configs {
    $env = @{}
    $labels = @{}

    foreach ($config in $Xml.Container.Config) {
        switch ($config.Type) {
            "Variable" { 
                if ($config.Target -and $config.'#text') {
                    $env[$config.Target] = $config.'#text'
                }
            }
            "Label" {
                if ($IncludeLabels -and $config.Target -and $config.'#text') {
                    $labels[$config.Target] = $config.'#text'
                }
            }
        }
    }

    return @{
        Env = $env
        Labels = $labels
        Ports = Get-Ports
        Volumes = Get-Volumes
        Devices = Get-Devices
    }
}

function Get-UnraidEnvironment {
    return @{
        HOST_OS = "Unraid"
        TZ = "UTC"
        HOST_CONTAINERNAME = Get-Tag "Name"
        HOST_HOSTNAME = Get-Tag "Name"
    }
}

function Get-UnraidLabels {
    if (-not $IncludeLabels) { return @{} }
    $labels = @{}
    $webUI = Get-Tag "WebUI"
    if ($webUI) { $labels["net.unraid.docker.webui"] = $webUI }
    $support = Get-Tag "Support"
    if ($support) { $labels["net.unraid.docker.support"] = $support }
    return $labels
}

function Get-Networks {
    $network = Get-Tag "Network"
    return @{
        $network = @{
            external = $true
            name = $network
        }
    }
}

function Get-Services {
    $cfg = Get-Configs
    $labels = @{}

    # Labels sicher zusammenführen
    foreach ($k in ($cfg.Labels.Keys + (Get-UnraidLabels).Keys | Select-Object -Unique)) {
        $v1 = $cfg.Labels[$k]
        $v2 = (Get-UnraidLabels)[$k]
        if ($v2) { $labels[$k] = $v2 } elseif ($v1) { $labels[$k] = $v1 }
    }

    # Environment sicher zusammenführen (überschreiben erlaubt)
    $env = [System.Collections.Hashtable]::new()
    foreach ($key in $cfg.Env.Keys) { $env[$key] = $cfg.Env[$key] }
    foreach ($key in (Get-UnraidEnvironment).Keys) { $env[$key] = (Get-UnraidEnvironment)[$key] }

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

# --- Verarbeitung ---
$xmlFiles = @()

if ($InputFolder) {
    if (-not (Test-Path $InputFolder)) {
        Write-Error "The folder '$InputFolder' does not exist."
        exit 1
    }

    Write-Host "Searching for XML files in $InputFolder..."
    $xmlFiles = Get-ChildItem -Path $InputFolder -Filter *.xml -File
    if (-not $xmlFiles) {
        Write-Warning "No XML files found in '$InputFolder'."
        exit 0
    }
}
elseif ($InputFile) {
    if (-not (Test-Path $InputFile)) {
        Write-Error "Input file '$InputFile' not found."
        exit 1
    }
    $xmlFiles = ,(Get-Item $InputFile)
}
else {
    Write-Error "Please specify either -InputFile or -InputFolder."
    exit 1
}

foreach ($xmlFile in $xmlFiles) {
    Write-Host "Processing: $($xmlFile.Name)"

    try {
        [xml]$Xml = Get-Content $xmlFile.FullName -Raw
    } catch {
        Write-Warning "Could not read '$($xmlFile.Name)': $($_.Exception.Message)"
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
        Write-Host "YAML file created: $OutputFile"
    } catch {
        Write-Warning "Error writing '$($xmlFile.Name)': $($_.Exception.Message)"
    }
}

Write-Host "All files processed."

# --- Modul nach Benutzung entfernen ---
try {
    Remove-Module $moduleName -ErrorAction SilentlyContinue
    Uninstall-Module $moduleName -AllVersions -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Failed to clean up module '$moduleName'."
}