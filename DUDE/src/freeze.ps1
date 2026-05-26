# IDM Registry Trial Freeze Script
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

# Helper function to trigger IDM offline startup and initialize registry CLSIDs
function Trigger-IDMInitialization {
    param (
        [string]$Path
    )
    Write-Host "Initializing IDM registry settings offline..." -ForegroundColor Cyan
    
    # Start IDM minimized to system tray to trigger offline key generation
    $proc = Start-Process -FilePath $Path -ArgumentList "/onstart" -PassThru -ErrorAction SilentlyContinue
    
    # Wait 3 seconds for IDM engine to initialize registry database
    Start-Sleep -Seconds 3
    
    # Terminate IDM process so we can safely lock the keys
    Stop-Process -Name "IDMan" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

if (-not $idmPath) {
    Write-Host "Internet Download Manager is not installed on your computer!" -ForegroundColor Yellow
    Write-Host "Please install it first before freezing trial." -ForegroundColor Yellow
    exit
}

# Proceed with trial freeze
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

# Helper function to lock registry key permissions (Everyone Deny FullControl, Owner S-1-0-0)
function Lock-RegistryKey {
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
        
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
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
        
        $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, 'ReadWriteSubTree', 'TakeOwnership')
        if ($regKey) {
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
            $acl = New-Object System.Security.AccessControl.RegistrySecurity
            $acl.SetOwner($currentUser)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
        }
        
        $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, 'ReadWriteSubTree', 'ChangePermissions')
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

# 1. Unlock the main registry key permanently (never keep DownloadManager locked!)
Write-Host "Unlocking main DownloadManager key..." -ForegroundColor Cyan
Unlock-RegistryKey -Path $regPath

# 2. Reset registration values to restore trial mode
Write-Host "Resetting IDM registration values..." -ForegroundColor Cyan
if (Test-Path $regPath) {
    $valuesToDelete = @("FName", "LName", "Email", "Serial", "LstCheck", "radxcnt", "nLst", "tvfrdt", "LastCheckQU")
    foreach ($val in $valuesToDelete) {
        Remove-ItemProperty -Path $regPath -Name $val -ErrorAction SilentlyContinue
    }
}

# Trigger IDM to initialize CLSID keys first
Trigger-IDMInitialization -Path $idmPath

# 3. Find and lock CLSID trial registry keys to freeze the 30-day trial forever
Write-Host "Locking CLSID keys to freeze trial..." -ForegroundColor Cyan
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)

$clsidPaths = @(
    "HKCU:\Software\Classes\CLSID",
    "HKCU:\Software\Classes\WOW6432Node\CLSID",
    "HKLM:\Software\Classes\CLSID",
    "HKLM:\Software\Classes\WOW6432Node\CLSID"
)
if ($sid) {
    $clsidPaths += "Registry::HKEY_USERS\$sid\Software\Classes\CLSID"
    $clsidPaths += "Registry::HKEY_USERS\$sid\Software\Classes\Wow6432Node\CLSID"
}

$finalKeys = @()

foreach ($clsidPath in $clsidPaths) {
    if (-not (Test-Path $clsidPath)) { continue }
    
    $rootKeyName = "CurrentUser"
    $subKeyPath = $clsidPath
    
    if ($clsidPath.StartsWith("HKCU:\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $subKeyPath = $clsidPath.Substring(6)
        $rootKeyName = "CurrentUser"
    } elseif ($clsidPath.StartsWith("HKLM:\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $subKeyPath = $clsidPath.Substring(6)
        $rootKeyName = "LocalMachine"
    } elseif ($clsidPath.StartsWith("HKU:\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $subKeyPath = $clsidPath.Substring(5)
        $rootKeyName = "Users"
    } elseif ($clsidPath.StartsWith("Registry::HKEY_USERS\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $subKeyPath = $clsidPath.Substring(21)
        $rootKeyName = "Users"
    }
    
    $rootKey = [Microsoft.Win32.Registry]::$rootKeyName
    $parentKey = $null
    try {
        $parentKey = $rootKey.OpenSubKey($subKeyPath)
    } catch { continue }
    
    if ($parentKey -eq $null) { continue }
    $subKeyNames = $parentKey.GetSubKeyNames()
    $parentKey.Close()
    
    foreach ($name in $subKeyNames) {
        if ($name -match '^\{[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\}$') {
            $fullSubKeyPath = "$subKeyPath\$name"
            $fullPsPath = "$clsidPath\$name"
            
            $isLocked = $false
            $subKey = $null
            try {
                $subKey = $rootKey.OpenSubKey($fullSubKeyPath)
                if ($subKey -eq $null) {
                    $isLocked = $true
                }
            } catch {
                $isLocked = $true
            }
            
            if ($isLocked) {
                $finalKeys += $fullPsPath
                continue
            }
            
            try {
                $valueCount = $subKey.ValueCount
                $subKeyCount = $subKey.SubKeyCount
                $defaultValue = $subKey.GetValue("")
                $defaultValueStr = if ($defaultValue -ne $null) { $defaultValue.ToString() } else { "" }
                
                $valueNames = $subKey.GetValueNames()
                $hasMatchProperty = $false
                foreach ($valName in $valueNames) {
                    if ($valName -match '^MData$|^Model$|^scansk$|^Therad$') {
                        $hasMatchProperty = $true
                        break
                    }
                }
                
                $hasVersionMatch = $false
                if ($subKeyCount -eq 1 -and ($subKey.GetSubKeyNames() -contains "Version")) {
                    $verKey = $subKey.OpenSubKey("Version")
                    if ($verKey -ne $null) {
                        $verVal = $verKey.GetValue("")
                        if ($verVal -ne $null -and $verVal.ToString() -match '^\d+$') {
                            $hasVersionMatch = $true
                        }
                        $verKey.Close()
                    }
                }
                
                $subKey.Close()
                
                if (($defaultValueStr -match '^\d+$') -and ($subKeyCount -eq 0)) {
                    $finalKeys += $fullPsPath
                } elseif (($defaultValueStr -match '\+|=') -and ($subKeyCount -eq 0)) {
                    $finalKeys += $fullPsPath
                } elseif ($hasVersionMatch) {
                    $finalKeys += $fullPsPath
                } elseif ($hasMatchProperty) {
                    $finalKeys += $fullPsPath
                } elseif (($valueCount -eq 0) -and ($subKeyCount -eq 0)) {
                    $finalKeys += $fullPsPath
                }
            } catch {
                $finalKeys += $fullPsPath
            }
        }
    }
}

$finalKeys = $finalKeys | Select-Object -Unique

# If there are trial keys, lock them!
if ($finalKeys) {
    Write-Host "Locking $($finalKeys.Count) tracking CLSID keys..." -ForegroundColor Cyan
    foreach ($keyPath in $finalKeys) {
        Lock-RegistryKey -Path $keyPath
    }
}

Write-Host "IDM Trial Frozen successfully!" -ForegroundColor Green

# Start IDM as standard user via Shell.Application
if ($idmPath) {
    Write-Host "Starting IDM..." -ForegroundColor Cyan
    $shell = New-Object -ComObject "Shell.Application"
    $shell.ShellExecute($idmPath)
}
