# IDM Alert Blocker - Turn the three nag alerts OFF or back ON
#
# Covers:
#   1. "IDM has been registered with a fake serial number"     -> CLSID tracking keys locked
#   2. "...counterfeit / stolen serial number" (30 day block)  -> validation hosts blocked
#   3. "Your IDM trial period has expired"                     -> registration values restored
#
# Usage: alerts.ps1 -Mode Off   |   alerts.ps1 -Mode On
param (
    [ValidateSet("Off", "On")]
    [string]$Mode = "Off"
)

$ErrorActionPreference = "Stop"

$regPath   = "HKCU:\SOFTWARE\DownloadManager"
$statePath = "HKCU:\SOFTWARE\DUDE_IDM"
$hostsPath = "$env:windir\System32\drivers\etc\hosts"

$markerStart = "# DUDE-IDM-ALERT-BLOCK-START"
$markerEnd   = "# DUDE-IDM-ALERT-BLOCK-END"

$validationHosts = @(
    "registeridm.com",
    "www.registeridm.com",
    "secure.registeridm.com",
    "secure.internetdownloadmanager.com",
    "registeridm.one",
    "star.tonec.com",
    "www.internetdownloadmanager.com",
    "tonec.com",
    "www.tonec.com",
    "mirror2.internetdownloadmanager.com"
)

# Locate IDM
$idmExe = ""
if (Test-Path "C:\Program Files (x86)\Internet Download Manager\IDMan.exe") {
    $idmExe = "C:\Program Files (x86)\Internet Download Manager\IDMan.exe"
} elseif (Test-Path "C:\Program Files\Internet Download Manager\IDMan.exe") {
    $idmExe = "C:\Program Files\Internet Download Manager\IDMan.exe"
}

if (-not $idmExe) {
    Write-Host "  [ERROR] Internet Download Manager is not installed!" -ForegroundColor Red
    return
}

# ---------------------------------------------------------------- helpers ---

function Stop-IDM {
    foreach ($procName in @("IDMan", "IEMonitor")) {
        $count = 0
        while ((Get-Process -Name $procName -ErrorAction SilentlyContinue) -and ($count -lt 10)) {
            Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            $count++
        }
    }
}

function Start-IDM {
    $shell = New-Object -ComObject "Shell.Application"
    $shell.ShellExecute($idmExe)
}

