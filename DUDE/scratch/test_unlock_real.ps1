# Test Lock and Unlock
$ErrorActionPreference = "Stop"

$testPath = "HKCU:\SOFTWARE\DudeTestLockKey"
if (Test-Path $testPath) {
    Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $testPath -Force | Out-Null
Set-ItemProperty -Path $testPath -Name "TestVal" -Value "Hello" -Force

# Lock-RegistryKey function from activate.ps1
function Lock-RegistryKey {
    param ([string]$Path)
    $subKeyPath = $Path.Substring(6) # HKCU:\
    $rootKey = "CurrentUser"
    
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    
    $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('RegistryPrivileges_' + [Guid]::NewGuid().ToString('N'))), [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('PrivilegeModule', $False)
    $TypeBuilder = $ModuleBuilder.DefineType('PrivilegeType', 'Public, Class')
    $TypeBuilder.DefinePInvokeMethod('RtlAdjustPrivilege', 'ntdll.dll', 'Public, Static', [System.Reflection.CallingConventions]::Standard, [int], @([int], [bool], [bool], [bool].MakeByRefType()), [System.Runtime.InteropServices.CharSet]::Ansi, [System.Runtime.InteropServices.LayoutKind]::Auto) | Out-Null
    $Type = $TypeBuilder.CreateType()
    
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
}

# Unlock-RegistryKey function from uninstall.ps1
function Unlock-RegistryKey {
    param ([string]$Path)
    $subKeyPath = $Path.Substring(6) # HKCU:\
    $rootKey = "CurrentUser"
    
    $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('RegistryPrivileges_' + [Guid]::NewGuid().ToString('N'))), [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('PrivilegeModule', $False)
    $TypeBuilder = $ModuleBuilder.DefineType('PrivilegeType', 'Public, Class')
    $TypeBuilder.DefinePInvokeMethod('RtlAdjustPrivilege', 'ntdll.dll', 'Public, Static', [System.Reflection.CallingConventions]::Standard, [int], @([int], [bool], [bool], [bool].MakeByRefType()), [System.Runtime.InteropServices.CharSet]::Ansi, [System.Runtime.InteropServices.LayoutKind]::Auto) | Out-Null
    $Type = $TypeBuilder.CreateType()
    
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
            Write-Host "Took ownership successfully."
        } else {
            Write-Host "Failed to open key for ownership (returned null)."
        }
    } catch {
        Write-Host "TakeOwnership Exception: $($_.Exception.Message)"
    }
    
    try {
        $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($subKeyPath, 'ReadWriteSubTree', 'ChangePermissions')
        if ($regKey) {
            $acl = $regKey.GetAccessControl()
            $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.ResetAccessRule($rule)
            $regKey.SetAccessControl($acl)
            $regKey.Close()
            Write-Host "Changed permissions successfully."
        } else {
            Write-Host "Failed to open key for ChangePermissions (returned null)."
        }
    } catch {
        Write-Host "ChangePermissions Exception: $($_.Exception.Message)"
    }
}

Write-Host "Locking key..."
Lock-RegistryKey -Path $testPath

Write-Host "Verifying key is locked (should fail to read value)..."
try {
    $val = Get-ItemProperty -Path $testPath -Name "TestVal" -ErrorAction Stop
    Write-Host "Key not locked! Value read: $($val.TestVal)" -ForegroundColor Red
} catch {
    Write-Host "Key is verified locked (as expected: $($_.Exception.Message))" -ForegroundColor Green
}

Write-Host "Unlocking key..."
Unlock-RegistryKey -Path $testPath

Write-Host "Verifying key is unlocked (should succeed to delete)..."
try {
    Remove-Item -Path $testPath -Recurse -Force -ErrorAction Stop
    Write-Host "Key successfully unlocked and deleted!" -ForegroundColor Green
} catch {
    Write-Host "Unlock verification failed: $($_.Exception.Message)" -ForegroundColor Red
}
