$Path = "HKCU:\SOFTWARE\TestFullLockKey"
New-Item -Path $Path -Force | Out-Null

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
$none = New-Object System.Security.Principal.SecurityIdentifier('S-1-0-0')

# Lock it: Set owner to None (Nobody) and Deny Everyone FullControl
$acl = Get-Acl -Path $Path
$acl.SetOwner($none)
$rule = New-Object System.Security.AccessControl.RegistryAccessRule(
    $everyone,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Deny"
)
$acl.SetAccessRule($rule)
Set-Acl -Path $Path -AclObject $acl

Write-Host "Fully locked key with owner None and Deny Everyone FullControl."

# Verify we cannot delete or read it normally
try {
    Get-ItemProperty -Path $Path -ErrorAction Stop
    Write-Host "Warning: Key is still accessible normally!"
} catch {
    Write-Host "Verified: Key is inaccessible normally ($($_.Exception.Message))"
}

# Unlock function
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
        
        # Take ownership
        $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
        if ($regKey) {
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
            $acl = New-Object System.Security.AccessControl.RegistrySecurity
            $acl.SetOwner($currentUser)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
            Write-Host "Ownership taken successfully."
        }
        
        # Reset ACL
        $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
        if ($regKey) {
            $acl = $regKey.GetAccessControl()
            $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.ResetAccessRule($rule)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
            Write-Host "Permissions reset successfully."
        }
    } catch {
        Write-Host "Unlock failed: $($_.Exception.Message)"
    }
}

Unlock-RegistryKey -Path $Path

# Try to delete it
try {
    Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
    Write-Host "Deleted successfully after unlock!"
} catch {
    Write-Host "Delete failed: $($_.Exception.Message)"
}
