# Ensure running with administrator privileges
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Self-elevate PowerShell script
    Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Enable UTF-8 console output for block characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Set Console Title
$host.UI.RawUI.WindowTitle = "DUDE IDM Activator v2.0"

# Main loop
do {
    Clear-Host
    Write-Host ""
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |                DUDE IDM ACTIVATOR v2.0 (2026)             |" -ForegroundColor Green
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "     =========================================" -ForegroundColor Cyan
    Write-Host "                  D U D E   I D M             " -ForegroundColor Green
    Write-Host "     =========================================" -ForegroundColor Cyan
    Write-Host "         Discord: https://discord.gg/fQhJsYZfgp" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  [1] " -NoNewline -ForegroundColor White
    Write-Host "Freeze Trial" -NoNewline -ForegroundColor Green
    Write-Host "  - Keep 30-day trial frozen forever (Recommended - No fake serials)" -ForegroundColor Gray
    
    Write-Host "  [2] " -NoNewline -ForegroundColor White
    Write-Host "Activate IDM" -NoNewline -ForegroundColor Green
    Write-Host "  - Permanent Registry Lock (May show fake serial warning on latest IDM)" -ForegroundColor Gray
    
    Write-Host "  [3] " -NoNewline -ForegroundColor White
    Write-Host "Reset Trial" -NoNewline -ForegroundColor Green
    Write-Host "   - Restore clean 30-day evaluation period" -ForegroundColor Gray
    
    Write-Host "  [4] " -NoNewline -ForegroundColor White
    Write-Host "Clean Reinstall" -NoNewline -ForegroundColor Green
    Write-Host " - Uninstall, purge remnants, and install latest IDM" -ForegroundColor Gray
    
    Write-Host "  [5] " -NoNewline -ForegroundColor White
    Write-Host "Clean Uninstall" -NoNewline -ForegroundColor Green
    Write-Host "   - Fully uninstall IDM and delete all traces (No Restart)" -ForegroundColor Gray
    
    Write-Host "  [6] " -NoNewline -ForegroundColor White
    Write-Host "Settings & Tools" -NoNewline -ForegroundColor Green
    Write-Host "  - Optimizer, Updates, Extensions, Backups, and Fixes" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "  [7] " -NoNewline -ForegroundColor White
    Write-Host "Exit" -ForegroundColor Red
    Write-Host ""
    Write-Host "  -------------------------------------------------------------" -ForegroundColor Cyan
    
    $choice = Read-Host "  Enter choice [1-7]"
    
    switch ($choice) {
        "1" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Stopping IDM process if running..." -ForegroundColor Yellow
            Write-Host "  [+] Running Trial Freeze script..." -ForegroundColor Yellow
            Write-Host ""
            & "$PSScriptRoot\freeze.ps1"
            Write-Host ""
            Read-Host "  Press Enter to return to the menu..."
        }
        "2" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Stopping IDM process if running..." -ForegroundColor Yellow
            Write-Host "  [+] Running IDM Registry Activation..." -ForegroundColor Yellow
            Write-Host ""
            & "$PSScriptRoot\activate.ps1"
            Write-Host ""
            Read-Host "  Press Enter to return to the menu..."
        }
        "3" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Stopping IDM process if running..." -ForegroundColor Yellow
            Write-Host "  [+] Running Trial Reset script..." -ForegroundColor Yellow
            Write-Host ""
            & "$PSScriptRoot\reset.ps1"
            Write-Host ""
            Read-Host "  Press Enter to return to the menu..."
        }
        "4" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Running Clean Uninstall and Reinstall..." -ForegroundColor Yellow
            Write-Host ""
            & "$PSScriptRoot\reinstall.ps1"
            Write-Host ""
            Read-Host "  Press Enter to return to the menu..."
        }
        "5" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Running Clean Uninstall..." -ForegroundColor Yellow
            Write-Host ""
            & "$PSScriptRoot\uninstall.ps1"
            Write-Host ""
            Read-Host "  Press Enter to return to the menu..."
        }
        "6" {
            Clear-Host
            Write-Host ""
            Write-Host "  [+] Opening Settings & Tools Submenu..." -ForegroundColor Yellow
            Write-Host ""
            & "$PSScriptRoot\settings.ps1"
        }
        "7" {
            Clear-Host
            Write-Host ""
            Write-Host "  Thank you for using DUDE IDM Activator!" -ForegroundColor Green
            Write-Host "  Exiting..."
            Start-Sleep -Seconds 2
            exit
        }
        default {
            Write-Host ""
            Write-Host "  [ERROR] Invalid choice! Please select an option between 1 and 7." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
