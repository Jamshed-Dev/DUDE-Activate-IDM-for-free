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
        Write-Host "Successfully unlocked: $Path" -ForegroundColor Green
    } catch {
        Write-Host "Failed to unlock: $Path - $($_.Exception.Message)" -ForegroundColor Red
    }
}

$keys = @(
    "HKCU:\Software\Classes\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}",
    "HKCU:\Software\Classes\WOW6432Node\CLSID\{79873CC5-3951-43ED-BDF9-D8759474B6FD}",
    "HKCU:\Software\Classes\WOW6432Node\CLSID\{E6871B76-C3C8-44DD-B947-ABFFE144860D}"
)

# Terminate IDM
Stop-Process -Name "IDMan" -ErrorAction SilentlyContinue
Stop-Process -Name "IEMonitor" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# Unlock and delete keys
foreach ($k in $keys) {
    if (Test-Path $k) {
        Unlock-RegistryKey -Path $k
        Remove-Item -Path $k -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted registry key: $k" -ForegroundColor Green
    }
}

# Delete DownloadManager settings
$dm = "HKCU:\Software\DownloadManager"
if (Test-Path $dm) {
    Unlock-RegistryKey -Path $dm
    Remove-Item -Path $dm -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Deleted DownloadManager settings: $dm" -ForegroundColor Green
}
