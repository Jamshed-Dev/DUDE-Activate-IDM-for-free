# IDM Registry Activation Script
$ErrorActionPreference = "Stop"

# Enable TLS 1.2 and TLS 1.3 dynamically for secure downloads
try {
    [Net.ServicePointManager]::SecurityProtocol = 3072 -bor 12288
} catch {}

$regPath = "HKCU:\SOFTWARE\DownloadManager"

# Check if IDM is installed
$idmPath = ""
if (Test-Path "C:\Program Files (x86)\Internet Download Manager\IDMan.exe") {
    $idmPath = "C:\Program Files (x86)\Internet Download Manager\IDMan.exe"
} elseif (Test-Path "C:\Program Files\Internet Download Manager\IDMan.exe") {
    $idmPath = "C:\Program Files\Internet Download Manager\IDMan.exe"
}

if (-not $idmPath) {
    Write-Host "Internet Download Manager is not installed on your computer!" -ForegroundColor Yellow
    Write-Host "Please install it first before activating." -ForegroundColor Yellow
    exit
}

# Proceed with activation
Write-Host "Terminating IDM processes..." -ForegroundColor Cyan
$processes = @("IDMan", "IEMonitor")
foreach ($procName in $processes) {
    $count = 0
    while ((Get-Process -Name $procName -ErrorAction SilentlyContinue) -and ($count -lt 10)) {
        Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        $count++
    }
}
Start-Sleep -Seconds 1

# Helper function to unlock registry key permissions
function Unlock-RegistryKey {
    param (
        [string]$Path
    )
    try {
        $subKeyPath = $Path
        $rootKey = "CurrentUser"
        
        if ($Path.StartsWith("HKCU:\", [System.StringComparison]::OrdinalIgnoreCase)) {
            $subKeyPath = $Path.Substring(6)
            $rootKey = "CurrentUser"
        } elseif ($Path.StartsWith("HKLM:\", [System.StringComparison]::OrdinalIgnoreCase)) {
            $subKeyPath = $Path.Substring(6)
            $rootKey = "LocalMachine"
        } elseif ($Path.StartsWith("HKU:\", [System.StringComparison]::OrdinalIgnoreCase)) {
            $subKeyPath = $Path.Substring(5)
            $rootKey = "Users"
        } elseif ($Path.StartsWith("Registry::HKEY_USERS\", [System.StringComparison]::OrdinalIgnoreCase)) {
            $subKeyPath = $Path.Substring(21)
            $rootKey = "Users"
        }
        
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
        
        try {
            $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, 'ReadWriteSubTree', 'TakeOwnership')
            if ($regKey) {
                $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
                $acl = New-Object System.Security.AccessControl.RegistrySecurity
                $acl.SetOwner($currentUser)
                $regKey.SetAccessControl($acl)
                $regKey.Close()
            }
        } catch {}
        
        $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, 'ReadWriteSubTree', 'ChangePermissions')
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


# 1. Unlock the main registry key permanently (never keep DownloadManager locked!)
Write-Host "Unlocking main DownloadManager key..." -ForegroundColor Cyan
Unlock-RegistryKey -Path $regPath

# 2. Write registration details
Write-Host "Writing registration details..." -ForegroundColor Cyan
if (!(Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "FName" -Value "DUDE" -Force
Set-ItemProperty -Path $regPath -Name "LName" -Value "https://discord.gg/fQhJsYZfgp" -Force
Set-ItemProperty -Path $regPath -Name "Email" -Value "info@dude.com" -Force
Set-ItemProperty -Path $regPath -Name "Serial" -Value "OS4VM-IK7ZF-655SG-EP0BO" -Force
Set-ItemProperty -Path $regPath -Name "LstCheck" -Value "12/31/99" -Force
Set-ItemProperty -Path $regPath -Name "radxcnt" -Value 0 -Force
Set-ItemProperty -Path $regPath -Name "nLst" -Value 1 -Force

# Remove any block/check parameters that cause false serial warning
Remove-ItemProperty -Path $regPath -Name "tvfrdt" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $regPath -Name "LastCheckQU" -ErrorAction SilentlyContinue

# 3. Block every alert path (fake serial / counterfeit serial / trial expired).
# alerts.ps1 owns this logic: it blocks the validation hosts, triggers IDM so the
# CLSID tracking keys exist, locks them, then does a second pass to seal the keys
# IDM regenerates afterwards - which is what used to leak the fake serial warning.
Write-Host ""
& "$PSScriptRoot\alerts.ps1" -Mode Off
Write-Host ""
Write-Host "IDM Activated and Registry Secured successfully!" -ForegroundColor Green
