# IDM Silent Clean Uninstall Script (No Restart Required)
$ErrorActionPreference = "Stop"

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

# 1. Unregister DLL files to release file locks
Write-Host "Unregistering shell extension and browser integration DLLs..." -ForegroundColor Cyan
$idmDirs = @(
    "C:\Program Files (x86)\Internet Download Manager",
    "C:\Program Files\Internet Download Manager"
)
$dlls = @("IDMShellExt.dll", "IDMShellExt64.dll", "IDMGetAll.dll", "IDMGetAll64.dll", "downlWithIDM.dll", "downlWithIDM64.dll")

foreach ($dir in $idmDirs) {
    if (Test-Path $dir) {
        foreach ($dll in $dlls) {
            $dllPath = Join-Path $dir $dll
            if (Test-Path $dllPath) {
                # Run regsvr32 silently with no GUI popup
                Start-Process -FilePath "regsvr32.exe" -ArgumentList "/u /s `"$dllPath`"" -Wait -ErrorAction SilentlyContinue
            }
        }
    }
}

# Wait for DLL handles to release
Start-Sleep -Seconds 2

# 2. Unlock and delete Registry Keys
Write-Host "Cleaning IDM registry entries..." -ForegroundColor Cyan

# Helper function to unlock registry key permissions (.NET API)
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
        
        # Enable SeTakeOwnershipPrivilege and SeRestorePrivilege
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
        
        # Try to take ownership first (in case it is locked with owner None / Everyone Deny)
        try {
            $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, 'ReadWriteSubTree', 'TakeOwnership')
            if ($regKey) {
                $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
                $acl = New-Object System.Security.AccessControl.RegistrySecurity
                $acl.SetOwner($currentUser)
                $regKey.SetAccessControl($acl)
                $regKey.Close()
            }
        } catch {
            # Silently ignore and proceed to ChangePermissions
        }
        
        # Reset ACL permissions to Everyone Allow FullControl
        $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, 'ReadWriteSubTree', 'ChangePermissions')
        if ($regKey) {
            $acl = $regKey.GetAccessControl()
            $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.ResetAccessRule($rule)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
        }
    } catch {
        # Ignore errors
    }
}
# Helper function to restore hosts file
function Unblock-IDMValidation {
    $hostsPath = "$env:windir\System32\drivers\etc\hosts"
    try {
        if (Test-Path $hostsPath) {
            $content = Get-Content $hostsPath
            $newContent = @()
            $hostsToRemove = @("registeridm.com", "secure.registeridm.com", "secure.internetdownloadmanager.com", "registeridm.one", "star.tonec.com")
            
            foreach ($line in $content) {
                $matched = $false
                foreach ($h in $hostsToRemove) {
                    if ($line -match [regex]::Escape($h)) {
                        $matched = $true
                        break
                    }
                }
                if (-not $matched) {
                    $newContent += $line
                }
            }
            
            $attrib = Get-ItemProperty -Path $hostsPath
            if ($attrib.Attributes -match "ReadOnly") {
                Set-ItemProperty -Path $hostsPath -Name Attributes -Value ($attrib.Attributes -bxor [System.IO.FileAttributes]::ReadOnly)
            }
            
            Set-Content -Path $hostsPath -Value $newContent -Force
            Write-Host "Hosts file restored (validation servers unblocked)." -ForegroundColor Green
        }
    } catch {
        Write-Host "Warning: Failed to restore hosts file ($($_.Exception.Message))" -ForegroundColor Yellow
    }
}
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)

# Restore hosts file
Unblock-IDMValidation

# Compile all standard and browser integration paths to delete
$registryPaths = @(
    "HKCU:\SOFTWARE\DownloadManager",
    "HKLM:\SOFTWARE\Internet Download Manager",
    "HKLM:\SOFTWARE\WOW6432Node\Internet Download Manager"
)

if ($sid) {
    $registryPaths += "Registry::HKEY_USERS\$sid\SOFTWARE\DownloadManager"
}

# Browser native messaging hosts and extensions
$browserPaths = @(
    "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.tonec.idm",
    "HKCU:\Software\Mozilla\NativeMessagingHosts\com.tonec.idm",
    "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.tonec.idm",
    "HKLM:\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.tonec.idm",
    "HKLM:\SOFTWARE\Mozilla\NativeMessagingHosts\com.tonec.idm",
    "HKLM:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.tonec.idm",
    "HKLM:\SOFTWARE\Wow6432Node\Google\Chrome\NativeMessagingHosts\com.tonec.idm",
    "HKLM:\SOFTWARE\Wow6432Node\Mozilla\NativeMessagingHosts\com.tonec.idm",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Edge\NativeMessagingHosts\com.tonec.idm",
    "HKCU:\Software\Google\Chrome\Extensions\ngpampimnmepgilmajochedlaopbbhcf",
    "HKLM:\Software\Google\Chrome\Extensions\ngpampimnmepgilmajochedlaopbbhcf",
    "HKLM:\SOFTWARE\Wow6432Node\Google\Chrome\Extensions\ngpampimnmepgilmajochedlaopbbhcf",
    "HKCU:\Software\Microsoft\Edge\Extensions\ngpampimnmepgilmajochedlaopbbhcf",
    "HKLM:\Software\Microsoft\Edge\Extensions\ngpampimnmepgilmajochedlaopbbhcf",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Edge\Extensions\ngpampimnmepgilmajochedlaopbbhcf"
)

$registryPaths += $browserPaths

foreach ($rp in $registryPaths) {
    if (Test-Path $rp) {
        Unlock-RegistryKey -Path $rp
        try {
            Remove-Item -Path $rp -Recurse -Force -ErrorAction Stop
            Write-Host "Deleted Registry: $rp" -ForegroundColor Green
        } catch {
            if ($_.Exception.Message -match "unauthorized operation" -or $_.Exception.Message -match "Access to the path is denied") {
                Write-Host "Registry path $rp is marked for deletion (will clear when active browser sessions are closed)." -ForegroundColor Green
            } else {
                Write-Host "Failed to delete registry key: $rp - $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

# 3. Clean hidden trial keys under CLSID
Write-Host "Purging hidden trial registration keys under CLSID..." -ForegroundColor Cyan

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

$finalKeysToDelete = @()

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
    } catch {
        continue
    }
    
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
                $finalKeysToDelete += $fullPsPath
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
                    $finalKeysToDelete += $fullPsPath
                } elseif (($defaultValueStr -match '\+|=') -and ($subKeyCount -eq 0)) {
                    $finalKeysToDelete += $fullPsPath
                } elseif ($hasVersionMatch) {
                    $finalKeysToDelete += $fullPsPath
                } elseif ($hasMatchProperty) {
                    $finalKeysToDelete += $fullPsPath
                } elseif (($valueCount -eq 0) -and ($subKeyCount -eq 0)) {
                    $finalKeysToDelete += $fullPsPath
                }
            } catch {
                $finalKeysToDelete += $fullPsPath
            }
        }
    }
}

$finalKeysToDelete = $finalKeysToDelete | Select-Object -Unique

if ($finalKeysToDelete) {
    Write-Host "Found $($finalKeysToDelete.Count) trial CLSID keys to purge. Cleaning..." -ForegroundColor Cyan
    foreach ($keyPath in $finalKeysToDelete) {
        if (Test-Path $keyPath) {
            Unlock-RegistryKey -Path $keyPath
            try {
                Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                Write-Host "Purged CLSID: $keyPath" -ForegroundColor Green
            } catch {
                Write-Host "Failed to purge CLSID: $keyPath - $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

# 4. Clean leftover files and folders
Write-Host "Cleaning leftover installation and data directories..." -ForegroundColor Cyan
$pathsToDelete = @(
    "$env:APPDATA\Internet Download Manager",
    "$env:LOCALAPPDATA\DwnlData",
    "C:\Program Files (x86)\Internet Download Manager",
    "C:\Program Files\Internet Download Manager"
)

foreach ($p in $pathsToDelete) {
    if (Test-Path $p) {
        try {
            Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
            Write-Host "Deleted: $p" -ForegroundColor Green
        } catch {
            Write-Host "Some files in $($p) are locked by Explorer. Restarting Windows Explorer to release locks..." -ForegroundColor Yellow
            # Force restart explorer.exe
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            try {
                Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
                Write-Host "Deleted: $($p) (after Explorer restart)" -ForegroundColor Green
            } catch {
                Write-Host "Could not delete $($p): $($_.Exception.Message)" -ForegroundColor Yellow
            }
            # Make sure Windows Explorer is restarted
            if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
                Start-Process explorer.exe
            }
        }
    }
}

Write-Host "Clean uninstallation finished successfully!" -ForegroundColor Green