function Split-RegistryPath {
    param ([string]$Path)
    if ($Path.StartsWith("HKCU:\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return @{ Root = "CurrentUser";  SubKey = $Path.Substring(6) }
    } elseif ($Path.StartsWith("HKLM:\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return @{ Root = "LocalMachine"; SubKey = $Path.Substring(6) }
    } elseif ($Path.StartsWith("HKU:\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return @{ Root = "Users";        SubKey = $Path.Substring(5) }
    } elseif ($Path.StartsWith("Registry::HKEY_USERS\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return @{ Root = "Users";        SubKey = $Path.Substring(21) }
    }
    return @{ Root = "CurrentUser"; SubKey = $Path }
}

function Enable-RegistryPrivileges {
    try {
        $Type = [PrivilegeType]
    } catch {
        $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('RegistryPrivileges_' + [Guid]::NewGuid().ToString('N'))), [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('PrivilegeModule', $False)
        $TypeBuilder = $ModuleBuilder.DefineType('PrivilegeType', 'Public, Class')
        $TypeBuilder.DefinePInvokeMethod('RtlAdjustPrivilege', 'ntdll.dll', 'Public, Static', [System.Reflection.CallingConventions]::Standard, [int], @([int], [bool], [bool], [bool].MakeByRefType()), [System.Runtime.InteropServices.CharSet]::Ansi, [System.Runtime.InteropServices.LayoutKind]::Auto) | Out-Null
        $Type = $TypeBuilder.CreateType()
    }
    $nullRef = $false
    [void]$Type::RtlAdjustPrivilege(9, $true, $false, [ref]$nullRef)
    [void]$Type::RtlAdjustPrivilege(17, $true, $false, [ref]$nullRef)
    [void]$Type::RtlAdjustPrivilege(18, $true, $false, [ref]$nullRef)
}

function Lock-RegistryKey {
    param ([string]$Path)
    try {
        $parts = Split-RegistryPath -Path $Path
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Enable-RegistryPrivileges

        $regKey = [Microsoft.Win32.Registry]::($parts.Root).OpenSubKey($parts.SubKey, 'ReadWriteSubTree', 'TakeOwnership')
        if ($regKey) {
            $acl = New-Object System.Security.AccessControl.RegistrySecurity
            $acl.SetOwner([System.Security.Principal.WindowsIdentity]::GetCurrent().User)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
        }

        $regKey = [Microsoft.Win32.Registry]::($parts.Root).OpenSubKey($parts.SubKey, 'ReadWriteSubTree', 'ChangePermissions')
        if ($regKey) {
            $acl = $regKey.GetAccessControl()
            $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
            $none = New-Object System.Security.Principal.SecurityIdentifier('S-1-0-0')
            $acl.SetOwner($none)
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Deny')
            $acl.ResetAccessRule($rule)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
        }
    } catch {}
}

function Unlock-RegistryKey {
    param ([string]$Path)
    try {
        $parts = Split-RegistryPath -Path $Path
        Enable-RegistryPrivileges

        try {
            $regKey = [Microsoft.Win32.Registry]::($parts.Root).OpenSubKey($parts.SubKey, 'ReadWriteSubTree', 'TakeOwnership')
            if ($regKey) {
                $acl = New-Object System.Security.AccessControl.RegistrySecurity
                $acl.SetOwner([System.Security.Principal.WindowsIdentity]::GetCurrent().User)
                $regKey.SetAccessControl($acl)
                $regKey.Close()
            }
        } catch {}

        $regKey = [Microsoft.Win32.Registry]::($parts.Root).OpenSubKey($parts.SubKey, 'ReadWriteSubTree', 'ChangePermissions')
        if ($regKey) {
            $acl = $regKey.GetAccessControl()
            $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.ResetAccessRule($rule)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
        }
    } catch {}
}

# Collect the CLSID roots IDM uses for trial/fingerprint tracking
function Get-ClsidRoots {
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $paths = @(
        "HKCU:\Software\Classes\CLSID",
        "HKCU:\Software\Classes\WOW6432Node\CLSID",
        "HKLM:\Software\Classes\CLSID",
        "HKLM:\Software\Classes\WOW6432Node\CLSID"
    )
    if ($sid) {
        $paths += "Registry::HKEY_USERS\$sid\Software\Classes\CLSID"
        $paths += "Registry::HKEY_USERS\$sid\Software\Classes\Wow6432Node\CLSID"
    }
    return $paths
}

# Find the CLSID subkeys that look like IDM trial/fingerprint stores
function Find-TrackingClsids {
    $found = @()
    foreach ($clsidPath in Get-ClsidRoots) {
        if (-not (Test-Path $clsidPath)) { continue }
        $parts = Split-RegistryPath -Path $clsidPath
        $rootKey = [Microsoft.Win32.Registry]::($parts.Root)

        $parentKey = $null
        try { $parentKey = $rootKey.OpenSubKey($parts.SubKey) } catch { continue }
        if ($parentKey -eq $null) { continue }
        $subKeyNames = $parentKey.GetSubKeyNames()
        $parentKey.Close()

        foreach ($name in $subKeyNames) {
            if ($name -notmatch '^\{[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\}$') { continue }
            $fullPsPath = "$clsidPath\$name"

            $subKey = $null
            try {
                $subKey = $rootKey.OpenSubKey("$($parts.SubKey)\$name")
                if ($subKey -eq $null) { $found += $fullPsPath; continue }
            } catch {
                $found += $fullPsPath
                continue
            }

            try {
                $valueCount   = $subKey.ValueCount
                $subKeyCount  = $subKey.SubKeyCount
                $defaultValue = $subKey.GetValue("")
                $defaultStr   = if ($defaultValue -ne $null) { $defaultValue.ToString() } else { "" }

                $hasMatchProperty = $false
                foreach ($valName in $subKey.GetValueNames()) {
                    if ($valName -match '^MData$|^Model$|^scansk$|^Therad$') { $hasMatchProperty = $true; break }
                }

                $hasVersionMatch = $false
                if ($subKeyCount -eq 1 -and ($subKey.GetSubKeyNames() -contains "Version")) {
                    $verKey = $subKey.OpenSubKey("Version")
                    if ($verKey -ne $null) {
                        $verVal = $verKey.GetValue("")
                        if ($verVal -ne $null -and $verVal.ToString() -match '^\d+$') { $hasVersionMatch = $true }
                        $verKey.Close()
                    }
                }
                $subKey.Close()

                if (($defaultStr -match '^\d+$') -and ($subKeyCount -eq 0)) {
                    $found += $fullPsPath
                } elseif (($defaultStr -match '\+|=') -and ($subKeyCount -eq 0)) {
                    $found += $fullPsPath
                } elseif ($hasVersionMatch -or $hasMatchProperty) {
                    $found += $fullPsPath
                } elseif (($valueCount -eq 0) -and ($subKeyCount -eq 0)) {
                    $found += $fullPsPath
                }
            } catch {
                $found += $fullPsPath
            }
        }
    }
    return ($found | Select-Object -Unique)
}

# Find CLSID subkeys that are currently locked (unreadable)
function Find-LockedClsids {
    $found = @()
    foreach ($clsidPath in Get-ClsidRoots) {
        if (-not (Test-Path $clsidPath)) { continue }
        $parts = Split-RegistryPath -Path $clsidPath
        $rootKey = [Microsoft.Win32.Registry]::($parts.Root)

        $parentKey = $null
        try { $parentKey = $rootKey.OpenSubKey($parts.SubKey) } catch { continue }
        if ($parentKey -eq $null) { continue }
        $subKeyNames = $parentKey.GetSubKeyNames()
        $parentKey.Close()

        foreach ($name in $subKeyNames) {
            if ($name -notmatch '^\{[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\}$') { continue }
            try {
                $subKey = $rootKey.OpenSubKey("$($parts.SubKey)\$name")
                if ($subKey -eq $null) { $found += "$clsidPath\$name" } else { $subKey.Close() }
            } catch {
                $found += "$clsidPath\$name"
            }
        }
    }
    return ($found | Select-Object -Unique)
}

function Clear-HostsReadOnly {
    $attrib = Get-ItemProperty -Path $hostsPath
    if ($attrib.Attributes -match "ReadOnly") {
        Set-ItemProperty -Path $hostsPath -Name Attributes -Value ($attrib.Attributes -bxor [System.IO.FileAttributes]::ReadOnly)
    }
}

# Strip every DUDE-managed line (marker block + legacy loose entries) from hosts
function Remove-HostsBlock {
    if (-not (Test-Path $hostsPath)) { return }
    Clear-HostsReadOnly

    $lines = @(Get-Content $hostsPath)
    $kept = @()
    $inBlock = $false
    foreach ($line in $lines) {
        if ($line.Trim() -eq $markerStart) { $inBlock = $true; continue }
        if ($line.Trim() -eq $markerEnd)   { $inBlock = $false; continue }
        if ($inBlock) { continue }

        $isValidationEntry = $false
        foreach ($h in $validationHosts) {
            if ($line -match ("(?i)^\s*(127\.0\.0\.1|0\.0\.0\.0)\s+" + [regex]::Escape($h) + "\s*$")) {
                $isValidationEntry = $true
                break
            }
        }
        if (-not $isValidationEntry) { $kept += $line }
    }

    Set-Content -Path $hostsPath -Value $kept -Encoding ASCII -Force
}

function Add-HostsBlock {
    if (-not (Test-Path $hostsPath)) { return }
    Remove-HostsBlock

    $block = @($markerStart)
    foreach ($h in $validationHosts) { $block += "127.0.0.1 $h" }
    $block += $markerEnd

    Add-Content -Path $hostsPath -Value $block -Encoding ASCII -Force
}

function Set-AlertState {
    param ([int]$Value)
    if (-not (Test-Path $statePath)) { New-Item -Path $statePath -Force | Out-Null }
    Set-ItemProperty -Path $statePath -Name "AlertsBlocked" -Value $Value -Type DWord -Force
}

# ------------------------------------------------------------------- main ---

if ($Mode -eq "Off") {
    Write-Host "  [+] Turning IDM alerts OFF..." -ForegroundColor Yellow
    Write-Host ""

    Stop-IDM

    # -- Alert 3: trial expired -> make sure registration data exists
    Write-Host "  [1/3] Restoring registration data (blocks 'trial expired')..." -ForegroundColor Cyan
    Unlock-RegistryKey -Path $regPath
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

    $existing = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace([string]$existing.Serial)) {
        Set-ItemProperty -Path $regPath -Name "FName"  -Value "DUDE" -Force
        Set-ItemProperty -Path $regPath -Name "LName"  -Value "https://discord.gg/fQhJsYZfgp" -Force
        Set-ItemProperty -Path $regPath -Name "Email"  -Value "info@dude.com" -Force
        Set-ItemProperty -Path $regPath -Name "Serial" -Value "OS4VM-IK7ZF-655SG-EP0BO" -Force
    }
    Set-ItemProperty -Path $regPath -Name "LstCheck" -Value "12/31/99" -Force
    Set-ItemProperty -Path $regPath -Name "radxcnt"  -Value 0 -Force
    Set-ItemProperty -Path $regPath -Name "nLst"     -Value 1 -Force
    Remove-ItemProperty -Path $regPath -Name "tvfrdt"      -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "LastCheckQU" -ErrorAction SilentlyContinue

    # -- Alert 2: counterfeit / 30 day block -> cut off validation servers
    Write-Host "  [2/3] Blocking Tonec validation servers (blocks 'counterfeit serial')..." -ForegroundColor Cyan
    try {
        Add-HostsBlock
    } catch {
        Write-Host "        Warning: hosts file update failed ($($_.Exception.Message))" -ForegroundColor Yellow
    }

    # -- Alert 1: fake serial -> freeze the CLSID fingerprint keys
    Write-Host "  [3/3] Locking CLSID tracking keys (blocks 'fake serial')..." -ForegroundColor Cyan
    $proc = Start-Process -FilePath $idmExe -ArgumentList "/onstart" -PassThru -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Stop-IDM

    $trackingKeys = Find-TrackingClsids
    if ($trackingKeys) {
        Write-Host "        Locking $($trackingKeys.Count) keys..." -ForegroundColor Gray
        foreach ($keyPath in $trackingKeys) { Lock-RegistryKey -Path $keyPath }
    } else {
        Write-Host "        No tracking keys found (nothing to lock)." -ForegroundColor Gray
    }

    # Second pass: with the first batch denied, IDM regenerates fresh tracking keys
    # on its next launch. Those are what produce the "fake serial" dialog later, so
    # start IDM once more and lock whatever it just created.
    Write-Host "        Sealing regenerated keys (second pass)..." -ForegroundColor Gray
    $alreadyLocked = @{}
    foreach ($k in $trackingKeys) { $alreadyLocked[$k] = $true }

    $proc = Start-Process -FilePath $idmExe -ArgumentList "/onstart" -PassThru -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Stop-IDM

    $newKeys = @(Find-TrackingClsids | Where-Object { -not $alreadyLocked.ContainsKey($_) })
    if ($newKeys.Count -gt 0) {
        Write-Host "        Locking $($newKeys.Count) regenerated keys..." -ForegroundColor Gray
        foreach ($keyPath in $newKeys) { Lock-RegistryKey -Path $keyPath }
    }

    Set-AlertState -Value 1

    Write-Host ""
    Write-Host "  [SUCCESS] All three IDM alerts are now blocked!" -ForegroundColor Green
    Write-Host "  [!] You can turn them back on any time from this same menu." -ForegroundColor Yellow
    Start-IDM
}
else {
    Write-Host "  [+] Turning IDM alerts back ON (restoring default behaviour)..." -ForegroundColor Yellow
    Write-Host ""

    Stop-IDM

    Write-Host "  [1/3] Unlocking CLSID tracking keys..." -ForegroundColor Cyan
    Unlock-RegistryKey -Path $regPath
    $lockedKeys = Find-LockedClsids
    if ($lockedKeys) {
        Write-Host "        Unlocking $($lockedKeys.Count) keys..." -ForegroundColor Gray
        foreach ($keyPath in $lockedKeys) { Unlock-RegistryKey -Path $keyPath }
    } else {
        Write-Host "        No locked keys found." -ForegroundColor Gray
    }

    Write-Host "  [2/3] Unblocking Tonec validation servers..." -ForegroundColor Cyan
    try {
        Remove-HostsBlock
    } catch {
        Write-Host "        Warning: hosts file cleanup failed ($($_.Exception.Message))" -ForegroundColor Yellow
    }

    Write-Host "  [3/3] Re-enabling IDM online checks..." -ForegroundColor Cyan
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "LstCheck" -Value ((Get-Date).ToString("MM/dd/yy")) -Force
    }

    Set-AlertState -Value 0

    Write-Host ""
    Write-Host "  [SUCCESS] IDM alerts restored to default." -ForegroundColor Green
    Write-Host "  [!] IDM may now show fake/counterfeit serial or trial warnings again." -ForegroundColor Yellow
    Start-IDM
}
