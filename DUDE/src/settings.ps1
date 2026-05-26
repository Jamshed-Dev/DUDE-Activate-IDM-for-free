# IDM Settings & Tools Submenu Script
$ErrorActionPreference = "Stop"

# Enable UTF-8 console output for block characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$regPath = "HKCU:\SOFTWARE\DownloadManager"

# Check if IDM is installed and get path
$idmExe = ""
if (Test-Path "C:\Program Files (x86)\Internet Download Manager\IDMan.exe") {
    $idmExe = "C:\Program Files (x86)\Internet Download Manager\IDMan.exe"
} elseif (Test-Path "C:\Program Files\Internet Download Manager\IDMan.exe") {
    $idmExe = "C:\Program Files\Internet Download Manager\IDMan.exe"
}

# Helper to restart IDM if running
function Restart-IDM {
    if ($idmExe) {
        Write-Host "  [+] Restarting IDM..." -ForegroundColor Cyan
        Stop-Process -Name "IDMan" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        $shell = New-Object -ComObject "Shell.Application"
        $shell.ShellExecute($idmExe)
    }
}

# Submenu loop
$exitSubmenu = $false
do {
    Clear-Host
    Write-Host ""
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |                 DUDE IDM SETTINGS & TOOLS                 |" -ForegroundColor Green
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    
    # Check current states
    $maxMCVal = 0
    $lstCheckVal = ""
    $startupVal = 0
    
    if (Test-Path $regPath) {
        $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($props.maxMC -ne $null) { $maxMCVal = $props.maxMC }
        if ($props.LstCheck -ne $null) { $lstCheckVal = $props.LstCheck }
        if ($props.LaunchOnStart -ne $null) { $startupVal = $props.LaunchOnStart }
    }
    
    # Display speed state
    $speedState = "Default (8 connections)"
    if ($maxMCVal -eq 1532) {
        $speedState = "Optimized (32 connections)"
    } elseif ($maxMCVal -eq 1516) {
        $speedState = "Optimized (16 connections)"
    }
    
    # Display updates state
    $updatesState = "Enabled"
    if ($lstCheckVal -eq "12/31/99") {
        $updatesState = "Disabled (Blocked)"
    }
    
    # Display startup state
    $startupState = "Disabled"
    if ($startupVal -eq 1) {
        $startupState = "Enabled"
    }

    Write-Host "  Current Status:" -ForegroundColor Yellow
    Write-Host "  - Download Connections : " -NoNewline -ForegroundColor Gray
    Write-Host $speedState -ForegroundColor Green
    Write-Host "  - Auto-Updates Check   : " -NoNewline -ForegroundColor Gray
    Write-Host $updatesState -ForegroundColor Green
    Write-Host "  - Launch on Startup    : " -NoNewline -ForegroundColor Gray
    Write-Host $startupState -ForegroundColor Green
    Write-Host ""
    Write-Host "  -------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  [1] " -NoNewline -ForegroundColor White
    Write-Host "Optimize Download Speed" -NoNewline -ForegroundColor Green
    Write-Host " - Enable High-Speed 32 connections" -ForegroundColor Gray
    
    Write-Host "  [2] " -NoNewline -ForegroundColor White
    Write-Host "Toggle Auto-Updates" -NoNewline -ForegroundColor Green
    Write-Host "    - Block or allow IDM online update checks" -ForegroundColor Gray
    
    Write-Host "  [3] " -NoNewline -ForegroundColor White
    Write-Host "Import Extra Extensions" -NoNewline -ForegroundColor Green
    Write-Host " - Add extra file formats to IDM download list" -ForegroundColor Gray
    
    Write-Host "  [4] " -NoNewline -ForegroundColor White
    Write-Host "Backup Settings & Queue" -NoNewline -ForegroundColor Green
    Write-Host " - Export settings & download history to Desktop" -ForegroundColor Gray
    
    Write-Host "  [5] " -NoNewline -ForegroundColor White
    Write-Host "Restore Settings & Queue" -NoNewline -ForegroundColor Green
    Write-Host "- Import settings & download history from Desktop" -ForegroundColor Gray
    
    Write-Host "  [6] " -NoNewline -ForegroundColor White
    Write-Host "Fix Browser Integration" -NoNewline -ForegroundColor Green
    Write-Host " - Repair extension capture/missing download bar" -ForegroundColor Gray
    
    Write-Host "  [7] " -NoNewline -ForegroundColor White
    Write-Host "Toggle Startup Launch" -NoNewline -ForegroundColor Green
    Write-Host "   - Turn IDM auto-launch on startup ON or OFF" -ForegroundColor Gray
    
    Write-Host "  [8] " -NoNewline -ForegroundColor White
    Write-Host "Unlock Registry" -NoNewline -ForegroundColor Green
    Write-Host "         - Restore registry permissions to default" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "  [9] " -NoNewline -ForegroundColor White
    Write-Host "Back to Main Menu" -ForegroundColor Red
    Write-Host ""
    Write-Host "  -------------------------------------------------------------" -ForegroundColor Cyan
    
    $choice = Read-Host "  Enter choice [1-9]"
    
    switch ($choice) {
        "1" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Optimizing connection speed & setting 32 connections..." -ForegroundColor Yellow
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name "maxMC" -Value 1532 -Force
            Write-Host "  [SUCCESS] IDM Speed Optimized to 32 Connections successfully!" -ForegroundColor Green
            Restart-IDM
            Write-Host ""
            Read-Host "  Press Enter to return..."
        }
        "2" {
            Clear-Host
            Write-Host ""
            if ($lstCheckVal -eq "12/31/99") {
                Write-Host "  [+] Enabling Auto-Updates..." -ForegroundColor Yellow
                $today = (Get-Date).ToString("MM/dd/yy")
                Set-ItemProperty -Path $regPath -Name "LstCheck" -Value $today -Force
                Write-Host "  [SUCCESS] Auto-Updates check enabled." -ForegroundColor Green
            } else {
                Write-Host "  [+] Blocking Auto-Updates..." -ForegroundColor Yellow
                Set-ItemProperty -Path $regPath -Name "LstCheck" -Value "12/31/99" -Force
                Write-Host "  [SUCCESS] Auto-Updates check disabled (nag screen blocked)!" -ForegroundColor Green
            }
            Write-Host ""
            Read-Host "  Press Enter to return..."
        }
        "3" {
            Clear-Host
            Write-Host ""
            $extFile = "$PSScriptRoot\extensions.bin"
            if (-not (Test-Path $extFile)) {
                Write-Host "  [ERROR] Extensions file (extensions.bin) not found!" -ForegroundColor Red
                Write-Host ""
                Read-Host "  Press Enter to return..."
                continue
            }
            Write-Host "  [+] Temporarily unlocking registry..." -ForegroundColor Yellow
            & "$PSScriptRoot\unlock.ps1" | Out-Null
            Write-Host "  [+] Importing extra file-type extensions..." -ForegroundColor Yellow
            Start-Process -FilePath "regedit.exe" -ArgumentList "/s `"$extFile`"" -Wait
            Write-Host "  [SUCCESS] Extra extensions imported successfully!" -ForegroundColor Green
            Write-Host ""
            Read-Host "  Press Enter to return..."
        }
        "4" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Stopping IDM process before backup..." -ForegroundColor Yellow
            Stop-Process -Name "IDMan" -Force -ErrorAction SilentlyContinue
            Stop-Process -Name "IEMonitor" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1

            $desktop = [System.Environment]::GetFolderPath("Desktop")
            $backupDir = Join-Path $desktop "IDM_Backup"
            if (-not (Test-Path $backupDir)) {
                New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
            }

            try {
                Write-Host "  [+] Exporting IDM registry settings..." -ForegroundColor Yellow
                reg.exe export "HKCU\Software\DownloadManager" "$backupDir\idm_settings.reg" /y | Out-Null
                
                $appDataDir = "$env:APPDATA\Internet Download Manager"
                if (Test-Path $appDataDir) {
                    Write-Host "  [+] Compressing IDM download database and queue..." -ForegroundColor Yellow
                    $zipPath = "$backupDir\idm_data.zip"
                    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
                    Compress-Archive -Path $appDataDir -DestinationPath $zipPath -Force
                }
                Write-Host ""
                Write-Host "  [SUCCESS] Backup completed successfully!" -ForegroundColor Green
                Write-Host "  [!] Backup files saved to: Desktop\IDM_Backup" -ForegroundColor Yellow
            } catch {
                Write-Host "  [ERROR] Backup failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            Restart-IDM
            Write-Host ""
            Read-Host "  Press Enter to return..."
        }
        "5" {
            Clear-Host
            Write-Host ""
            $desktop = [System.Environment]::GetFolderPath("Desktop")
            $backupDir = Join-Path $desktop "IDM_Backup"
            $regFile = "$backupDir\idm_settings.reg"
            $zipFile = "$backupDir\idm_data.zip"

            if (-not (Test-Path $regFile)) {
                Write-Host "  [ERROR] Backup registry settings file not found in Desktop\IDM_Backup!" -ForegroundColor Red
                Write-Host ""
                Read-Host "  Press Enter to return..."
                continue
            }

            Write-Host "  [+] Stopping IDM process before restore..." -ForegroundColor Yellow
            Stop-Process -Name "IDMan" -Force -ErrorAction SilentlyContinue
            Stop-Process -Name "IEMonitor" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1

            try {
                Write-Host "  [+] Importing IDM registry settings..." -ForegroundColor Yellow
                reg.exe import $regFile | Out-Null

                $appDataDir = "$env:APPDATA\Internet Download Manager"
                if (Test-Path $zipFile) {
                    Write-Host "  [+] Restoring IDM download database and queue..." -ForegroundColor Yellow
                    if (Test-Path $appDataDir) {
                        Remove-Item -Path $appDataDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Expand-Archive -Path $zipFile -DestinationPath (Split-Path $appDataDir -Parent) -Force
                }
                Write-Host ""
                Write-Host "  [SUCCESS] Settings & Queue restored successfully!" -ForegroundColor Green
            } catch {
                Write-Host "  [ERROR] Restore failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            Restart-IDM
            Write-Host ""
            Read-Host "  Press Enter to return..."
        }
        "6" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Re-registering shell integration DLLs..." -ForegroundColor Yellow
            $idmDirs = @("C:\Program Files (x86)\Internet Download Manager", "C:\Program Files\Internet Download Manager")
            $activeIdmDir = $idmDirs | Where-Object { Test-Path $_ } | Select-Object -First 1

            if ($activeIdmDir) {
                $dll64 = Join-Path $activeIdmDir "IDMShellExt64.dll"
                $dll32 = Join-Path $activeIdmDir "IDMShellExt.dll"
                if (Test-Path $dll64) {
                    Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s `"$dll64`"" -Wait -ErrorAction SilentlyContinue
                }
                if (Test-Path $dll32) {
                    Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s `"$dll32`"" -Wait -ErrorAction SilentlyContinue
                }
                Write-Host "  [+] Shell integration registered successfully." -ForegroundColor Green
            }

            # Unlocking native messaging keys for Chrome, Edge, Firefox
            Write-Host "  [+] Repairing browser native messaging permissions..." -ForegroundColor Yellow
            $browserPaths = @(
                "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.tonec.idm",
                "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.tonec.idm",
                "HKCU:\Software\Mozilla\NativeMessagingHosts\com.tonec.idm"
            )
            foreach ($p in $browserPaths) {
                if (Test-Path $p) {
                    & "$PSScriptRoot\unlock.ps1" | Out-Null
                }
            }

            Write-Host "  [+] Opening extension store pages to check installation..." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            
            # Chrome
            Start-Process "https://chromewebstore.google.com/detail/idm-integration-module/ngpampimnmepgilmajochedlaopbbhcf" -ErrorAction SilentlyContinue
            # Edge
            Start-Process "https://microsoftedge.microsoft.com/addons/detail/idm-integration-module/gphjopenaffeolnnjmpbcalbenfjihde" -ErrorAction SilentlyContinue
            # Firefox
            Start-Process "https://addons.mozilla.org/en-US/firefox/addon/tonec-idm-integration-module/" -ErrorAction SilentlyContinue

            Write-Host ""
            Write-Host "  [SUCCESS] Browser Integration Fixer completed." -ForegroundColor Green
            Write-Host "  [!] Make sure the extension is enabled in your browser settings." -ForegroundColor Yellow
            Write-Host ""
            Read-Host "  Press Enter to return..."
        }
        "7" {
            Clear-Host
            Write-Host ""
            $runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            if ($startupVal -eq 1) {
                Write-Host "  [+] Disabling launch on startup..." -ForegroundColor Yellow
                Set-ItemProperty -Path $regPath -Name "LaunchOnStart" -Value 0 -Force
                Remove-ItemProperty -Path $runPath -Name "IDMan" -ErrorAction SilentlyContinue
                Write-Host "  [SUCCESS] IDM startup launch disabled." -ForegroundColor Green
            } else {
                Write-Host "  [+] Enabling launch on startup..." -ForegroundColor Yellow
                Set-ItemProperty -Path $regPath -Name "LaunchOnStart" -Value 1 -Force
                if ($idmExe) {
                    Set-ItemProperty -Path $runPath -Name "IDMan" -Value "`"$idmExe`" /onstart" -Force
                }
                Write-Host "  [SUCCESS] IDM startup launch enabled." -ForegroundColor Green
            }
            Write-Host ""
            Read-Host "  Press Enter to return..."
        }
        "8" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Restoring default registry permissions..." -ForegroundColor Yellow
            Write-Host ""
            & "$PSScriptRoot\unlock.ps1"
            Write-Host ""
            Read-Host "  Press Enter to return to the menu..."
        }
        "9" {
            $exitSubmenu = $true
        }
        default {
            Write-Host ""
            Write-Host "  [ERROR] Invalid choice! Please select an option between 1 and 9." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while (-not $exitSubmenu)
