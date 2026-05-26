# Robust script to unlock IDM registry key
try {
    Write-Host "Terminating IDM processes..."
    Stop-Process -Name "IDMan" -ErrorAction SilentlyContinue

    Write-Host "Unlocking HKCU:\SOFTWARE\DownloadManager..."
    $regKey = $null
    try {
        # Try with ChangePermissions rights (Required if current user is Denied SetValue/Delete)
        $nonePermission = [Microsoft.Win32.RegistryKeyPermissionCheck]::None
        $changePerms = [System.Security.AccessControl.RegistryRights]::ChangePermissions
        $regKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("SOFTWARE\DownloadManager", $nonePermission, $changePerms)
    } catch {
        # Fallback to simple write access
        try {
            $regKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("SOFTWARE\DownloadManager", $true)
        } catch {}
    }

    if ($regKey) {
        $acl = $regKey.GetAccessControl()
        $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
        $removedCount = 0
        foreach ($rule in $rules) {
            if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) {
                $acl.RemoveAccessRule($rule) | Out-Null
                $removedCount++
            }
        }
        if ($removedCount -gt 0) {
            $regKey.SetAccessControl($acl)
            Write-Host "Successfully removed $removedCount Deny rule(s)." -ForegroundColor Green
        } else {
            Write-Host "No Deny rules found." -ForegroundColor Yellow
        }
        $regKey.Close()
    } else {
        # Try using Set-Acl directly on the provider path if OpenSubKey failed
        Write-Host "OpenSubKey failed. Trying Set-Acl..." -ForegroundColor Yellow
        $path = "HKCU:\SOFTWARE\DownloadManager"
        if (Test-Path $path) {
            $acl = Get-Acl -Path $path
            $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
            $removedCount = 0
            foreach ($rule in $rules) {
                if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) {
                    $acl.RemoveAccessRule($rule) | Out-Null
                    $removedCount++
                }
            }
            if ($removedCount -gt 0) {
                Set-Acl -Path $path -AclObject $acl
                Write-Host "Successfully unlocked using Set-Acl." -ForegroundColor Green
            } else {
                Write-Host "No Deny rules found via Set-Acl." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Registry key HKCU:\SOFTWARE\DownloadManager does not exist." -ForegroundColor Red
        }
    }
} catch {
    Write-Error $_
}
