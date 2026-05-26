# IDM Registry Trial Reset Script
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
    $installChoice = Read-Host "Do you want to download and install the latest official IDM now? (Y/N)"
    if ($installChoice -eq "Y" -or $installChoice -eq "y" -or $installChoice -eq "") {
        Write-Host "Fetching latest official IDM download link..." -ForegroundColor Cyan
        $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        $downloadUrl = ""
        try {
            $url = "https://www.internetdownloadmanager.com/download.html"
            if (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue) {
                $html = Invoke-WebRequest -Uri $url -UserAgent $userAgent -UseBasicParsing -TimeoutSec 15
                $downloadUrl = $html.Links | Where-Object { $_.href -like "*idman*.exe" } | Select-Object -First 1 -ExpandProperty href
            } else {
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", $userAgent)
                $pageSource = $webClient.DownloadString($url)
                if ($pageSource -match 'href="([^"]*idman[^"]*\.exe)"') {
                    $downloadUrl = $Matches[1]
                }
            }
        } catch {
            Write-Host "Warning: Failed to extract link dynamically ($($_.Exception.Message))." -ForegroundColor Yellow
        }
        
        if (-not $downloadUrl) {
            $downloadUrl = "https://mirror2.internetdownloadmanager.com/idman642build64.exe"
        }
        
        $tempFile = "$env:TEMP\idm_setup.exe"
        Write-Host "Downloading IDM from Tonec..." -ForegroundColor Cyan
        try {
            # Download file using robust fallback
            if (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue) {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UserAgent $userAgent -UseBasicParsing -TimeoutSec 60
            } else {
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", $userAgent)
                $webClient.DownloadFile($downloadUrl, $tempFile)
            }
            Write-Host "Launching official setup wizard..." -ForegroundColor Green
            Write-Host "Please complete the setup to proceed with trial reset." -ForegroundColor Yellow
            Start-Process -FilePath $tempFile -Wait
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            
            # Re-verify path
            if (Test-Path "C:\Program Files (x86)\Internet Download Manager\IDMan.exe") {
                $idmPath = "C:\Program Files (x86)\Internet Download Manager\IDMan.exe"
            } elseif (Test-Path "C:\Program Files\Internet Download Manager\IDMan.exe") {
                $idmPath = "C:\Program Files\Internet Download Manager\IDMan.exe"
            }
            if (-not $idmPath) {
                Write-Host "Installation was not completed. Trial reset cancelled." -ForegroundColor Red
                exit
            }
        } catch {
            Write-Host "Error: Failed to download or install IDM ($($_.Exception.Message))" -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "Action cancelled. IDM must be installed to reset trial." -ForegroundColor Red
        exit
    }
}

# Proceed with trial reset
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
        # Ignore errors during unlocking
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

# 1. Unlock and delete trial values under DownloadManager registry keys
Write-Host "Clearing IDM trial and registration values..." -ForegroundColor Cyan

$downloadManagerPaths = @("HKCU:\SOFTWARE\DownloadManager")
if ($sid) {
    $downloadManagerPaths += "Registry::HKEY_USERS\$sid\SOFTWARE\DownloadManager"
}

$valuesToDelete = @("tvfrdt", "radxcnt", "LstCheck", "LastCheckQU", "CheckUpdtVM", "FName", "LName", "Email", "Serial", "scansk", "awd", "almd", "adv", "dsk", "ptrk_scdt")

foreach ($dmPath in $downloadManagerPaths) {
    if (Test-Path $dmPath) {
        Unlock-RegistryKey -Path $dmPath
        foreach ($val in $valuesToDelete) {
            Remove-ItemProperty -Path $dmPath -Name $val -ErrorAction SilentlyContinue
        }
    }
}

# 2. Clean hidden trial keys under CLSID (architecture aware and surgically filtered)
Write-Host "Scanning and cleaning hidden trial keys under CLSID..." -ForegroundColor Cyan

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

# Delete found keys
if ($finalKeysToDelete) {
    Write-Host "Found $($finalKeysToDelete.Count) IDM trial tracking registry keys. Cleaning..." -ForegroundColor Cyan
    foreach ($keyPath in $finalKeysToDelete) {
        if (Test-Path $keyPath) {
            Unlock-RegistryKey -Path $keyPath
            try {
                Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                Write-Host "Deleted: $keyPath" -ForegroundColor Green
            } catch {
                Write-Host "Failed to delete: $keyPath - $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "No IDM trial tracking CLSID keys found." -ForegroundColor Green
}

Write-Host "IDM Trial Reset completed successfully! Your 30-day trial has been restored." -ForegroundColor Green

# Start IDM as standard user via Shell.Application
if ($idmPath) {
    Write-Host "Starting IDM..." -ForegroundColor Cyan
    $shell = New-Object -ComObject "Shell.Application"
    $shell.ShellExecute($idmPath)
}
