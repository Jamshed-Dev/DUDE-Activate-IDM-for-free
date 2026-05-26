$regKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('SOFTWARE\DownloadManager', 'ReadWriteSubTree', 'ChangePermissions')
if ($regKey) {
    $acl = $regKey.GetAccessControl()
    $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
    foreach ($rule in $rules) {
        if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) {
            $acl.RemoveAccessRule($rule) | Out-Null
        }
    }
    $regKey.SetAccessControl($acl)
    $regKey.Close()
    Write-Host "Unlocked DownloadManager successfully!"
} else {
    Write-Host "Failed to open DownloadManager key."
}
