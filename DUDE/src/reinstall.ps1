# IDM Clean Uninstall and Reinstall Script
$ErrorActionPreference = "Stop"

# Enable TLS 1.2 and TLS 1.3 dynamically for secure downloads
try {
    [Net.ServicePointManager]::SecurityProtocol = 3072 -bor 12288
} catch {}

$regPath = "HKCU:\SOFTWARE\DownloadManager"

Write-Host "Terminating IDM process if running..." -ForegroundColor Cyan
Stop-Process -Name "IDMan" -ErrorAction SilentlyContinue
Stop-Process -Name "IEMonitor" -ErrorAction SilentlyContinue

# 1. Run standalone clean uninstaller (completely silent and restart-free)
& "$PSScriptRoot\uninstall.ps1"

# 4. Download latest official setup
Write-Host "Fetching latest official IDM download link..." -ForegroundColor Cyan
$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
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

# Fallback to direct URL if page parsing failed
if (-not $downloadUrl) {
    $downloadUrl = "https://mirror2.internetdownloadmanager.com/idman642build64.exe"
    Write-Host "Using fallback official link: $downloadUrl" -ForegroundColor Yellow
}

$tempFile = "$env:TEMP\idm_setup.exe"
Write-Host "Downloading latest official installer from Tonec..." -ForegroundColor Cyan
Write-Host "Link: $downloadUrl" -ForegroundColor Gray

try {
    # Download file using robust fallback
    try {
        if (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue) {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UserAgent $userAgent -UseBasicParsing -TimeoutSec 60
        } else {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", $userAgent)
            $webClient.DownloadFile($downloadUrl, $tempFile)
        }
    } catch {
        # Final pure WebClient fallback
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", $userAgent)
        $webClient.DownloadFile($downloadUrl, $tempFile)
    }
    
    # 5. Launch Setup Silently
    Write-Host "Launching official IDM installation setup silently..." -ForegroundColor Green
    Start-Process -FilePath $tempFile -ArgumentList "/skipdlgs" -Wait
    
    # Cleanup temp setup file
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    
    # Terminate the elevated IDM process started by the installer
    Write-Host "Restarting IDM in standard user mode to enable browser integration..." -ForegroundColor Cyan
    Stop-Process -Name "IDMan" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    # Start IDM as standard user via Shell.Application
    $idmExe = ""
    if (Test-Path "C:\Program Files (x86)\Internet Download Manager\IDMan.exe") {
        $idmExe = "C:\Program Files (x86)\Internet Download Manager\IDMan.exe"
    } elseif (Test-Path "C:\Program Files\Internet Download Manager\IDMan.exe") {
        $idmExe = "C:\Program Files\Internet Download Manager\IDMan.exe"
    }
    
    if ($idmExe) {
        $shell = New-Object -ComObject "Shell.Application"
        $shell.ShellExecute($idmExe)
    }
    
    Write-Host "Clean Reinstallation completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to download or install IDM ($($_.Exception.Message))" -ForegroundColor Red
    Write-Host "You can manually download the installer from: $downloadUrl" -ForegroundColor Yellow
}
