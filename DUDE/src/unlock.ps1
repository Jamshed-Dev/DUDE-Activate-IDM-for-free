# IDM Registry Unlock Script
$ErrorActionPreference = "Stop"

Write-Host "Unlocking main DownloadManager key permissions..." -ForegroundColor Cyan

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
        
        # Enable privileges
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
        
        # Take ownership first (in case it is locked with owner None / Everyone Deny)
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
        
        # Reset ACL permissions to Everyone Allow FullControl
        $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, 'ReadWriteSubTree', 'ChangePermissions')
        if ($regKey) {
            $acl = $regKey.GetAccessControl()
            $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.ResetAccessRule($rule)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
            Write-Host "Unlocked permissions: $Path" -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to unlock permissions for $Path : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 1. Unlock the main registry key
Unlock-RegistryKey -Path "HKCU:\SOFTWARE\DownloadManager"

# 2. Find and unlock all CLSID tracking keys
Write-Host "Scanning for locked CLSID keys to restore default permissions..." -ForegroundColor Cyan
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

$lockedClsids = @()

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
                $lockedClsids += $fullPsPath
            }
        }
    }
}

$lockedClsids = $lockedClsids | Select-Object -Unique

if ($lockedClsids) {
    Write-Host "Found $($lockedClsids.Count) locked CLSID keys. Restoring permissions..." -ForegroundColor Cyan
    foreach ($keyPath in $lockedClsids) {
        Unlock-RegistryKey -Path $keyPath
    }
    Write-Host "All registry locks successfully removed!" -ForegroundColor Green
} else {
    Write-Host "No locked registry keys found." -ForegroundColor Green
}
